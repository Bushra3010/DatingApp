import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/models.dart';
import 'package:everlane/voice.dart';

void main() {
  test('Discovery respects filters, skip, undo, and pause', () {
    final store = PreviewStore();
    addTearDown(store.dispose);
    store.ages = const RangeValues(27, 29);
    store.distance = 8;
    expect(store.discover.map((p) => p.id), ['ananya', 'meera']);
    store.skip(demoPeople.first);
    expect(store.discover.map((p) => p.id), ['meera']);
    expect(store.undoLastPass(), isNull, reason: 'Rewind needs Plus');
    store.choosePlan(Plan.plus);
    expect(store.undoLastPass()?.id, 'ananya');
    expect(store.discover.length, 2);
    expect(store.undoLastPass(), isNull);
    store.paused = true;
    expect(store.discover, isEmpty);
    expect(store.conversations, isNotEmpty);
  });

  test('A like retains its specific target and comment and cannot count twice',
      () {
    final store = PreviewStore();
    addTearDown(store.dispose);
    store.like(demoPeople.first,
        target: 'My ideal Sunday', comment: '  Which bookstore?  ');
    store.like(demoPeople.first);
    expect(store.remaining, 7);
    expect(store.sentLikes.single.target, 'My ideal Sunday');
    expect(store.sentLikes.single.comment, 'Which bookstore?');
    expect(store.discover.any((p) => p.id == demoPeople.first.id), isFalse);
    for (var i = 0; i < 10; i++) {
      store.like(Person(
          id: '$i',
          name: 'Test',
          age: 27,
          job: '',
          photo: '',
          distance: 1,
          answer: '',
          lookingFor: const [LookingFor.longTerm]));
    }
    expect(store.remaining, 0);
    expect(store.sentLikes.length, 8);
  });

  test(
      'Accepting a like opens a conversation and sending ignores blank messages',
      () {
    final store = PreviewStore();
    addTearDown(store.dispose);
    final person = store.incoming.first;
    final chat = store.match(person);
    expect(store.incoming.contains(person), isFalse);
    expect(store.conversations.first, same(chat));
    expect(store.discover.any((p) => p.id == person.id), isFalse);
    store.send(chat, '  Hello there!  ');
    store.send(chat, '   ');
    expect(chat.messages.length, 2);
    expect(chat.messages.last.text, 'Hello there!');
    expect(chat.messages.last.mine, isTrue);
  });

  test('Plans follow the four launch tiers', () {
    final store = PreviewStore();
    addTearDown(store.dispose);
    expect(
        Plan.values.map((p) => p.title), ['Free', 'Plus', 'Gold', 'Platinum']);
    expect(store.remaining, 8);
    expect(store.canRewind, isFalse);
    expect(store.canSeeLikes, isFalse);
    expect(store.plan.monthlyBoosts, 0);
    store.choosePlan(Plan.plus);
    expect(store.remaining, 25);
    expect(store.canRewind, isTrue);
    expect(store.canSeeLikes, isFalse, reason: 'Likes You is a Gold feature');
    expect(store.fullerChemistry, isTrue);
    expect(store.detailedChemistry, isFalse);
    store.choosePlan(Plan.gold);
    expect(store.canSeeLikes, isTrue);
    expect(store.canHangout, isTrue, reason: 'Hangouts are open to everyone');
    store.startBoost();
    expect(store.boosting, isTrue);
    expect(store.boostsLeft, 1);
    store.startBoost();
    expect(store.boostsLeft, 1, reason: 'one boost at a time');
    store.choosePlan(Plan.platinum);
    expect(store.canHangout, isTrue);
    expect(store.detailedChemistry, isTrue);
  });

  test('Intention filter needs Plus and clears on downgrade', () {
    final store = PreviewStore();
    addTearDown(store.dispose);
    store.choosePlan(Plan.plus);
    store.intentFilter.add(LookingFor.shortTerm);
    expect(store.discover.map((p) => p.id), ['isha']);
    store.choosePlan(Plan.free);
    expect(store.intentFilter, isEmpty);
  });

  test('A city search ignores distance; Nearby lists only people close by',
      () {
    final store = PreviewStore();
    addTearDown(store.dispose);
    store.ages = const RangeValues(18, 60);
    store.distance = 1;
    expect(store.discover, isEmpty);
    store.cityFilter = 'bengaluru';
    expect(store.discover, isNotEmpty,
        reason: 'case-insensitive, and distance no longer applies');
    store.cityFilter = 'Mumbai';
    expect(store.discover, isEmpty);
    expect(store.cityOptions, contains('Mumbai'));
    expect(store.nearby.every((p) => p.distance <= 5), isTrue);
    expect(store.nearby.map((p) => p.distance).toList(),
        [...store.nearby.map((p) => p.distance)]..sort());
  });

  test('A voice prompt is saved and removed locally without an account',
      () async {
    final store = PreviewStore();
    addTearDown(store.dispose);
    expect(store.hasVoice, isFalse);
    final wav = wavFromPcm16(Uint8List(32000));
    await store.setVoice('My simple pleasures', wav, 1);
    expect(store.hasVoice, isTrue);
    expect(store.myVoiceLabel, 'My simple pleasures');
    store.removeVoice();
    expect(store.hasVoice, isFalse);
  });

  test('Recordings are wrapped in a valid mono 16 kHz WAV header', () {
    final wav = wavFromPcm16(Uint8List(100));
    final data = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(data.getUint32(4, Endian.little), 136);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), 16000);
    expect(data.getUint32(40, Endian.little), 100);
    expect(wav.length, 144);
  });

  test('Messages carry their time, including ones from Supabase', () {
    final m = ChatMessage.fromRow(
        {'body': 'hi', 'created_at': '2026-10-26T05:46:00Z'},
        mine: true);
    expect(m.sentAt, DateTime.utc(2026, 10, 26, 5, 46).toLocal());
    expect(m.mine, isTrue);
  });

  test('Areas are rounded to about 1 km before anything is kept', () {
    final (lat, lng) = snapToArea(12.97843, 77.64071);
    expect(lat, closeTo(12.975, 1e-9));
    expect(lng, closeTo(77.645, 1e-9));
    final (lat2, lng2) = snapToArea(12.97101, 77.64999);
    expect((lat2, lng2), (lat, lng), reason: 'same ~1 km square');
  });

  test('Crossed paths is opt-in, and turning it off forgets your area',
      () async {
    final store = PreviewStore();
    addTearDown(store.dispose);
    expect(store.shareArea, isFalse);
    expect(store.crossings, isNotEmpty, reason: 'demo crossings');
    await store.recordArea(12.97843, 77.64071);
    expect(store.shareArea, isTrue);
    expect(store.myArea!.$1, closeTo(12.975, 1e-9));
    store.stopSharingArea();
    expect(store.shareArea, isFalse);
    expect(store.myArea, isNull);
  });

  test('A warning from the team can be dismissed', () {
    final store = PreviewStore();
    addTearDown(store.dispose);
    store.adminWarning = 'Please keep it respectful';
    store.acknowledgeWarning();
    expect(store.adminWarning, isEmpty);
  });
}
