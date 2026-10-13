// Wire models for recognition and pulse surveys.

class RecognitionBadge {
  final int id;
  final String name;
  final String emoji;

  const RecognitionBadge({required this.id, required this.name, required this.emoji});

  factory RecognitionBadge.fromJson(Map<String, dynamic> j) => RecognitionBadge(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        emoji: j['emoji']?.toString() ?? '',
      );
}

class RecognitionRecord {
  final int id;
  final String senderName;
  final String recipientName;
  final String badgeName;
  final String badgeEmoji;
  final String? message;
  final DateTime? recognizedOn;

  const RecognitionRecord({
    required this.id,
    required this.senderName,
    required this.recipientName,
    required this.badgeName,
    required this.badgeEmoji,
    this.message,
    this.recognizedOn,
  });

  factory RecognitionRecord.fromJson(Map<String, dynamic> j) => RecognitionRecord(
        id: (j['id'] as num?)?.toInt() ?? 0,
        senderName: j['senderName']?.toString() ?? '',
        recipientName: j['recipientName']?.toString() ?? '',
        badgeName: j['badgeName']?.toString() ?? '',
        badgeEmoji: j['badgeEmoji']?.toString() ?? '',
        message: j['message'] as String?,
        recognizedOn: DateTime.tryParse(j['recognizedOn']?.toString() ?? '')?.toLocal(),
      );
}

class LeaderEntry {
  final int rank;
  final String name;
  final String? designation;
  final int count;

  const LeaderEntry({required this.rank, required this.name, this.designation, required this.count});

  factory LeaderEntry.fromJson(Map<String, dynamic> j) => LeaderEntry(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        name: j['employeeName']?.toString() ?? '',
        designation: j['designation'] as String?,
        count: (j['recognitionCount'] as num?)?.toInt() ?? 0,
      );
}

/// Slim employee picker row from /employee/options.
class EmployeeOption {
  final int id;
  final String label;
  final String? subLabel;

  const EmployeeOption({required this.id, required this.label, this.subLabel});

  factory EmployeeOption.fromJson(Map<String, dynamic> j) => EmployeeOption(
        id: (j['id'] as num?)?.toInt() ?? 0,
        label: j['label']?.toString() ?? '',
        subLabel: j['subLabel'] as String?,
      );
}

/// Survey question types (QuestionType on the server).
class QuestionType {
  QuestionType._();
  static const int rating5 = 1;
  static const int rating10 = 2;
  static const int mcq = 3;
  static const int text = 4;
}

class SurveyOption {
  final int id;
  final String text;
  const SurveyOption(this.id, this.text);

  factory SurveyOption.fromJson(Map<String, dynamic> j) =>
      SurveyOption((j['id'] as num?)?.toInt() ?? 0, j['optionText']?.toString() ?? '');
}

class SurveyQuestion {
  final int id;
  final String text;
  final int typeId;
  final bool isRequired;
  final List<SurveyOption> options;

  const SurveyQuestion({
    required this.id,
    required this.text,
    required this.typeId,
    required this.isRequired,
    required this.options,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> j) => SurveyQuestion(
        id: (j['id'] as num?)?.toInt() ?? 0,
        text: j['questionText']?.toString() ?? '',
        typeId: (j['questionTypeId'] as num?)?.toInt() ?? QuestionType.text,
        isRequired: j['isRequired'] as bool? ?? false,
        options: (j['options'] as List<dynamic>? ?? [])
            .map((e) => SurveyOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Survey {
  final int id;
  final String title;
  final String? description;
  final bool isAnonymous;
  final String? endsOn;
  final bool isCompleted;
  final List<SurveyQuestion> questions;

  const Survey({
    required this.id,
    required this.title,
    this.description,
    required this.isAnonymous,
    this.endsOn,
    required this.isCompleted,
    required this.questions,
  });

  factory Survey.fromJson(Map<String, dynamic> j) => Survey(
        id: (j['surveyId'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        description: j['description'] as String?,
        isAnonymous: j['isAnonymous'] as bool? ?? false,
        endsOn: j['endsOn']?.toString(),
        isCompleted: j['isCompleted'] as bool? ?? false,
        questions: (j['questions'] as List<dynamic>? ?? [])
            .map((e) => SurveyQuestion.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id)),
      );
}
