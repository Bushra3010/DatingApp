// Help & support: the Help center (FAQ), contact support, your requests and
// their replies, your data requests, and inviting friends.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin.dart';
import 'backend.dart' show errorMessage;
import 'legal.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

void openHelp(BuildContext context, PreviewStore store) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => HelpSupportScreen(store: store)));

void openYourData(BuildContext context, PreviewStore store) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => YourDataScreen(store: store)));

void openInvite(BuildContext context, PreviewStore store) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => InviteScreen(store: store)));

Widget _subtitle(String text) =>
    Text(text, style: TextStyle(fontSize: 12, color: EverlaneColors.muted));

/// Help center, contact support, my requests and your data.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.loadTickets();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        return Scaffold(
            appBar: AppBar(
                title: const Text('Help & support',
                    style: TextStyle(fontSize: 17))),
            body: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        children: [
                          Text('How can we help?',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 16),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.menu_book_outlined),
                              title: const Text('Help center'),
                              subtitle:
                                  _subtitle('Answers to common questions'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          HelpCenterScreen(store: store)))),
                          const Divider(height: 1),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.support_agent_rounded),
                              title: const Text('Contact support'),
                              subtitle: _subtitle(store.canContactSupport
                                  ? 'We usually reply within a day'
                                  : 'Sign in to contact us'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: store.canContactSupport
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => ContactSupportScreen(
                                              store: store)))
                                  : null),
                          const Divider(height: 1),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.inbox_outlined),
                              title: const Text('My requests'),
                              subtitle: _subtitle(store.unreadTickets > 0
                                  ? 'New reply from our team'
                                  : 'Your conversations with support'),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (store.unreadTickets > 0)
                                      Badge(
                                          backgroundColor: EverlaneColors.like,
                                          label:
                                              Text('${store.unreadTickets}')),
                                    const Icon(Icons.chevron_right),
                                  ]),
                              onTap: store.canContactSupport
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) =>
                                              MyTicketsScreen(store: store)))
                                  : null),
                          const Divider(height: 1),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.folder_shared_outlined),
                              title: const Text('Your data'),
                              subtitle: _subtitle(
                                  'Download it or ask for a deletion review'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => openYourData(context, store)),
                          const Divider(height: 1),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.handshake_outlined),
                              title: const Text('Community guidelines'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => openGuidelines(context)),
                        ]))));
      });
}

/// FAQ articles from the admin panel, grouped by category.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  @override
  void initState() {
    super.initState();
    // Already set (loaded before, or by a test): show it, refresh quietly.
    if (widget.store.backend != null || widget.store.faq == null) {
      widget.store.loadFaq();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final faq = widget.store.faq;
        final groups = <String, List<FaqItem>>{};
        for (final f in faq ?? const <FaqItem>[]) {
          (groups[f.category] ??= []).add(f);
        }
        return Scaffold(
            appBar: AppBar(
                title:
                    const Text('Help center', style: TextStyle(fontSize: 17))),
            body: faq == null
                ? const Center(
                    child:
                        CircularProgressIndicator(color: EverlaneColors.like))
                : faq.isEmpty
                    ? EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: widget.store.faqFailed
                            ? 'Couldn’t load help articles.'
                            : 'No articles yet.',
                        detail: 'You can always contact support instead.')
                    : Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                children: [
                                  for (final MapEntry(
                                        key: category,
                                        value: items
                                      ) in groups.entries) ...[
                                    Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            8, 18, 8, 6),
                                        child: Eyebrow(category)),
                                    for (final f in items)
                                      ExpansionTile(
                                          key: ValueKey(f.id),
                                          shape: const Border(),
                                          collapsedShape: const Border(),
                                          title: Text(f.question,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          expandedCrossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          childrenPadding:
                                              const EdgeInsets.fromLTRB(
                                                  16, 0, 16, 16),
                                          children: [
                                            SelectableText(f.answer,
                                                style: TextStyle(
                                                    height: 1.5,
                                                    color:
                                                        EverlaneColors.body)),
                                          ]),
                                  ],
                                ]))));
      });
}

/// A new support request.
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final subject = TextEditingController();
  final body = TextEditingController();
  String category = 'general';
  bool busy = false;
  String? error;

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  bool get ready =>
      subject.text.trim().isNotEmpty && body.text.trim().isNotEmpty;

  Future<void> send() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.createTicket(
          subject: subject.text.trim(),
          category: category,
          body: body.text.trim());
      if (!mounted) return;
      showNotice(context, 'Sent. We’ll reply in My requests.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
            () => error = errorMessage(e, 'Couldn’t send that. Try again.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Contact support', style: TextStyle(fontSize: 17))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    Text('What’s it about?',
                        style: TextStyle(color: EverlaneColors.muted)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (value, label) in ticketCategories)
                        ChoiceChip(
                            label: Text(label),
                            selected: category == value,
                            onSelected: (_) =>
                                setState(() => category = value)),
                    ]),
                    const SizedBox(height: 18),
                    TextField(
                        controller: subject,
                        maxLength: 120,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            hintText: 'Subject', counterText: '')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: body,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 4000,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            hintText: 'Tell us what’s going on')),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(error!,
                              style:
                                  const TextStyle(color: EverlaneColors.like))),
                    const SizedBox(height: 8),
                    GradientButton(
                        label: busy ? 'Sending…' : 'Send',
                        onTap: busy || !ready ? null : send),
                  ]))));
}

