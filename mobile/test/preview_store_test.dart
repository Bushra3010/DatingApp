import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kindred/models.dart';

void main() {
  test('Discovery respects filters, skip, undo, and pause', () {
    final store = PreviewStore();
    addTearDown(store.dispose);
    store.ages = const RangeValues(27, 29);
    store.distance = 8;
    expect(store.discover.map((p) => p.id), ['ananya', 'meera']);
    store.skip(demoPeople.first);
    expect(store.discover.map((p) => p.id), ['meera']);
    store.undo(demoPeople.first);
    expect(store.discover.length, 2);
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
          answer: ''));
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
}
