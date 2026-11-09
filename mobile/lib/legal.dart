// Everlane Privacy Policy and Terms & Conditions.
//
// The published text lives in Supabase (legal_docs, edited in the admin
// panel); these are the fallbacks. Keep in sync with web/privacy.html and
// web/terms.html.

import 'package:flutter/material.dart';

import 'backend.dart';
import 'theme.dart';

const legalUpdated = '8 November 2026';

/// Privacy Policy sections: (heading, body).
const privacyPolicySections = <(String, String)>[
  (
    '1. Information We Collect',
    'We collect information necessary to operate our matchmaking, compatibility, and social meetup services:\n• Account Information: We collect your name, age, date of birth, gender, phone number, email address, photographs, bio, and dating preferences during registration.\n• Verification Data: If you apply for a verified profile badge, we process your verification selfie or identity confirmation media strictly to authenticate your profile.\n• Compatibility Data: We process your questionnaire responses and interaction preferences to generate area-by-area Chemistry reports.\n• Location Data: With your permission, we collect precise or approximate location data to show nearby profiles and facilitate local Hangouts.\n• Payment Information: When you purchase a paid plan via a UPI app, we collect transaction reference numbers (UTR), payment screenshots, or UPI IDs required for manual verification.',
  ),
  (
    '2. How We Use Your Information',
    'We process your personal data strictly for the following purposes:\n• Core Matchmaking: Operating your profile, delivering daily likes, sending weekly Sparks, applying monthly profile boosts, and calculating Chemistry reports.\n• Hangouts Feature: Enabling eligible members to host or join plans nearby and coordinate local meetups with other users.\n• Payment Verification: Manually verifying your UPI payment, which typically takes a few hours before your upgraded plan turns on.\n• Platform Safety: Detecting bots, preventing fraud, enforcing community guidelines, and investigating reported accounts.',
  ),
  (
    'Automated profiles',
    'Alongside real members, Everlane runs some automated profiles that we create ourselves. They are labelled "Automated profile" in the app and are not real people; their replies are automatic. Messages you send to an automated profile are stored like any other message so the conversation works, and are handled under this policy. Please do not share personal details with them.',
  ),
  (
    '3. Data Sharing and Disclosure',
    'We do not sell your personal data to third-party advertisers or data brokers. We share data only in the following contexts:\n• With Other Users: Your public profile, photos, verification badge, and hosted Hangouts activity are visible to other platform members.\n• Service Providers: We use trusted hosting, database, and communication providers bound by strict confidentiality obligations.\n• Legal Compliance: We may disclose information if required by Indian law, court order, or law enforcement agencies investigating cybercrime or safety threats.',
  ),
  (
    '4. Data Retention and Deletion',
    'We retain your personal data only as long as your account remains active. When you delete your account, your profile, photos, and chat history are permanently erased from our active databases within 30 days, except for transaction records required for tax or legal compliance (retained for up to 7 years).',
  ),
  (
    '5. Your Rights Under the DPDP Act',
    'Under India\'s Digital Personal Data Protection Act, 2023, you hold the following rights regarding your data:\n• Right to Access: You may request a summary of the personal data we process and any third parties with whom it is shared.\n• Right to Correction: You may update inaccurate or incomplete personal details directly through your profile settings.\n• Right to Erasure: You may delete your account or request complete erasure of your personal data at any time.\n• Consent Withdrawal: You may revoke permissions such as location access via your device settings, though location-based matching will be limited.',
  ),
  (
    '6. Security Safeguards',
    'We implement encryption in transit (HTTPS/TLS), database access controls, and secure authentication protocols to protect your personal information against unauthorized access or disclosure.',
  ),
  (
    '7. Grievance Officer and Contact',
    'For privacy inquiries, data access requests, or complaints, please contact our Grievance Officer:\npreetsoni7847@gmail.com',
  ),
];

