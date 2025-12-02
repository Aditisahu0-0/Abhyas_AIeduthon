
class Course {
  final String id;
  final String title;
  final String description;
  final String iconPath;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconPath': iconPath,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      iconPath: map['iconPath'],
    );
  }
}

class Lesson {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int orderIndex;

  Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'orderIndex': orderIndex,
    };
  }

  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'],
      courseId: map['courseId'],
      title: map['title'],
      description: map['description'],
      orderIndex: map['orderIndex'],
    );
  }
}

class Topic {
  final String id;
  final String lessonId;
  final String title;
  final String content;
  final int orderIndex;

  Topic({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.content,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lessonId': lessonId,
      'title': title,
      'content': content,
      'orderIndex': orderIndex,
    };
  }

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'],
      lessonId: map['lessonId'],
      title: map['title'],
      content: map['content'],
      orderIndex: map['orderIndex'],
    );
  }
}

class Quiz {
  final String id;
  final String lessonId;
  final String title;
  final List<QuizQuestion> questions;

  Quiz({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.questions,
  });
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options.join('|'), // Simple serialization
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
    };
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      question: map['question'] ?? 'Unknown Question',
      options: map['options'] is List 
          ? List<String>.from(map['options'])
          : (map['options'] as String?)?.split('|') ?? [],
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
      explanation: map['explanation'] ?? '',
    );
  }
}
