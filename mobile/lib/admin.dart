// What admins set in the panel: maintenance, minimum versions, feature
// flags, onboarding rules, announcements, and the support and data models
// that go with them. Every value has a safe default, so the app behaves as
// it always did when there's no backend (tests, preview) or it can't load.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Comes with supabase_flutter; see pubspec.yaml.
import 'package:url_launcher/url_launcher.dart';

import 'backend.dart' show errorMessage;
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Keep in sync with `version:` in pubspec.yaml (without the build number).
const appVersion = '0.3.9';

bool _bool(Object? v, bool fallback) => switch (v) {
      bool b => b,
      'true' => true,
      'false' => false,
      _ => fallback,
    };

int _int(Object? v, int fallback) => switch (v) {
      num n => n.toInt(),
      String s => int.tryParse(s) ?? fallback,
      _ => fallback,
    };

String _str(Object? v) => v is String ? v : '';

Map<String, dynamic> _section(Map<String, dynamic> j, String key) =>
    j[key] is Map ? Map<String, dynamic>.from(j[key] as Map) : const {};

/// -1, 0 or 1, comparing "1.2.10" and "1.2.9" part by part. A build number
/// ("+12") and anything that isn't a number are ignored.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
        for (final p in v.split('+').first.trim().split('.'))
          int.tryParse(RegExp(r'^\d+').stringMatch(p) ?? '') ?? 0
      ];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// The result of `app_settings()`.
class AppSettings {
  const AppSettings({
    this.maintenance = false,
    this.maintenanceMessage = '',
    this.minVersionWeb = '',
    this.minVersionAndroid = '',
    this.minVersionIos = '',
    this.updateMessage = '',
    this.hangouts = true,
    this.likesYou = true,
    this.boost = true,
    this.sparks = true,
    this.rewind = true,
    this.quiz = true,
    this.voicePrompts = true,
    this.crossedPaths = true,
    this.introductions = true,
    this.selfieVerification = true,
    this.referrals = true,
    this.requirePhoto = true,
    this.minPhotos = 1,
    this.requireCity = false,
    this.requireInterests = false,
    this.requireBio = false,
    this.minAge = 18,
    this.referralEnabled = false,
    this.referralRewardDays = 0,
    this.referralRewardPlan = '',
  });

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final m = _section(j, 'maintenance'),
        v = _section(j, 'min_version'),
        f = _section(j, 'flags'),
        o = _section(j, 'onboarding'),
        a = _section(j, 'age'),
        r = _section(j, 'referral');
    bool flag(String key) => _bool(f[key], true);
    return AppSettings(
      maintenance: _bool(m['on'], false),
      maintenanceMessage: _str(m['message']),
      minVersionWeb: _str(v['web']),
      minVersionAndroid: _str(v['android']),
      minVersionIos: _str(v['ios']),
      updateMessage: _str(v['message']),
      hangouts: flag('hangouts'),
      likesYou: flag('likes_you'),
      boost: flag('boost'),
      sparks: flag('sparks'),
      rewind: flag('rewind'),
      quiz: flag('quiz'),
      voicePrompts: flag('voice_prompts'),
      crossedPaths: flag('crossed_paths'),
      introductions: flag('introductions'),
      selfieVerification: flag('selfie_verification'),
      referrals: flag('referrals'),
      requirePhoto: _bool(o['require_photo'], true),
      minPhotos: _int(o['min_photos'], 1),
      requireCity: _bool(o['require_city'], false),
      requireInterests: _bool(o['require_interests'], false),
      requireBio: _bool(o['require_bio'], false),
      minAge: _int(a['min_age'], 18),
      referralEnabled: _bool(r['enabled'], false),
      referralRewardDays: _int(r['reward_days'], 0),
      referralRewardPlan: _str(r['reward_plan']),
    );
  }

  final bool maintenance;
  final String maintenanceMessage;

  final String minVersionWeb, minVersionAndroid, minVersionIos, updateMessage;

  /// Feature flags: false hides the feature's entry points.
  final bool hangouts,
      likesYou,
      boost,
      sparks,
      rewind,
      quiz,
      voicePrompts,
      crossedPaths,
      introductions,
      selfieVerification,
      referrals;

  final bool requirePhoto, requireCity, requireInterests, requireBio;
  final int minPhotos;
  final int minAge;

  final bool referralEnabled;
  final int referralRewardDays;
  final String referralRewardPlan;

  /// Never below 18, whatever the panel says.
  int get adultAge => minAge < 18 ? 18 : minAge;

  /// Photos needed to finish sign-up (at most the gallery's size).
  int get photosNeeded {
    final n = requirePhoto ? (minPhotos < 1 ? 1 : minPhotos) : minPhotos;
    return n.clamp(0, PreviewStore.maxPhotos);
  }

  bool get referralsOn => referrals && referralEnabled;

  /// The lowest version allowed on this platform; empty for none.
  String minVersionFor({required bool web, required TargetPlatform platform}) {
    if (web) return minVersionWeb;
    return switch (platform) {
      TargetPlatform.android => minVersionAndroid,
      TargetPlatform.iOS => minVersionIos,
      _ => '',
    };
  }

  bool needsUpdate(String version,
      {required bool web, required TargetPlatform platform}) {
    final min = minVersionFor(web: web, platform: platform).trim();
    return min.isNotEmpty && compareVersions(version, min) < 0;
  }
}

