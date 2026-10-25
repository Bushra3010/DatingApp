import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

const _sampleRate = 16000;
const maxVoiceSeconds = 30;

/// Wraps raw 16-bit mono PCM in a WAV header, so every platform (and
/// Safari) can play it back without a codec.
Uint8List wavFromPcm16(Uint8List pcm, {int sampleRate = _sampleRate}) {
  final header = ByteData(44);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .toBytes();
}

/// Opens the recorder: pick a question, record up to 30 seconds, listen
/// back, then save it to the profile.
Future<void> recordVoicePrompt(BuildContext context, PreviewStore store) =>
    showEverlaneSheet(context, _VoiceRecorder(store: store));

class _VoiceRecorder extends StatefulWidget {
  const _VoiceRecorder({required this.store});
  final PreviewStore store;
  @override
  State<_VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<_VoiceRecorder> {
  final recorder = AudioRecorder();
  late String label = widget.store.myVoiceLabel.isNotEmpty
      ? widget.store.myVoiceLabel
      : PreviewStore.voicePromptOptions.first;
  final pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? sub;
  Timer? ticker;
  int seconds = 0;
  bool recording = false;
  bool saving = false;
  Uint8List? wav;

  @override
  void dispose() {
    ticker?.cancel();
    sub?.cancel();
    recorder.dispose();
    super.dispose();
  }

  Future<void> start() async {
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          showNotice(context,
              'Allow microphone access to record a voice prompt.');
        }
        return;
      }
      pcm.clear();
      final stream = await recorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true));
      sub = stream.listen(pcm.add);
      setState(() {
        recording = true;
        seconds = 0;
        wav = null;
      });
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => seconds++);
        if (seconds >= maxVoiceSeconds) stop();
      });
    } catch (_) {
      if (mounted) showNotice(context, 'Couldn’t start recording. Try again.');
    }
  }

  Future<void> stop() async {
    ticker?.cancel();
    await recorder.stop();
    await sub?.cancel();
    sub = null;
    final bytes = pcm.takeBytes();
    setState(() {
      recording = false;
      // Under a second is almost always an accidental tap.
      wav = seconds < 1 || bytes.isEmpty ? null : wavFromPcm16(bytes);
    });
  }

  Future<void> save() async {
    final clip = wav;
    if (clip == null) return;
    setState(() => saving = true);
    await widget.store.setVoice(label, clip, seconds.clamp(1, maxVoiceSeconds));
    if (!mounted) return;
    Navigator.pop(context);
    showNotice(context, 'Voice prompt saved to your profile.');
  }

  @override
  Widget build(BuildContext context) {
    final clip = wav;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Voice prompt', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text('Answer in your own voice. Up to $maxVoiceSeconds seconds.',
          style: TextStyle(color: EverlaneColors.muted)),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
          initialValue: label,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Pick a prompt'),
          items: [
            for (final o in {...PreviewStore.voicePromptOptions, label})
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: recording
              ? null
              : (v) => setState(() => label = v ?? label)),
      const SizedBox(height: 26),
      Center(
          child: Column(children: [
        Text(
            '0:${seconds.toString().padLeft(2, '0')} / 0:$maxVoiceSeconds',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: recording ? EverlaneColors.like : EverlaneColors.muted)),
        const SizedBox(height: 12),
        Semantics(
            button: true,
            label: recording ? 'Stop recording' : 'Start recording',
            child: GestureDetector(
                onTap: saving ? null : (recording ? stop : start),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: recording ? EverlaneColors.like : null,
                        gradient:
                            recording ? null : EverlaneColors.premiumGradient,
                        boxShadow: [
                          BoxShadow(
                              color: EverlaneColors.like.withValues(alpha: .4),
                              blurRadius: recording ? 26 : 14)
                        ]),
                    child: Icon(
                        recording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 38)))),
        const SizedBox(height: 10),
        Text(
            recording
                ? 'Recording… tap to stop'
                : clip == null
                    ? 'Tap to record'
                    : 'Tap to record again',
            style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
      ])),
      if (clip != null && !recording) ...[
        const SizedBox(height: 20),
        VoicePrompt(
            id: 'draft',
            label: label,
            seconds: seconds,
            bytes: clip),
      ],
      const SizedBox(height: 22),
      GradientButton(
          label: saving ? 'Saving…' : 'Save voice prompt',
          icon: Icons.check_rounded,
          onTap: clip == null || recording || saving ? null : save),
      if (widget.store.hasVoice) ...[
        const SizedBox(height: 6),
        Center(
            child: TextButton(
                onPressed: recording || saving
                    ? null
                    : () {
                        widget.store.removeVoice();
                        Navigator.pop(context);
                        showNotice(context, 'Voice prompt removed.');
                      },
                child: const Text('Remove my voice prompt'))),
      ],
      const SizedBox(height: 10),
    ]);
  }
}