String _statusLabel(String s) => switch (s) {
      'open' => 'Open',
      'pending' => 'Waiting on you',
      'answered' => 'Answered',
      'resolved' || 'closed' => 'Closed',
      'done' || 'completed' => 'Done',
      'in_progress' || 'processing' => 'In progress',
      'rejected' || 'declined' => 'Declined',
      '' => '',
      _ => '${s[0].toUpperCase()}${s.substring(1).replaceAll('_', ' ')}',
    };

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    widget.store.loadTickets().whenComplete(() {
      if (mounted) setState(() => loading = false);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final tickets = widget.store.tickets;
        return Scaffold(
            appBar: AppBar(
                title:
                    const Text('My requests', style: TextStyle(fontSize: 17))),
            body: tickets.isEmpty
                ? loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: EverlaneColors.like))
                    : const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No requests yet.',
                        detail: 'Anything you send to support shows up here.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: tickets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final t = tickets[i];
                      return ListTile(
                          title: Text(t.subject.isEmpty ? 'Request' : t.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: t.unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                          subtitle: _subtitle([
                            ticketCategoryLabel(t.category),
                            _statusLabel(t.status),
                            shortDate(t.updatedAt),
                          ].where((x) => x.isNotEmpty).join(' · ')),
                          trailing: t.unread > 0
                              ? Badge(
                                  backgroundColor: EverlaneColors.like,
                                  label: Text('${t.unread}'))
                              : const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) => TicketThreadScreen(
                                      store: widget.store, ticket: t))));
                    }));
      });
}

/// One request as a chat with the support team.
class TicketThreadScreen extends StatefulWidget {
  const TicketThreadScreen(
      {super.key, required this.store, required this.ticket});
  final PreviewStore store;
  final SupportTicket ticket;
  @override
  State<TicketThreadScreen> createState() => _TicketThreadScreenState();
}

class _TicketThreadScreenState extends State<TicketThreadScreen> {
  final reply = TextEditingController();
  List<TicketMessage>? messages;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final m = await widget.store.ticketThread(widget.ticket.id);
      if (mounted) setState(() => messages = m);
    } catch (e) {
      if (mounted) {
        setState(() {
          messages ??= const [];
          error = 'Couldn’t load this conversation.';
        });
      }
    }
  }

  Future<void> send() async {
    final text = reply.text.trim();
    if (text.isEmpty) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.store.replyTicket(widget.ticket.id, text);
      reply.clear();
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = errorMessage(e, 'Couldn’t send. Try again.'));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = messages;
    return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.ticket.subject.isEmpty
                    ? 'Request'
                    : widget.ticket.subject,
                style: const TextStyle(fontSize: 17))),
        body: Column(children: [
          Expanded(
              child: list == null
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: EverlaneColors.like))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      children: [
                          for (final m in list)
                            Align(
                                alignment: m.fromAdmin
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 320),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                        color: m.fromAdmin
                                            ? EverlaneColors.card
                                            : EverlaneColors.deep,
                                        borderRadius: BorderRadius.circular(16),
                                        border: m.fromAdmin
                                            ? Border.all(
                                                color: EverlaneColors.line)
                                            : null),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (m.fromAdmin)
                                            const Padding(
                                                padding:
                                                    EdgeInsets.only(bottom: 4),
                                                child: Text('Everlane support',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: EverlaneColors
                                                            .like))),
                                          Text(m.body,
                                              style: TextStyle(
                                                  height: 1.4,
                                                  color: m.fromAdmin
                                                      ? EverlaneColors.plum
                                                      : Colors.white)),
                                          if (m.createdAt != null)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                    shortDate(m.createdAt),
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: m.fromAdmin
                                                            ? EverlaneColors
                                                                .muted
                                                            : Colors.white70))),
                                        ]))),
                        ])),
          if (error != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(error!,
                    style: const TextStyle(color: EverlaneColors.like))),
          SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                  child: Row(children: [
                    Expanded(
                        child: TextField(
                            controller: reply,
                            minLines: 1,
                            maxLines: 4,
                            onChanged: (_) => setState(() {}),
                            decoration:
                                const InputDecoration(hintText: 'Reply'))),
                    IconButton(
                        tooltip: 'Send reply',
                        onPressed:
                            sending || reply.text.trim().isEmpty ? null : send,
                        icon: const Icon(Icons.send_rounded)),
                  ]))),
        ]));
  }
}