/// Why a signed-in member can't use the app right now.
class AccountRestriction {
  const AccountRestriction(
      {required this.title, required this.message, this.canAppeal = true});
  final String title, message;

  /// Suspended or blocked members stay signed in to appeal; banned
  /// accounts are signed out.
  final bool canAppeal;
}

/// A row from `my_announcements()`.
class Announcement {
  const Announcement(
      {required this.id,
      required this.kind,
      required this.title,
      this.body = '',
      this.ctaLabel = '',
      this.ctaUrl = '',
      this.createdAt});

  factory Announcement.fromRow(Map<String, dynamic> r) => Announcement(
      id: '${r['id']}',
      kind: _str(r['kind']),
      title: _str(r['title']),
      body: _str(r['body']),
      ctaLabel: _str(r['cta_label']),
      ctaUrl: _str(r['cta_url']),
      createdAt: DateTime.tryParse(_str(r['created_at']))?.toLocal());

  final String id, kind, title, body, ctaLabel, ctaUrl;
  final DateTime? createdAt;
  bool get isBanner => kind == 'banner';
  bool get isNotice => kind == 'notice';

  /// Only web links get a button.
  Uri? get cta {
    final u = Uri.tryParse(ctaUrl.trim());
    if (u == null || ctaLabel.trim().isEmpty) return null;
    return u.scheme == 'https' || u.scheme == 'http' ? u : null;
  }
}

/// A Help center article from the `faq` table.
class FaqItem {
  const FaqItem(
      {required this.id,
      required this.category,
      required this.question,
      required this.answer});
  factory FaqItem.fromRow(Map<String, dynamic> r) => FaqItem(
      id: '${r['id']}',
      category: _str(r['category']).isEmpty ? 'General' : _str(r['category']),
      question: _str(r['question']),
      answer: _str(r['answer']));
  final String id, category, question, answer;
}

const ticketCategories = [
  ('general', 'General'),
  ('account', 'Account'),
  ('billing', 'Billing'),
  ('safety', 'Safety'),
  ('bug', 'Something’s broken'),
  ('other', 'Other'),
];

String ticketCategoryLabel(String c) => c == 'appeal'
    ? 'Appeal'
    : ticketCategories.where((x) => x.$1 == c).map((x) => x.$2).firstOrNull ??
        c;

/// A row from `my_tickets()`.
class SupportTicket {
  const SupportTicket(
      {required this.id,
      required this.subject,
      required this.category,
      required this.status,
      this.updatedAt,
      this.unread = 0});
  factory SupportTicket.fromRow(Map<String, dynamic> r) => SupportTicket(
      id: '${r['id']}',
      subject: _str(r['subject']),
      category: _str(r['category']),
      status: _str(r['status']),
      updatedAt: DateTime.tryParse(_str(r['updated_at']))?.toLocal(),
      unread: switch (r['unread']) {
        bool b => b ? 1 : 0,
        num n => n.toInt(),
        _ => 0,
      });
  final String id, subject, category, status;
  final DateTime? updatedAt;

