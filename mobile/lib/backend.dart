import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart' show Hangout;
import 'supabase_config.dart';

/// Talks to Supabase for the signed-in member's own account, profile row and
/// photos. Discovery, likes and chat still run on the in-memory demo data.
///
/// The app runs without one (tests, or Supabase unreachable) and then keeps
/// everything in memory, as the preview always did.
class ProfileBackend {
  ProfileBackend(this.client);
  final SupabaseClient client;

  static const _bucket = 'photos';

  User? get user => client.auth.currentUser;
  bool get signedIn => user != null;

  Future<void> signUp(String email, String password) async {
    final res = await client.auth.signUp(email: email, password: password);
    // With email confirmation on, Supabase creates the user but no session.
    if (res.session == null) {
      throw const AuthException(
          'Check your inbox to confirm your email, then log in.');
    }
  }

  Future<void> logIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  /// Where Google sends the member back: the page itself on the web, the
  /// app's own link on Android and iOS (registered in AndroidManifest.xml
  /// and Info.plist). Both must be in Supabase's Redirect URLs list.
  static const appCallback = 'com.everlane.everlane://login-callback';

  /// Google sign-in. On the web this leaves the page for Google and comes
  /// back signed in; in the app it opens the browser and returns through
  /// [appCallback]. Supabase picks the session up either way.
  /// Needs the Google provider (client ID + secret) enabled in Supabase.
  /// Checked first, so a switched-off provider shows a message in the app
  /// instead of sending the member to Supabase's error page.
  Future<void> continueWithGoogle() async {
    if (!await _providerEnabled('google')) {
      throw const AuthException('Google provider is not enabled');
    }
    await client.auth.signInWithOAuth(OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : appCallback);
  }

  /// Whether a sign-in provider is switched on in Supabase's Auth settings.
  Future<bool> _providerEnabled(String provider) async {
    final res = await http.get(Uri.parse('$supabaseUrl/auth/v1/settings'),
        headers: {'apikey': supabasePublishableKey});
    if (res.statusCode != 200) return true; // let Supabase report it
    final external = (jsonDecode(res.body) as Map)['external'] as Map?;
    return external?[provider] == true;
  }

  /// Sends a one-time code by SMS to [phone] (E.164, e.g. +919876543210).
  /// Needs the Phone provider and an SMS service set up in Supabase.
  Future<void> sendPhoneCode(String phone) =>
      client.auth.signInWithOtp(phone: phone);

