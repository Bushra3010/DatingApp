// Everlane Privacy Policy and Terms & Conditions.
//
// TEMPLATE: to be reviewed by a lawyer before launch. Fill in every
// [placeholder]. Keep in sync with web/privacy.html and web/terms.html.

import 'package:flutter/material.dart';

import 'theme.dart';

const legalUpdated = '31 October 2026';

/// Privacy Policy sections: (heading, body).
const privacyPolicySections = <(String, String)>[
  (
    'Who we are',
    'Everlane is a dating app for adults in India, available on the web at everlane-topaz.vercel.app and as a mobile app. It is operated by [company legal name], [registered address] ("Everlane", "we", "us").\n\nThis policy explains what personal data we collect, why, who we share it with, how long we keep it and the rights you have under India\'s Digital Personal Data Protection Act, 2023 (DPDP Act). By creating an account you give consent to the processing described here. You can withdraw that consent at any time by deleting your account.\n\nQuestions: [support email].',
  ),
  (
    'Information you give us',
    '• Account: your email address, your phone number (if you sign up with a one-time code by SMS), or your Google account\'s email and name (if you sign in with Google). If you use email, your password is handled by our authentication provider and we never see it in plain text.\n• Profile: name, date of birth (to show your age and confirm you are 18 or over), gender, who you want to meet, height, languages, city, job, bio, prompt answers, interests, photos and, if you choose, a recorded voice prompt.\n• Compatibility quiz: your answers, used to suggest people and show how well you match.\n• Activity: the people you like and pass on, your matches and the messages you send.\n• Hangouts: plans you host (type, title, time, area, exact venue, city, notes, number of spots) and requests you send or accept to join plans.\n• Verification: if you ask for the verified badge, a short burst of live selfie frames from your front camera.\n• Safety: reports you make, and anything you tell us when you contact support.',
  ),
  (
    'Location',
    'We only use your location at the level of a city.\n\n• Your city: you pick it from a list. If you tap "use my current location", your device works out the nearest listed city and only that city is saved. We do not store your exact coordinates for this.\n• Distance: distances to other people are calculated from city centres, not from where you actually are.\n• Crossed paths (optional): if you turn this on, the app saves the roughly 1 km area you are in, with the date, so it can show people who were in the same area on the same day. It is off until you share your area, older areas are deleted after 30 days, and you can clear all of them at any time.\n• Hangouts: other members see a plan\'s general area. The exact venue is shown only to the host and to guests the host has accepted.',
  ),
  (
    'Sample profiles',
    'Alongside real members, Everlane runs some sample profiles that we create ourselves. They are labelled "Sample profile" in the app. They are not real people: their replies are automatic, and they may like you, match with you or accept a Hangouts request automatically. Messages you send to a sample profile are stored like any other message so the conversation works, and are handled under this policy. Please do not share personal details with them or arrange to meet them.',
  ),
  (
    'How we use your information',
    '• To create and run your account and sign you in.\n• To show your profile to other members and suggest people to you, based on your preferences, city, distance and quiz answers.\n• To deliver likes, matches, messages and Hangouts.\n• To verify that profiles belong to real people.\n• To keep Everlane safe: filtering banned words from messages and profile text, reviewing reports, and acting against accounts that break our Terms.\n• To manage premium plans.\n• To answer your questions and tell you about important changes.\n\nWe do not sell your personal data, and we do not use it for third-party advertising.',
  ),
  (
    'What other members see',
    'Members you are shown to can see your profile: name, age (not your full date of birth), gender, height, languages, city, distance, job, bio, prompts, interests, photos, voice prompt and verified badge. Your messages are seen by the person you send them to. Your email address and phone number are never shown to other members.',
  ),
  (
    'Safety and moderation',
    '• Messages and profile text containing words on our banned list are blocked.\n• When you report someone, we keep the report, its reason and details, and a copy of the last few messages between you, so our team can review what happened.\n• Our admins can see reports and the attached messages, and can warn, suspend or block accounts. They do not read conversations that have not been reported.\n• Verification selfies are stored in a private storage area that only our admins can open. An admin compares them with your profile photos to decide whether to give you the verified badge.\n• We may keep or share information where the law requires it, or where it is needed to protect someone\'s safety.',
  ),
  (
    'Who we share data with',
    'We use a small number of service providers (data processors) who handle data only on our instructions:\n\n• Supabase: database, sign-in and file storage for profiles, photos, voice prompts, messages and verification selfies.\n• Vercel: hosting for the Everlane web app.\n• Google: only if you choose "Sign in with Google", to confirm your identity.\n• An SMS provider used by our sign-in service, only if you sign up with your phone number, to send your one-time code.\n\nThese providers may store or process data on servers outside India. We share data with authorities only when required by law. If Everlane is ever sold or merged, your data would move to the new owner under this policy, and we would tell you first.',
  ),
  (
    'How long we keep data',
    'We keep your data while your account is open.\n\nWhen you tap Delete account in Settings, your account is deleted along with your profile, likes, passes, matches, messages, quiz answers, Hangouts and crossed-paths areas. Your photos and voice prompt are removed from storage. Messages you sent are removed from the other person\'s chat too.\n\nWe may keep a limited record for longer where we need it for safety or legal reasons, for example reports about an account that was suspended or blocked, or where the law requires us to keep it. Verification selfies are deleted once they are no longer needed for verification. Backups held by our providers are overwritten on their normal schedule.',
  ),
  (
    'Your rights',
    'Under the DPDP Act you have the right to:\n\n• Access: ask for a summary of the personal data we hold about you and how we use it.\n• Correction and updating: most of your profile can be edited in the app at any time; you can ask us to correct anything else.\n• Erasure: delete your account in Settings, or ask us to delete specific data.\n• Withdraw consent: you can stop at any time by deleting your account. This does not affect processing done before.\n• Grievance redressal: complain to our Grievance Officer (below), and, if you are not satisfied, to the Data Protection Board of India.\n• Nominate: name someone who can exercise these rights for you if you die or are unable to.\n\nTo use any of these rights, write to [support email] from the email or phone number linked to your account. We may need to confirm it is you before we act.',
  ),
  (
    'Grievance Officer',
    'Name: [Grievance Officer name]\nEmail: [support email]\nAddress: [company legal name], [registered address]\n\nWe will acknowledge your complaint and aim to resolve it within the time limits set by applicable law.',
  ),
  (
    'Security',
    'Data is sent over encrypted connections (HTTPS). Access to the database is controlled by per-user rules, so members can only reach the data they are meant to see, and admin tools are limited to authorised staff. No system is completely secure. If a breach affects your personal data, we will notify you and the Data Protection Board as the law requires.',
  ),
  (
    'Age limit and children',
    'Everlane is only for people aged 18 and over. We do not knowingly collect data from anyone under 18. If we learn that an account belongs to someone under 18, we will delete it. If you believe a minor is using Everlane, please report the profile or write to [support email].',
  ),
  (
    'Changes to this policy',
    'We may update this policy as the app changes. We will change the "Last updated" date above and, for significant changes, tell you in the app before they take effect.',
  ),
  (
    'Contact',
    '[company legal name]\n[registered address]\nEmail: [support email]',
  ),
];

