import 'dart:convert';

/// A record of a single jersey detection.
class DetectionRecord {
  DetectionRecord({
    required this.id,
    required this.timestamp,
    required this.groundTruthClass,
    required this.groundTruthIndex,
    required this.predictedClass,
    required this.predictedIndex,
    required this.confidence,
    required this.scores,
    this.isVerified = false,
  });

  /// Unique identifier for this record.
  final String id;

  /// When the detection occurred.
  final DateTime timestamp;

  /// The class the user selected as ground truth (what they were trying to detect).
  final String groundTruthClass;
  final int groundTruthIndex;

  /// The class predicted by the model.
  final String predictedClass;
  final int predictedIndex;

  /// Confidence of the top prediction (0.0 - 1.0).
  final double confidence;

  /// All class scores from the model.
  final List<double> scores;

  /// Whether the user has verified/confirmed this detection.
  final bool isVerified;

  /// Whether the prediction was correct.
  bool get isCorrect => groundTruthIndex == predictedIndex;

  /// Create a copy with updated fields.
  DetectionRecord copyWith({bool? isVerified}) {
    return DetectionRecord(
      id: id,
      timestamp: timestamp,
      groundTruthClass: groundTruthClass,
      groundTruthIndex: groundTruthIndex,
      predictedClass: predictedClass,
      predictedIndex: predictedIndex,
      confidence: confidence,
      scores: scores,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  /// Create from JSON map.
  factory DetectionRecord.fromJson(Map<String, dynamic> json) {
    return DetectionRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      groundTruthClass: json['groundTruthClass'] as String,
      groundTruthIndex: json['groundTruthIndex'] as int,
      predictedClass: json['predictedClass'] as String,
      predictedIndex: json['predictedIndex'] as int,
      confidence: (json['confidence'] as num).toDouble(),
      scores: (json['scores'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'groundTruthClass': groundTruthClass,
      'groundTruthIndex': groundTruthIndex,
      'predictedClass': predictedClass,
      'predictedIndex': predictedIndex,
      'confidence': confidence,
      'scores': scores,
      'isVerified': isVerified,
    };
  }

  /// Encode to JSON string.
  String encode() => jsonEncode(toJson());

  /// Decode from JSON string.
  static DetectionRecord decode(String source) =>
      DetectionRecord.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