  Future<void> verifyPhoneCode(String phone, String code) =>
      client.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);

  Future<void> logOut() => client.auth.signOut();

  /// Ids of the admin-made bot profiles, which the app labels as samples.
  Future<Set<String>> sampleProfileIds() async {
    final data = await client.rpc('sample_profile_ids');
    return {
      for (final x in data as List)
        (x is Map ? x.values.first : x) as String
    };
  }

  /// Compatibility quiz answers of the given members, keyed by member id.
  /// Members who haven't taken the quiz are left out.
  Future<Map<String, Map<String, List<String>>>> quizAnswersOf(
      List<String> ids) async {
    final rows = _rows(await client.rpc('quiz_answers_of', params: {'ids': ids}));
    return {
      for (final r in rows)
        r['id'] as String: {
          for (final e in (r['quiz_answers'] as Map).entries)
            e.key as String: List<String>.from(e.value as List)
        }
    };
  }

  Future<Map<String, dynamic>?> loadProfile() =>
      client.from('profiles').select().eq('id', user!.id).maybeSingle();

  Future<void> saveProfile(Map<String, dynamic> row) =>
      client.from('profiles').upsert({
        ...row,
        'id': user!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  /// Uploads into the member's own folder and returns the storage path.
  Future<String> uploadPhoto(Uint8List bytes) async {
    final (ext, mime) = _imageType(bytes);
    final path = '${user!.id}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await client.storage.from(_bucket).uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: mime));
    return path;
  }

  /// Uploads a live-selfie burst into the private "verifications" bucket
  /// and queues it for an admin to review.
  Future<void> submitVerification(List<Uint8List> frames) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final paths = <String>[];
    for (final (i, bytes) in frames.indexed) {
      final (ext, mime) = _imageType(bytes);
      final path = '${user!.id}/$stamp-$i.$ext';
      await client.storage.from('verifications').uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: mime));
      paths.add(path);
    }
    await client.rpc('submit_verification', params: {'frames': paths});
  }

  /// The member's latest verification request: its status ('pending',
  /// 'approved', 'rejected') and the reviewer's note, or null if none.
  Future<({String status, String note})?> latestVerification() async {
    final row = await client
        .from('verification_requests')
        .select('status, note')
        .eq('user_id', user!.id)
        .neq('status', 'replaced')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return (status: row['status'] as String, note: row['note'] as String);
  }

  Future<Uint8List> downloadPhoto(String path) =>
      client.storage.from(_bucket).download(path);

  Future<void> deletePhoto(String path) =>
      client.storage.from(_bucket).remove([path]);

  String photoUrl(String path) =>
      client.storage.from(_bucket).getPublicUrl(path);

  // ---- Voice prompt (a WAV of up to 30 seconds) ----

  static const _voiceBucket = 'voice';

  Future<String> uploadVoice(Uint8List wav) async {
    final path = '${user!.id}/${DateTime.now().microsecondsSinceEpoch}.wav';
    await client.storage.from(_voiceBucket).uploadBinary(path, wav,
        fileOptions: const FileOptions(contentType: 'audio/wav'));
    return path;
  }

  Future<void> deleteVoice(String path) =>
      client.storage.from(_voiceBucket).remove([path]);

  String voiceUrl(String path) =>
      client.storage.from(_voiceBucket).getPublicUrl(path);

  /// Deletes the member's files, then their account; the database cascades
  /// to everything else (see migration 006).
  Future<void> deleteAccount(
      {required List<String> photos, String voice = ''}) async {
    if (photos.isNotEmpty) await client.storage.from(_bucket).remove(photos);
    if (voice.isNotEmpty) await deleteVoice(voice);
    await client.rpc('delete_my_account');
    await client.auth.signOut();
  }

  // ---- Admin-managed content (readable without signing in) ----

  Future<List<Map<String, dynamic>>> quizQuestions() async => _rows(await client
      .from('quiz_questions')
      .select()
      .eq('active', true)
      .order('position'));

  /// Monthly plan prices for India, as set in the admin panel.
  Future<List<Map<String, dynamic>>> planPrices() async => _rows(await client
      .from('plan_prices')
      .select('plan, price, symbol')
      .eq('country', 'India')
      .eq('active', true));

  Future<List<Map<String, dynamic>>> appOptions() async => _rows(await client
      .from('app_options')
      .select('kind, value')
      .eq('active', true)
      .order('position'));

  // ---- Moderation (see migration 007) ----

  Future<void> report(String member, String reason) =>
      client.rpc('submit_report', params: {'member': member, 'reason': reason});

  Future<void> acknowledgeWarning() => client.rpc('acknowledge_warning');

  // ---- Crossed paths (see migration 008) ----

  /// The database snaps these to a ~1 km area again, so an exact spot is
  /// never stored even if one is sent.
  Future<void> recordArea(double lat, double lng) =>
      client.rpc('record_area', params: {'lat': lat, 'lng': lng});

  Future<List<Map<String, dynamic>>> crossedPaths() async =>
      _rows(await client.rpc('crossed_paths'));

  Future<void> clearAreas() => client.rpc('clear_my_areas');

  // ---- Hangouts (see migration 020) ----

  Future<List<Map<String, dynamic>>> hangoutsNear({int? maxKm}) async =>
      _rows(await client.rpc('hangouts_near',
          params: {if (maxKm != null) 'max_km': maxKm}));

  Future<void> hostHangout(Hangout h) => client.rpc('host_hangout', params: {
        'kind': h.kind.name,
        'title': h.title,
        'starts_at': h.startsAt.toUtc().toIso8601String(),
        'area': h.area,
        'venue': h.venue,
        'city': h.city,
        'note': h.note,
        'looking_for': h.lookingFor,
        'spots': h.spots,
      });

  Future<void> cancelHangout(String id) =>
      client.rpc('cancel_hangout', params: {'plan': id});

  /// Returns your request's status: 'pending', or 'accepted' straight away
  /// for a sample profile's plan.
  Future<String?> requestHangout(String id) async =>
      await client.rpc('request_hangout', params: {'plan': id}) as String?;

  Future<List<Map<String, dynamic>>> hangoutRequestsMine() async =>
      _rows(await client.rpc('hangout_requests_mine'));

  Future<void> answerHangoutRequest(String plan, String member,
          {required bool accept}) =>
      client.rpc('answer_hangout_request',
          params: {'plan': plan, 'who': member, 'accept': accept});

  // ---- Discovery, likes, matches and chat ----

  /// People to discover; with [maxKm], only those within that distance
  /// of your city (or in your city when a location isn't known).
  Future<List<Map<String, dynamic>>> discover({int? maxKm}) async =>
      _rows(await client.rpc('discover_members',
          params: {if (maxKm != null) 'max_km': maxKm}));

  Future<List<Map<String, dynamic>>> likesReceived() async =>
      _rows(await client.rpc('likes_received'));

  Future<List<Map<String, dynamic>>> myMatches() async =>
      _rows(await client.rpc('my_matches'));

  Future<List<Map<String, dynamic>>> messages(String matchId) async =>
      _rows(await client
          .from('messages')
          .select()
          .eq('match_id', matchId)
          .order('created_at'));

  /// Likes [to]; returns the match id if they had already liked you back.
  Future<String?> like(String to, {String target = 'photo', String comment = ''}) async {
    final me = user!.id;
    await client.from('likes').upsert(
        {'from_user': me, 'to_user': to, 'target': target, 'comment': comment},
        ignoreDuplicates: true);
    return matchWith(to);
  }

  Future<String?> matchWith(String other) async {
    final me = user!.id;
    final row = await client
        .from('matches')
        .select('id')
        .or('and(user_a.eq.$me,user_b.eq.$other),and(user_a.eq.$other,user_b.eq.$me)')
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<void> pass(String to) => client
      .from('passes')
      .upsert({'from_user': user!.id, 'to_user': to}, ignoreDuplicates: true);

  Future<void> unpass(String to) => client
      .from('passes')
      .delete()
      .eq('from_user', user!.id)
      .eq('to_user', to);

  Future<void> unmatch(String matchId) =>
      client.from('matches').delete().eq('id', matchId);

  Future<void> sendMessage(String matchId, String body) => client
      .from('messages')
      .insert({'match_id': matchId, 'sender': user!.id, 'body': body});

  /// Live updates: new messages in your matches, new matches, new likes.
  /// Row-level security decides which rows each member actually receives.
  RealtimeChannel listen({
    required void Function(Map<String, dynamic> message) onMessage,
    required void Function(Map<String, dynamic> match) onMatch,
    required void Function(Map<String, dynamic> like) onLike,
  }) {
    final me = user!.id;
    return client
        .channel('everlane-$me')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (p) => onMessage(p.newRecord))
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'matches',
            callback: (p) => onMatch(p.newRecord))
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'likes',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'to_user',
                value: me),
            callback: (p) => onLike(p.newRecord))
        .subscribe();
  }

  Future<void> stopListening(RealtimeChannel channel) =>
      client.removeChannel(channel);

  static List<Map<String, dynamic>> _rows(dynamic data) =>
      [for (final r in data as List) Map<String, dynamic>.from(r as Map)];

  /// Sniffs the file signature; picked photos don't carry a reliable name.
  static (String, String) _imageType(Uint8List b) {
    bool at(int i, List<int> sig) =>
        b.length >= i + sig.length &&
        [for (var j = 0; j < sig.length; j++) b[i + j]].join(',') ==
            sig.join(',');
    if (at(0, [0x89, 0x50, 0x4E, 0x47])) return ('png', 'image/png');
    if (at(0, [0x47, 0x49, 0x46])) return ('gif', 'image/gif');
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
      return ('webp', 'image/webp');
    }
    if (at(4, [0x66, 0x74, 0x79, 0x70])) return ('heic', 'image/heic');
    return ('jpg', 'image/jpeg');
  }
}

/// The database refuses messages and profile text with a banned word
/// (migration 007) with this error.
bool isBannedWordError(Object e) =>
    e is PostgrestException && e.message.contains('banned_word');
