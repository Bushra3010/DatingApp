import 'package:flutter/material.dart';

class Person {
  const Person(
      {required this.id,
      required this.name,
      required this.age,
      required this.job,
      required this.photo,
      required this.distance,
      required this.answer,
      this.verified = true});
  final String id, name, job, photo, answer;
  final int age, distance;
  final bool verified;
  String get image =>
      'https://images.unsplash.com/$photo?auto=format&fit=crop&w=1000&q=85';
}

const demoPeople = [
  Person(
      id: 'ananya',
      name: 'Ananya',
      age: 27,
      job: 'Product designer',
      photo: 'photo-1534528741775-53994a69daeb',
      distance: 4,
      answer:
          'A slow morning, a strong filter coffee, and getting wonderfully lost in a bookstore.'),
  Person(
      id: 'meera',
      name: 'Meera',
      age: 28,
      job: 'Architect',
      photo: 'photo-1524504388940-b1c1722653e1',
      distance: 7,
      answer:
          'Finding a little café with a big personality. Bonus points if there’s a dog.'),
  Person(
      id: 'isha',
      name: 'Isha',
      age: 25,
      job: 'Creative strategist',
      photo: 'photo-1524250502761-1ac6f2e30d43',
      distance: 3,
      answer:
          'A spontaneous drive, a very specific playlist, and absolutely no rush to get home.'),
  Person(
      id: 'tara',
      name: 'Tara',
      age: 29,
      job: 'Doctor',
      photo: 'photo-1517841905240-472988babdf9',
      distance: 12,
      answer:
          'Cooking something new together. I’ll handle dessert if you handle the playlist.'),
];

class ChatMessage {
  ChatMessage(this.text, {this.mine = false});
  final String text;
  final bool mine;
}

class SentLike {
  const SentLike(this.personId, this.target, this.comment);
  final String personId, target, comment;
}

class Conversation {
  Conversation(this.person, this.messages);
  final Person person;
  final List<ChatMessage> messages;
}

/// Local preview state. No likes, messages or account changes reach the API yet.
class PreviewStore extends ChangeNotifier {
  final Set<String> passed = {};
  final Set<String> liked = {};
  final List<SentLike> sentLikes = [];
  final List<Person> incoming = [demoPeople[1], demoPeople[2]];
  final List<Conversation> conversations = [
    Conversation(demoPeople[3], [
      ChatMessage('You liked their answer to “My ideal Sunday”', mine: true),
      ChatMessage('Okay, important question: what’s your go-to dessert?')
    ]),
  ];
  RangeValues ages = const RangeValues(24, 32);
  double distance = 25;
  bool verifiedOnly = false;
  bool paused = false;
  bool notifications = true;
  String myName = 'Rohit';
  String myJob = 'Software engineer';
  String myPrompt =
      'Good food, better company, and finding a new favourite place.';
  int get remaining => 8 - liked.length;
  List<Person> get discover => paused
      ? []
      : demoPeople
          .where((p) =>
              !passed.contains(p.id) &&
              !liked.contains(p.id) &&
              !conversations.any((chat) => chat.person.id == p.id) &&
              p.age >= ages.start &&
              p.age <= ages.end &&
              p.distance <= distance &&
              (!verifiedOnly || p.verified))
          .toList();
  void skip(Person p) {
    passed.add(p.id);
    notifyListeners();
  }

  void undo(Person p) {
    passed.remove(p.id);
    notifyListeners();
  }

  void like(Person p, {String target = 'photo', String comment = ''}) {
    if (remaining <= 0 || liked.contains(p.id)) return;
    liked.add(p.id);
    sentLikes.add(SentLike(p.id, target, comment.trim()));
    notifyListeners();
  }

  void removeLike(Person p) {
    incoming.remove(p);
    notifyListeners();
  }

  Conversation match(Person p) {
    incoming.remove(p);
    final chat = Conversation(p, [
      ChatMessage(
          'I love your idea of a perfect Sunday. What’s your favourite spot?')
    ]);
    conversations.insert(0, chat);
    notifyListeners();
    return chat;
  }

  void send(Conversation chat, String text) {
    if (text.trim().isEmpty) return;
    chat.messages.add(ChatMessage(text.trim(), mine: true));
    notifyListeners();
  }

  void update() => notifyListeners();
}
