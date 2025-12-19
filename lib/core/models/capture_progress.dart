import 'dart:convert';

/// A record tracking capture progress for equipment classes
class CaptureProgress {
  CaptureProgress({
    required this.id,
    required this.equipmentClass,
    required this.equipmentIndex,
    required this.totalCaptures,
    required this.targetCaptures,
    required this.percentageComplete,
    required this.lastUpdated,
  });

  /// Unique identifier for this progress record
  final String id;

  /// The equipment class being tracked
  final String equipmentClass;

  /// The index of the equipment class
  final int equipmentIndex;

  /// Current number of captures completed
  final int totalCaptures;

  /// Target number of captures for this equipment class
  final int targetCaptures;

  /// Percentage of completion (0.0 - 100.0)
  final double percentageComplete;

  /// When this progress record was last updated
  final DateTime lastUpdated;

  /// Create a copy with updated fields
  CaptureProgress copyWith({
    int? totalCaptures,
    int? targetCaptures,
    double? percentageComplete,
    DateTime? lastUpdated,
  }) {
    return CaptureProgress(
      id: id,
      equipmentClass: equipmentClass,
      equipmentIndex: equipmentIndex,
      totalCaptures: totalCaptures ?? this.totalCaptures,
      targetCaptures: targetCaptures ?? this.targetCaptures,
      percentageComplete: percentageComplete ?? this.percentageComplete,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Create from JSON map
  factory CaptureProgress.fromJson(Map<String, dynamic> json) {
    return CaptureProgress(
      id: json['id'] as String,
      equipmentClass: json['equipmentClass'] as String,
      equipmentIndex: json['equipmentIndex'] as int,
      totalCaptures: json['totalCaptures'] as int,
      targetCaptures: json['targetCaptures'] as int,
      percentageComplete: (json['percentageComplete'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipmentClass': equipmentClass,
      'equipmentIndex': equipmentIndex,
      'totalCaptures': totalCaptures,
      'targetCaptures': targetCaptures,
      'percentageComplete': percentageComplete,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Encode to JSON string
  String encode() => jsonEncode(toJson());

  /// Decode from JSON string
  static CaptureProgress decode(String source) =>
      CaptureProgress.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// Holds overall capture progress statistics
class OverallCaptureStats {
  final int totalEquipmentClasses;
  final int completedClasses;
  final double overallPercentage;
  final int totalCaptures;
  final int totalTargetCaptures;
  final DateTime lastUpdated;

  OverallCaptureStats({
    required this.totalEquipmentClasses,
    required this.completedClasses,
    required this.overallPercentage,
    required this.totalCaptures,
    required this.totalTargetCaptures,
    required this.lastUpdated,
  });

  /// Create from JSON map
  factory OverallCaptureStats.fromJson(Map<String, dynamic> json) {
    return OverallCaptureStats(
      totalEquipmentClasses: json['totalEquipmentClasses'] as int,
      completedClasses: json['completedClasses'] as int,
      overallPercentage: (json['overallPercentage'] as num).toDouble(),
      totalCaptures: json['totalCaptures'] as int,
      totalTargetCaptures: json['totalTargetCaptures'] as int,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'totalEquipmentClasses': totalEquipmentClasses,
      'completedClasses': completedClasses,
      'overallPercentage': overallPercentage,
      'totalCaptures': totalCaptures,
      'totalTargetCaptures': totalTargetCaptures,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