/// Terms & Conditions sections: (heading, body).
const termsSections = <(String, String)>[
  (
    '1. Acceptance of Terms and Eligibility',
    'By creating an account or accessing everlanedating.com, you agree to be bound by these Terms and Conditions. You must be at least 18 years of age and legally permitted to form a binding contract under the Indian Contract Act, 1872.',
  ),
  (
    '2. Membership Plans and Features',
    'Everlane Dating offers a Free member tier alongside paid subscription upgrades (Plus, Gold, and Platinum):\n• Gold Plan: Priced at ₹499 per month, Gold includes everything in Plus, seeing who liked you, 50 likes each day, 2 Sparks each week, and 2 profile boosts each month.\n• Platinum Plan: Priced at ₹899 per month, Platinum includes everything in Gold, 100 likes each day, 3 Sparks each week, 5 profile boosts each month, a detailed Chemistry report, and Hangouts access.\n• Feature Allocation: Daily likes, weekly Sparks, and monthly profile boosts reset on their respective cycles and do not carry over or hold cash value.',
  ),
  (
    '3. Payments, Manual Verification, and Cancellations',
    'All paid subscriptions are subject to the following billing and verification rules:\n• UPI Payments: Paid plans can be purchased using any supported UPI app.\n• Manual Verification: We verify every payment by hand, usually within a few hours, and your upgraded plan turns on once payment is verified.\n• Subscriptions: Gold renews monthly at ₹499 and Platinum renews monthly at ₹899 until you cancel.\n• Cancellation Policy: You may cancel your subscription anytime through your account settings to prevent future billing cycles.\n• Refund Policy: Payments for verified active subscription cycles are non-refundable, except where a duplicate deduction occurs due to a verified technical error.',
  ),
  (
    '4. Hangouts and Offline Safety Disclaimer',
    'The Hangouts feature allows eligible members to host or join plans nearby. Everlane Dating does not conduct criminal background checks on users and does not supervise offline events. You are solely responsible for your personal safety when meeting other users, and you must always meet in public places and inform a trusted contact of your plans.',
  ),
  (
    '5. User Conduct and Community Guidelines',
    'To maintain a safe platform, you agree not to engage in any of the following prohibited actions:\n• Impersonation: Creating fake profiles, misrepresenting your age or identity, or uploading photographs belonging to another person.\n• Harassment: Sending abusive, defamatory, obscene, or threatening messages to other members or support staff.\n• Commercial Solicitation: Using the platform or Hangouts to promote third-party businesses, scams, or unlawful activities.\n• Payment Fraud: Submitting falsified, altered, or duplicate UPI payment references during subscription verification.',
  ),
  (
    'Automated profiles',
    'Some profiles on Everlane are automated profiles that we create ourselves. They are labelled "Automated profile" in the app. They are not real people: their replies are automatic and they may like you back or match with you automatically. They never host or join Hangouts, never arrange to meet, and never ask for money or contact details. Likes, matches or messages from automated profiles are not interest from real members.',
  ),
  (
    '6. Account Suspension and Termination',
    'We reserve the right to suspend or permanently terminate your account without refund if you violate these Terms, submit fraudulent UPI payment proofs, or engage in behavior that threatens the safety of our community.',
  ),
  (
    '7. Limitation of Liability',
    'Everlane Dating provides the platform on an "as-is" and "as-available" basis. To the maximum extent permitted by law, we are not liable for any indirect damages, Compatibility or Chemistry report outcomes, user disputes, or incidents arising from online interactions or offline Hangouts.',
  ),
  (
    '8. Governing Law and Jurisdiction',
    'These Terms are governed by the laws of India. Any legal disputes arising out of your use of the platform shall be subject to the exclusive jurisdiction of the courts in India.',
  ),
];

/// Community Guidelines, used when the published version can't be loaded.
const guidelinesSections = <(String, String)>[
  (
    'Be kind',
    'Treat everyone with respect, online and when you meet. No harassment, hate speech, threats or bullying. A polite "no thanks" is always fine.',
  ),
  (
    'Be real',
    'Use your own name, age and recent photos of you. Don\'t pretend to be someone else or mislead people about who you are.',
  ),
  (
    'Stay safe',
    'Meet in public places, tell a friend your plans and keep personal and financial details private until you trust someone.',
  ),
  (
    'No selling',
    'Everlane is for meeting people, not for promoting products, services, other apps or asking for money. No spam, scams or solicitation.',
  ),
  (
    'Adults only',
    'You must be 18 or older to use Everlane. No sexual content involving minors, ever. We report it to the authorities.',
  ),
  (
    'Reporting',
    'If someone breaks these guidelines, report them from their profile or your chat. Reports are confidential, and our team reviews every one.',
  ),
];

