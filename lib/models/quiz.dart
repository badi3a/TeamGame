enum QuizStatus { pending, done, expired }

class Quiz {
  final String id;
  final String title;
  final DateTime expiryDate;
  final int duration; // in minutes
  final QuizStatus status;

  Quiz({
    required this.id,
    required this.title,
    required this.expiryDate,
    required this.duration,
    required this.status,
  });
}
