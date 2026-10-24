import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Google sign-in. On the web this leaves the page for Google and comes
  /// back signed in; Supabase picks the session up when the app reloads.
  /// Needs the Google provider (client ID + secret) enabled in Supabase.
  Future<void> continueWithGoogle() => client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: Uri.base.origin);

  /// Sends a one-time code by SMS to [phone] (E.164, e.g. +919876543210).
  /// Needs the Phone provider and an SMS service set up in Supabase.
  Future<void> sendPhoneCode(String phone) =>
      client.auth.signInWithOtp(phone: phone);

  Future<void> verifyPhoneCode(String phone, String code) =>
      client.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);

  Future<void> logOut() => client.auth.signOut();

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

  Future<Uint8List> downloadPhoto(String path) =>
      client.storage.from(_bucket).download(path);

  Future<void> deletePhoto(String path) =>
      client.storage.from(_bucket).remove([path]);

  String photoUrl(String path) =>
      client.storage.from(_bucket).getPublicUrl(path);

  // ---- Admin-managed content (readable without signing in) ----

  Future<List<Map<String, dynamic>>> quizQuestions() async => _rows(await client
      .from('quiz_questions')
      .select()
      .eq('active', true)
      .order('position'));

  Future<List<Map<String, dynamic>>> appOptions() async => _rows(await client
      .from('app_options')
      .select('kind, value')
      .eq('active', true)
      .order('position'));

  // ---- Discovery, likes, matches and chat ----

  Future<List<Map<String, dynamic>>> discover() async =>
      _rows(await client.rpc('discover_members'));

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