  /// Replies from the team you haven't read.
  final int unread;
}

/// A row from `ticket_thread()`.
class TicketMessage {
  const TicketMessage(
      {required this.id,
      required this.fromAdmin,
      required this.body,
      this.createdAt});
  factory TicketMessage.fromRow(Map<String, dynamic> r) => TicketMessage(
      id: '${r['id']}',
      fromAdmin: _bool(r['from_admin'], false),
      body: _str(r['body']),
      createdAt: DateTime.tryParse(_str(r['created_at']))?.toLocal());
  final String id, body;
  final bool fromAdmin;
  final DateTime? createdAt;
}

/// A row from `my_data_requests()`.
class DataRequest {
  const DataRequest(
      {required this.id,
      required this.kind,
      required this.status,
      this.note = '',
      this.createdAt,
      this.completedAt});
  factory DataRequest.fromRow(Map<String, dynamic> r) => DataRequest(
      id: '${r['id']}',
      kind: _str(r['kind']),
      status: _str(r['status']),
      note: _str(r['note']),
      createdAt: DateTime.tryParse(_str(r['created_at']))?.toLocal(),
      completedAt: DateTime.tryParse(_str(r['completed_at']))?.toLocal());
  final String id, kind, status, note;
  final DateTime? createdAt, completedAt;
}

/// The result of `my_referral()`.
class Referral {
  const Referral({required this.code, this.joined = 0, this.rewardDays = 0});
  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
      code: _str(j['code']),
      joined: _int(j['joined'], 0),
      rewardDays: _int(j['reward_days'], 0));
  final String code;
  final int joined, rewardDays;
}

/// "26 Oct 2026".
String shortDate(DateTime? t) {
  if (t == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${t.day} ${months[t.month - 1]} ${t.year}';
}

Future<void> openLink(BuildContext context, Uri url) async {
  try {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (context.mounted) showNotice(context, 'Couldn’t open that link.');
}

// ---------------------------------------------------------------------------
// Full-screen gates
// ---------------------------------------------------------------------------

/// A centred icon, title, message and buttons, in place of the app.
class GateScreen extends StatelessWidget {
  const GateScreen(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      required this.actions});
  final IconData icon;
  final String title, message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                                child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                        color: EverlaneColors.blush,
                                        shape: BoxShape.circle),
                                    child: Icon(icon,
                                        size: 38, color: EverlaneColors.like))),
                            const SizedBox(height: 24),
                            Text(title,
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 12),
                            Text(message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: EverlaneColors.muted, height: 1.6)),
                            const SizedBox(height: 28),
                            for (final (i, a) in actions.indexed) ...[
                              if (i > 0) const SizedBox(height: 8),
                              a,
                            ],
                          ]))))));
}

/// Shown instead of the app (and onboarding) while maintenance is on.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool busy = false;

  Future<void> retry() async {
    setState(() => busy = true);
    await widget.store.loadSettings();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.store.settings.maintenanceMessage.trim();
    return GateScreen(
        icon: Icons.construction_rounded,
        title: 'We’ll be right back',
        message: message.isEmpty
            ? 'Everlane is getting a quick tune-up. Please check back soon.'
            : message,
        actions: [
          GradientButton(
              label: busy ? 'Checking…' : 'Retry', onTap: busy ? null : retry),
        ]);
  }
}

/// Shown when this build is older than the minimum set in the panel.
class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool busy = false;

  Future<void> check() async {
    setState(() => busy = true);
    await widget.store.loadSettings();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.store.settings.updateMessage.trim();
    return GateScreen(
        icon: Icons.system_update_rounded,
        title: 'Update Everlane',
        message: message.isEmpty
            ? kIsWeb
                ? 'A newer version of Everlane is out. Reload to get it.'
                : 'A newer version of Everlane is out. Please update the app to keep going.'
            : message,
        actions: [
          if (kIsWeb)
            GradientButton(
                label: 'Reload',
                onTap: () =>
                    launchUrl(Uri.base, webOnlyWindowName: '_self').ignore())
          else
            GradientButton(
                label: busy ? 'Checking…' : 'I’ve updated',
                onTap: busy ? null : check),
        ]);
  }
}

