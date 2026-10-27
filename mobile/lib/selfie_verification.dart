import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'theme.dart';

/// The live selfie for the verified badge. It takes a short burst from the
/// front camera: eyes open, a blink, then eyes open again. A reviewer in the
/// admin panel checks the blink across the frames (so it's a live face, not a
/// photo held up to the camera) and compares the face with the profile
/// photos. Pops with true once the burst is sent.
class SelfieVerificationScreen extends StatefulWidget {
  const SelfieVerificationScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<SelfieVerificationScreen> createState() =>
      _SelfieVerificationScreenState();
}

enum _Step { starting, ready, capturing, review, sending, failed }

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen> {
  CameraController? camera;
  _Step step = _Step.starting;
  String prompt = 'Fit your face in the oval';
  String error = '';
  final frames = <Uint8List>[];

  @override
  void initState() {
    super.initState();
    openCamera();
  }

  @override
  void dispose() {
    camera?.dispose();
    super.dispose();
  }

  Future<void> openCamera() async {
    setState(() {
      step = _Step.starting;
      error = '';
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('none', 'No camera found.');
      final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first);
      final c = CameraController(front, ResolutionPreset.medium,
          enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        camera = c;
        step = _Step.ready;
      });
    } on CameraException catch (e) {
      fail(e.code.contains('ermission') || e.code.contains('Denied')
          ? 'Everlane needs your camera for the selfie. Allow camera access in your settings, then try again.'
          : 'Couldn’t start the camera. ${e.description ?? ''}');
    } catch (e) {
      fail('Couldn’t start the camera.');
    }
  }

  void fail(String message) {
    if (!mounted) return;
    setState(() {
      step = _Step.failed;
      error = message;
    });
  }

  Future<void> shot() async {
    final file = await camera!.takePicture();
    frames.add(await file.readAsBytes());
  }

  Future<void> say(String text, int waitMs) async {
    if (!mounted) return;
    setState(() => prompt = text);
    await Future<void>.delayed(Duration(milliseconds: waitMs));
  }

  /// Eyes open, then three quick frames through the blink, then open again.
  Future<void> capture() async {
    frames.clear();
    setState(() => step = _Step.capturing);
    try {
      await say('Look straight at the camera', 1200);
      await shot();
      await say('Blink now', 250);
      HapticFeedback.mediumImpact();
      for (var i = 0; i < 3; i++) {
        await shot();
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      await say('Eyes open again', 700);
      await shot();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        step = _Step.review;
        prompt = 'Check your selfie';
      });
    } catch (_) {
      fail('Something went wrong taking the selfie. Try again.');
    }
  }

  Future<void> send() async {
    setState(() => step = _Step.sending);
    try {
      await widget.store.submitVerification(frames);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => step = _Step.review);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn’t send your selfie. Check your connection.')));
    }
  }

  void retake() => setState(() {
        frames.clear();
        step = _Step.ready;
        prompt = 'Fit your face in the oval';
      });

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFF07060B),
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Selfie verification'),
          leading: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded))),
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: switch (step) {
                _Step.failed => _failed(),
                _Step.review || _Step.sending => _review(),
                _ => _live(),
              })));

  Widget _live() {
    final c = camera;
    return Column(children: [
      Text(prompt,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: prompt == 'Blink now' ? EverlaneColors.like : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
          step == _Step.capturing
              ? 'Hold still'
              : 'Good light, no sunglasses, just you in the frame',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: .6))),
      const SizedBox(height: 24),
      Expanded(
          child: Center(
              child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(4),
                      decoration: ShapeDecoration(
                          shape: const OvalBorder(),
                          gradient: step == _Step.capturing
                              ? EverlaneColors.premiumGradient
                              : null,
                          color: step == _Step.capturing
                              ? null
                              : Colors.white.withValues(alpha: .25)),
                      child: ClipOval(
                          child: c == null || step == _Step.starting
                              ? const ColoredBox(
                                  color: Colors.black,
                                  child: Center(
                                      child: CircularProgressIndicator()))
                              : FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                      width: 300,
                                      height: 300 * c.value.aspectRatio,
                                      child: CameraPreview(c)))))))),
      const SizedBox(height: 28),
      SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: step == _Step.ready ? capture : null,
              style: FilledButton.styleFrom(
                  backgroundColor: EverlaneColors.like,
                  minimumSize: const Size(0, 54)),
              child: Text(step == _Step.capturing ? 'Taking selfie…' : 'Start'))),
    ]);
  }

  Widget _review() => Column(children: [
        const Text('Check your selfie',
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Your face should be clear in every frame.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .6))),
        const SizedBox(height: 20),
        Expanded(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.memory(frames.first,
                    fit: BoxFit.cover, width: double.infinity))),
        const SizedBox(height: 12),
        SizedBox(
            height: 72,
            child: Row(children: [
              for (final f in frames.skip(1))
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(f,
                                fit: BoxFit.cover, height: 72)))),
            ])),
        const SizedBox(height: 22),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: step == _Step.sending ? null : send,
                style: FilledButton.styleFrom(
                    backgroundColor: EverlaneColors.like,
                    minimumSize: const Size(0, 54)),
                child: step == _Step.sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Send for review'))),
        const SizedBox(height: 8),
        TextButton(
            onPressed: step == _Step.sending ? null : retake,
            child: const Text('Retake',
                style: TextStyle(color: Colors.white))),
      ]);

  Widget _failed() => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.no_photography_outlined,
            color: Colors.white70, size: 48),
        const SizedBox(height: 16),
        Text(error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, height: 1.5)),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: openCamera,
            style: FilledButton.styleFrom(backgroundColor: EverlaneColors.like),
            child: const Text('Try again')),
      ]));
}
