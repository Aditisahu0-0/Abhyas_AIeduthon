
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
    // Handle options field (can be List or pipe-separated string)
<<<<<<< HEAD
    List<String> optionsList = map['options'] is List 
=======
    final List<String> optionsList = map['options'] is List 
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
        ? List<String>.from(map['options'])
        : (map['options'] as String?)?.split('|') ?? [];
    
    // Handle correctOptionIndex - support both old and new format
    int correctIndex = 0;
    
    if (map['correctOptionIndex'] != null) {
      // New format: integer index
      correctIndex = map['correctOptionIndex'] as int;
<<<<<<< HEAD
      
      // Validate range
      if (correctIndex < 0 || correctIndex >= optionsList.length) {
        print('⚠️ Warning: correctIndex $correctIndex out of range, setting to 0');
        correctIndex = 0;
      }
    } 
    
    // Check for explicit string match (Highest Priority)
    if (map['correctAnswer'] != null) {
      final correctAnswer = map['correctAnswer'] as String;
      // Try exact match
      int foundIndex = optionsList.indexOf(correctAnswer);
      
      // Try partial match if exact match fails
      if (foundIndex == -1) {
         for (int i = 0; i < optionsList.length; i++) {
           if (optionsList[i].trim().toLowerCase() == correctAnswer.trim().toLowerCase()) {
             foundIndex = i;
             break;
           }
         }
      }
      
      if (foundIndex != -1) {
        correctIndex = foundIndex;
      }
    }
    
    // VALIDATION: Check for malformed options and fix them
    for (int i = 0; i < optionsList.length; i++) {
      final option = optionsList[i].trim();
      // Detect malformed options: very short, just numbers/letters, or clearly incomplete
      // Detect malformed options: empty or just "Option A" placeholder logic
      // WE RELAXED THIS: Short options like "Mg", "5", "pH" are valid.
      // Only filter out truly broken stuff.
      if (option.trim().isEmpty || 
          option.toLowerCase() == 'option a' || 
          option.toLowerCase() == 'option b' ||
          option.toLowerCase() == 'option c' ||
          option.toLowerCase() == 'option d') {
        print('⚠️ Malformed option detected at index $i: "$option" - replacing with fallback');
        // Replace with a meaningful fallback based on position
        final fallbacks = [
          'Option A',
          'Option B',  
          'Option C',
          'None of the above'
        ];
        optionsList[i] = fallbacks[i % fallbacks.length];
      }
    }
    
    // CRITICAL: Ensure EXACTLY 4 options
    if (optionsList.length < 4) {
      print('⚠️ Quiz has only ${optionsList.length} options, padding to 4');
      
      if (optionsList.length == 3) {
        // Add "None of the above" as 4th option
        optionsList.add('None of the above');
      } else if (optionsList.length == 2) {
        // Add "Both of the above" and "None of the above"
        optionsList.add('Both of the above');
        optionsList.add('None of the above');
      } else if (optionsList.length == 1) {
        // Add 3 filler options
        optionsList.add('None of the above');
        optionsList.add('All of the above');
        optionsList.add('Cannot be determined');
      } else if (optionsList.isEmpty) {
        // Emergency fallback - create 4 generic options
        print('❌ ERROR: Quiz has NO options, creating fallback');
        optionsList = ['Option A', 'Option B', 'Option C', 'Option D'];
        correctIndex = 0;
      }
      
      // After padding, ensure correctIndex is still valid
      // If correctIndex >= original length, it means correct answer was in the original options
      // which is still valid after padding
    } else if (optionsList.length > 4) {
      // If more than 4, truncate to 4
      print('⚠️ Quiz has ${optionsList.length} options, truncating to 4');
      optionsList = optionsList.sublist(0, 4);
      // Ensure correctIndex is still valid
      if (correctIndex >= 4) {
        print('⚠️ correctIndex was $correctIndex, setting to 0');
=======
    } else if (map['correct_answer'] != null) {
      // Old format: string answer - find the matching option
      final correctAnswer = map['correct_answer'] as String;
      correctIndex = optionsList.indexOf(correctAnswer);
      if (correctIndex == -1) {
        // Fallback if answer not found in options
        print('⚠️ Warning: correct_answer "$correctAnswer" not found in options');
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
        correctIndex = 0;
      }
    }
    
<<<<<<< HEAD
    print('✅ Quiz validated: ${optionsList.length} options, correctIndex: $correctIndex');
    
=======
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
    return QuizQuestion(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      question: map['question'] ?? 'Unknown Question',
      options: optionsList,
      correctOptionIndex: correctIndex,
      explanation: map['explanation'] ?? '',
    );
  }
}