/// A suspended or blocked member: they can appeal or log out, nothing else.
/// A banned account is already signed out and can only go back.
class AccountRestrictedScreen extends StatelessWidget {
  const AccountRestrictedScreen(
      {super.key, required this.store, required this.restriction});
  final PreviewStore store;
  final AccountRestriction restriction;

  @override
  Widget build(BuildContext context) => GateScreen(
          icon: Icons.block_rounded,
          title: restriction.title,
          message: restriction.message,
          actions: [
            if (restriction.canAppeal && store.signedIn) ...[
              Builder(
                  builder: (context) => GradientButton(
                      label: 'Appeal this decision',
                      onTap: () => showAppealSheet(context, store))),
              TextButton(
                  onPressed: () => store.logOut(),
                  child: const Text('Log out')),
            ] else
              GradientButton(
                  label: 'OK', onTap: () => store.clearRestriction()),
          ]);
}

Future<void> showAppealSheet(BuildContext context, PreviewStore store) =>
    showEverlaneSheet<void>(context, _AppealForm(store: store));

class _AppealForm extends StatefulWidget {
  const _AppealForm({required this.store});
  final PreviewStore store;
  @override
  State<_AppealForm> createState() => _AppealFormState();
}

class _AppealFormState extends State<_AppealForm> {
  final body = TextEditingController();
  bool busy = false, sent = false;
  String? error;

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> send() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.createTicket(
          subject: 'Appeal: ${widget.store.restriction?.title ?? 'account'}',
          category: 'appeal',
          body: body.text.trim());
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = errorMessage(e, 'Couldn’t send your appeal. Try again.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => sent
      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Appeal sent',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text('Our team will review it and reply by email.',
              style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
          const SizedBox(height: 20),
          GradientButton(label: 'Done', onTap: () => Navigator.pop(context)),
        ])
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Appeal this decision',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text('Tell us what happened. A person on our team will review it.',
              style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
          const SizedBox(height: 16),
          TextField(
              controller: body,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Your message')),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(error!,
                    style: const TextStyle(color: EverlaneColors.like))),
          GradientButton(
              label: busy ? 'Sending…' : 'Send appeal',
              onTap: busy || body.text.trim().isEmpty ? null : send),
        ]);
}

// ---------------------------------------------------------------------------
// Announcements
// ---------------------------------------------------------------------------

/// The newest banner announcement, dismissible, at the top of Discover.
class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({super.key, required this.store});
  final PreviewStore store;

  @override
  Widget build(BuildContext context) {
    final a = store.banner;
    if (a == null) return const SizedBox.shrink();
    final cta = a.cta;
    return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        decoration: BoxDecoration(
            color: EverlaneColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: EverlaneColors.line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.campaign_outlined,
                  size: 20, color: EverlaneColors.like)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(a.title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (a.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: EverlaneColors.muted)),
                ],
                if (cta != null)
                  TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36)),
                      onPressed: () => openLink(context, cta),
                      child: Text(a.ctaLabel)),
              ])),
          IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: () => store.dismissAnnouncement(a.id),
              icon: Icon(Icons.close_rounded,
                  size: 18, color: EverlaneColors.muted)),
        ]));
  }
}

/// Shows a 'notice' announcement once, as a dialog.
Future<void> showNoticeAnnouncement(
    BuildContext context, PreviewStore store, Announcement a) async {
  store.dismissAnnouncement(a.id);
  final cta = a.cta;
  await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: Text(a.title),
              content: a.body.isEmpty
                  ? null
                  : SingleChildScrollView(child: Text(a.body)),
              actions: [
                if (cta != null)
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        openLink(context, cta);
                      },
                      child: Text(a.ctaLabel)),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it')),
              ]));
}