/// Plays a voice prompt on a profile: a recording from [url] or [bytes],
/// or, for demo people with neither, just animates the waveform.
class VoicePrompt extends StatefulWidget {
  const VoicePrompt(
      {super.key,
      required this.id,
      required this.seconds,
      this.label = '',
      this.transcript = '',
      this.url = '',
      this.bytes});

  VoicePrompt.of(Person p, {Key? key})
      : this(
            key: key,
            id: p.id,
            seconds: p.voiceSeconds,
            label: p.voiceLabel,
            transcript: p.voicePrompt,
            url: p.voiceUrl);

  /// Seeds the waveform shape, so it stays the same for a person.
  final String id;
  final int seconds;
  final String label, transcript, url;
  final Uint8List? bytes;
  bool get hasAudio => url.isNotEmpty || bytes != null;
  @override
  State<VoicePrompt> createState() => _VoicePromptState();
}

class _VoicePromptState extends State<VoicePrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds.clamp(1, maxVoiceSeconds)))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && !widget.hasAudio) reset();
    });
  AudioPlayer? player;
  StreamSubscription<void>? done;

  late final bars = List.generate(36, (i) {
    final id = widget.id.isEmpty ? 'voice' : widget.id;
    final seed = id.codeUnitAt(i % id.length);
    return .25 + ((seed * (i + 7)) % 11) / 14;
  });

  void reset() {
    controller.reset();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    done?.cancel();
    player?.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> toggle() async {
    if (controller.isAnimating) {
      controller.stop();
      await player?.pause();
      setState(() {});
      return;
    }
    if (widget.hasAudio) {
      try {
        final p = player ??= AudioPlayer();
        done ??= p.onPlayerComplete.listen((_) => reset());
        if (controller.value == 0) {
          final bytes = widget.bytes;
          await p.play(bytes != null
              ? BytesSource(bytes, mimeType: 'audio/wav')
              : UrlSource(widget.url));
        } else {
          await p.resume();
        }
      } catch (_) {
        if (mounted) showNotice(context, 'Couldn’t play this voice prompt.');
        return;
      }
    }
    controller.forward();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 14),
      decoration: BoxDecoration(
          color: EverlaneColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: EverlaneColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.label.isNotEmpty)
          Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 0, 10),
              child: Row(children: [
                Icon(Icons.mic_rounded, size: 15, color: EverlaneColors.like),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(widget.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: EverlaneColors.muted))),
              ])),
        Row(children: [
          IconButton(
              tooltip: controller.isAnimating
                  ? 'Pause voice prompt'
                  : 'Play voice prompt',
              onPressed: toggle,
              style: IconButton.styleFrom(
                  backgroundColor: EverlaneColors.like,
                  foregroundColor: Colors.white),
              icon: Icon(controller.isAnimating
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: SizedBox(
                  height: 34,
                  child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (var i = 0; i < bars.length; i++)
                                  Expanded(
                                      child: Center(
                                          child: Container(
                                              width: 2,
                                              height: 34 * bars[i],
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  color: i / bars.length <
                                                          controller.value
                                                      ? EverlaneColors.like
                                                      : EverlaneColors.line)))),
                              ])))),
          const SizedBox(width: 10),
          Text('0:${widget.seconds.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
        ]),
        if (widget.transcript.isNotEmpty)
          Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 0, 0),
              child: Text('“${widget.transcript}”',
                  style: const TextStyle(
                      fontSize: 14, fontStyle: FontStyle.italic, height: 1.5))),
      ]));
}