/// A legal document as published in the admin panel (`legal_doc()`).
class LegalDoc {
  const LegalDoc(
      {required this.title, required this.sections, required this.version});

  /// Null when the row has no usable sections.
  static LegalDoc? fromJson(Map<String, dynamic> j, String fallbackTitle) {
    final sections = [
      for (final s in j['sections'] as List? ?? const [])
        if (s is Map)
          ('${s['heading'] ?? ''}', '${s['body'] ?? ''}')
    ].where((s) => s.$1.isNotEmpty || s.$2.isNotEmpty).toList();
    if (sections.isEmpty) return null;
    final title = j['title'];
    final version = j['version'];
    return LegalDoc(
        title: title is String && title.isNotEmpty ? title : fallbackTitle,
        sections: sections,
        version: version is String && version.isNotEmpty ? version : legalUpdated);
  }

  final String title, version;
  final List<(String, String)> sections;
}

/// Set at start-up when Supabase is reachable; null in tests and offline,
/// where the built-in documents above are shown.
ProfileBackend? legalBackend;

/// Published documents loaded so far, by slug.
final Map<String, LegalDoc> legalDocs = {};

/// The published document, or null (no backend, offline, or unpublished).
Future<LegalDoc?> loadLegalDoc(String slug, {String title = ''}) async {
  final b = legalBackend;
  if (b == null) return legalDocs[slug];
  try {
    final row = await b.legalDoc(slug);
    final doc = row == null ? null : LegalDoc.fromJson(row, title);
    if (doc != null) legalDocs[slug] = doc;
    return doc ?? legalDocs[slug];
  } catch (_) {
    return legalDocs[slug];
  }
}

/// The terms version a member agrees to: the published one when known.
Future<String> termsVersion() async =>
    (await loadLegalDoc('terms'))?.version ?? legalUpdated;

/// Shows a legal document as a readable, scrollable list of sections,
/// centred at a comfortable reading width. With a [slug] it shows the
/// version published in the admin panel, falling back to [sections].
class LegalScreen extends StatefulWidget {
  const LegalScreen(
      {super.key, required this.title, required this.sections, this.slug});

  final String title;
  final List<(String, String)> sections;

  /// 'privacy', 'terms' or 'guidelines'.
  final String? slug;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late LegalDoc? doc = widget.slug == null ? null : legalDocs[widget.slug];
  late bool loading = widget.slug != null && legalBackend != null;

  @override
  void initState() {
    super.initState();
    final slug = widget.slug;
    if (slug == null || legalBackend == null) return;
    loadLegalDoc(slug, title: widget.title).then((d) {
      if (mounted) {
        setState(() {
          doc = d;
          loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = doc?.title ?? widget.title;
    final sections = doc?.sections ?? widget.sections;
    final version = doc?.version ?? legalUpdated;
    final text = Theme.of(context).textTheme;
    final body = text.bodyLarge?.copyWith(fontSize: 15, height: 1.5) ??
        const TextStyle(fontSize: 15, height: 1.5);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: loading && doc == null
                ? const CircularProgressIndicator(color: EverlaneColors.like)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    itemCount: sections.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('Last updated: $version',
                              style: body.copyWith(
                                  fontSize: 13, color: EverlaneColors.muted)),
                        );
                      }
                      final (heading, content) = sections[i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(heading,
                                style: body.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3)),
                            const SizedBox(height: 8),
                            SelectableText(content, style: body),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Opens the Privacy Policy.
void openPrivacyPolicy(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const LegalScreen(
        title: 'Privacy Policy',
        sections: privacyPolicySections,
        slug: 'privacy'),
  ));
}

/// Opens the Terms & Conditions.
void openTerms(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const LegalScreen(
        title: 'Terms & Conditions', sections: termsSections, slug: 'terms'),
  ));
}

/// Opens the Community Guidelines.
void openGuidelines(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const LegalScreen(
        title: 'Community guidelines',
        sections: guidelinesSections,
        slug: 'guidelines'),
  ));
}
