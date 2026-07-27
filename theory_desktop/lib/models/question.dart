class Question {
  final int id;
  final String text;
  final List<String> options;
  final int correct;
  final String category;
  final List<String> licenses;
  final String? img;

  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correct,
    required this.category,
    required this.licenses,
    this.img,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as int,
        text: j['text'] as String,
        options: (j['options'] as List).cast<String>(),
        correct: j['correct'] as int,
        category: j['category'] as String,
        licenses: (j['licenses'] as List).cast<String>(),
        img: j['img'] as String?,
      );
}
