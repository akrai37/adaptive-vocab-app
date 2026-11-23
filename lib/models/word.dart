/// One vocabulary item. [id] is stable across languages and is what the
/// answer log refers to; [text] and [audio] are keyed by language code.
class Word {
  final String id;
  final String category;

  /// Stand-in picture until real images exist.
  final String emoji;
  final String image;
  final Map<String, String> text;

  /// One short sentence about the word, for children, keyed by language.
  final Map<String, String> fact;
  final Map<String, String?> audio;

  const Word({
    required this.id,
    required this.category,
    required this.emoji,
    required this.image,
    required this.text,
    this.fact = const {},
    required this.audio,
  });

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    id: json['id'] as String,
    category: json['category'] as String,
    emoji: json['emoji'] as String,
    image: json['image'] as String,
    text: Map<String, String>.from(json['text'] as Map),
    fact: Map<String, String>.from(json['fact'] as Map? ?? const {}),
    audio: Map<String, String?>.from(json['audio'] as Map),
  );

  /// The word in [lang], falling back to English if it has no entry yet.
  String label(String lang) => text[lang] ?? text['en']!;

  /// The fact in [lang], falling back to English, or null if there is none.
  String? factIn(String lang) => fact[lang] ?? fact['en'];
}