/// Download your data, or ask for a deletion review, and see past requests.
class YourDataScreen extends StatefulWidget {
  const YourDataScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<YourDataScreen> createState() => _YourDataScreenState();
}

class _YourDataScreenState extends State<YourDataScreen> {
  String? busy;

  @override
  void initState() {
    super.initState();
    widget.store.loadDataRequests();
  }

  Future<void> request(String kind) async {
    if (kind == 'deletion') {
      final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Request a deletion review?'),
                  content: const Text(
                      'Our team will review your account and remove your data, then let you know. To delete your account straight away, use Delete account instead.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Send request')),
                  ]));
      if (ok != true || !mounted) return;
    }
    setState(() => busy = kind);
    try {
      await widget.store.requestMyData(kind);
      if (mounted) {
        showNotice(
            context,
            kind == 'export'
                ? 'Requested. We’ll email you when your data is ready.'
                : 'Requested. We’ll be in touch.');
      }
    } catch (e) {
      if (mounted) {
        showNotice(
            context, errorMessage(e, 'Couldn’t send that request. Try again.'));
      }
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final enabled = store.canContactSupport && busy == null;
        return Scaffold(
            appBar: AppBar(
                title: const Text('Your data', style: TextStyle(fontSize: 17))),
            body: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        children: [
                          Text(
                              store.canContactSupport
                                  ? 'You can ask for a copy of everything we hold about you, or for our team to review and delete it.'
                                  : 'Sign in to request your data.',
                              style: TextStyle(
                                  color: EverlaneColors.muted, height: 1.5)),
                          const SizedBox(height: 12),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.download_rounded),
                              title: const Text('Download my data'),
                              subtitle:
                                  _subtitle('We’ll prepare a copy for you'),
                              trailing: busy == 'export'
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : null,
                              onTap: enabled ? () => request('export') : null),
                          const Divider(height: 1),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.manage_history_rounded),
                              title:
                                  const Text('Request account deletion review'),
                              subtitle: _subtitle(
                                  'Our team reviews and removes your data'),
                              trailing: busy == 'deletion'
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : null,
                              onTap:
                                  enabled ? () => request('deletion') : null),
                          if (store.dataRequests.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Eyebrow('Your requests'),
                            const SizedBox(height: 6),
                            for (final r in store.dataRequests)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(r.kind == 'export'
                                      ? 'Data download'
                                      : 'Deletion review'),
                                  subtitle: _subtitle([
                                    _statusLabel(r.status),
                                    if (r.completedAt != null)
                                      'Completed ${shortDate(r.completedAt)}'
                                    else
                                      shortDate(r.createdAt),
                                    if (r.note.isNotEmpty) r.note,
                                  ].where((x) => x.isNotEmpty).join(' · '))),
                          ],
                        ]))));
      });
}

/// Your invite code with a copy button and how many friends joined.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.loadReferral();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Invite friends', style: TextStyle(fontSize: 17))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [InviteCard(store: widget.store)]))));
}

class InviteCard extends StatefulWidget {
  const InviteCard({super.key, required this.store});
  final PreviewStore store;
  @override
  State<InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<InviteCard> {
  @override
  void initState() {
    super.initState();
    if (widget.store.referral == null) widget.store.loadReferral();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final r = store.referral;
        final days = r?.rewardDays ?? store.settings.referralRewardDays;
        final plan = store.settings.referralRewardPlan.isEmpty
            ? 'Plus'
            : '${store.settings.referralRewardPlan[0].toUpperCase()}${store.settings.referralRewardPlan.substring(1)}';
        return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: EverlaneColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: EverlaneColors.line)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.card_giftcard_rounded,
                    size: 20, color: EverlaneColors.like),
                SizedBox(width: 8),
                Text('Invite friends',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text(
                  days > 0
                      ? 'Share your code. When a friend joins, you get $days days of $plan.'
                      : 'Share your code with friends who’d love Everlane.',
                  style: TextStyle(
                      fontSize: 13, height: 1.4, color: EverlaneColors.muted)),
              const SizedBox(height: 14),
              if (r == null || r.code.isEmpty)
                Text('Loading your code…',
                    style: TextStyle(color: EverlaneColors.muted))
              else ...[
                Row(children: [
                  Expanded(
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                              color: EverlaneColors.blush,
                              borderRadius: BorderRadius.circular(12)),
                          child: SelectableText(r.code,
                              style: const TextStyle(
                                  fontSize: 18,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700)))),
                  const SizedBox(width: 8),
                  IconButton(
                      tooltip: 'Copy invite',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(
                            text:
                                'Join me on Everlane with my invite code ${r.code}'));
                        if (context.mounted) {
                          showNotice(context, 'Invite copied');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded)),
                ]),
                const SizedBox(height: 10),
                Text(
                    r.joined == 1
                        ? '1 friend joined'
                        : '${r.joined} friends joined',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ]));
      });
}