/// Terms & Conditions sections: (heading, body).
const termsSections = <(String, String)>[
  (
    'Agreement',
    'These Terms are an agreement between you and [company legal name], [registered address] ("Everlane", "we", "us"). By creating an account or using Everlane you accept these Terms and our Privacy Policy. If you do not agree, do not use Everlane.',
  ),
  (
    'Who can use Everlane',
    '• You must be at least 18 years old.\n• You must be legally able to enter a contract in India and not barred from using the service under any law.\n• You must not have been removed from Everlane before, unless we have agreed otherwise.\n• You may have only one account, and it must be for you.',
  ),
  (
    'Your account',
    'Keep your sign-in details safe and do not share your account. You are responsible for what happens on it. Give accurate information about yourself, including your age, and keep it up to date. Tell us at [support email] if you think someone else has accessed your account.',
  ),
  (
    'Community rules',
    'Treat people the way you would want to be treated. You must not:\n\n• harass, bully, threaten, stalk or intimidate anyone;\n• post or send nudity, sexual content, or graphic violence;\n• post hate speech or attack people for their religion, caste, race, ethnicity, gender, sexual orientation, disability or any similar trait;\n• scam people, ask for money, gifts, investments or financial details, or promote any business, product or service;\n• offer or ask for sex work or any paid companionship;\n• pretend to be someone else, use other people\'s photos, or give false information about yourself;\n• involve minors in any way, including photos of children without a parent present;\n• share anyone else\'s private information without their consent;\n• use Everlane for anything illegal, or use bots, scrapers or automated tools to access it;\n• try to break, overload or get around the security of the service.\n\nIf someone breaks these rules, please report them from their profile or chat.',
  ),
  (
    'Safety when meeting in person',
    'Everlane does not run criminal background checks or identity checks on members, and a verified badge only means that someone\'s selfie matched their photos. You are responsible for your own safety and your dealings with other members.\n\n• Get to know someone in the app before meeting.\n• Meet in a busy public place, and arrange your own travel there and back.\n• Tell a friend or family member where you are going, who you are meeting and when you expect to be back.\n• Stay in control of your drinks and belongings.\n• Never send money or share bank, card or ID details.\n• Leave if you feel uncomfortable, and report anyone who makes you feel unsafe.\n\nHangouts: hosts choose public venues and decide who joins. The exact venue is only shown to accepted guests, but you may still be meeting several people you do not know. The same tips apply. Hosts must not charge guests or use Hangouts to sell anything.\n\nIn an emergency, call 112.',
  ),
  (
    'Your content',
    'You own the photos, text, voice recordings and messages you post ("your content"). You give Everlane a non-exclusive, royalty-free, worldwide licence to store, display, copy, resize and share your content within the service, only to run and improve Everlane. The licence ends when you delete the content or your account, except for copies kept for safety or legal reasons as described in the Privacy Policy, and messages already delivered to others.\n\nYou confirm you have the right to post your content and that it follows these Terms. We may remove any content that we believe breaks them.',
  ),
  (
    'Sample profiles',
    'Everlane shows some sample profiles that we create ourselves. They are labelled "Sample profile", are not real people, and reply automatically. They may like you, match with you or accept a Hangouts request automatically. Do not share personal details with them or try to meet them. Likes, matches or messages from sample profiles are not interest from real members.',
  ),
  (
    'Premium plans and payments',
    'Some features are offered in paid premium plans. Before you buy, we will show you the price, what is included, the billing period, whether it renews automatically and how to cancel. Prices include applicable taxes unless stated otherwise.\n\n• Subscriptions renew at the end of each period until you cancel. Cancelling stops the next renewal; you keep premium features until the end of the period you have paid for.\n• If you buy through an app store, that store\'s payment terms and refund rules apply, and you manage the subscription there.\n• Payments are not refundable except where the law requires it, where we say otherwise at the time of purchase, or where we end your access without you having broken these Terms.\n• We may change prices or features of plans. Price changes apply from your next billing period and we will tell you in advance.\n\nDuring the current preview no payment is taken.',
  ),
  (
    'Moderation and ending your account',
    'We review reports and may, at our discretion, remove content, warn you, suspend your account or block it permanently if we believe you have broken these Terms or put others at risk. Where it is safe and lawful, we will tell you why. If you think we got it wrong, write to [support email].\n\nYou can stop using Everlane at any time and delete your account in Settings. We may also stop offering Everlane, or any part of it, with reasonable notice.',
  ),
  (
    'Disclaimers',
    'Everlane is provided "as is" and "as available". We do not promise that you will find a match, that the service will always be available or free of errors, or that what members say about themselves is true. We are not responsible for the conduct of any member, online or offline.',
  ),
  (
    'Limitation of liability',
    'To the extent the law allows, Everlane and its team are not liable for any indirect, incidental or consequential loss, or for loss of data, profits or goodwill, arising from your use of Everlane or your dealings with other members. Our total liability to you for any claim is limited to the amount you paid us in the 12 months before the claim, or INR 1,000 if you have not paid us. Nothing in these Terms limits liability that cannot be limited by law.\n\nYou agree to cover Everlane for losses caused by your breach of these Terms or misuse of the service.',
  ),
  (
    'Governing law and disputes',
    'These Terms are governed by the laws of India. Please contact us first so we can try to resolve any problem. If we cannot, the courts at [city of jurisdiction] will have exclusive jurisdiction, subject to any rights you have under consumer protection law.',
  ),
  (
    'Changes to these Terms',
    'We may update these Terms as Everlane changes. We will update the "Last updated" date above and, for significant changes, tell you in the app before they take effect. If you keep using Everlane after that, you accept the new Terms.',
  ),
  (
    'Contact',
    '[company legal name]\n[registered address]\nEmail: [support email]\nGrievance Officer: [Grievance Officer name], [support email]',
  ),
];

/// Shows a legal document (Privacy Policy or Terms) as a readable, scrollable
/// list of sections, centred at a comfortable reading width.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
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
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              itemCount: sections.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Last updated: $legalUpdated',
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
        title: 'Privacy Policy', sections: privacyPolicySections),
  ));
}

/// Opens the Terms & Conditions.
void openTerms(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) =>
        const LegalScreen(title: 'Terms & Conditions', sections: termsSections),
  ));
}
