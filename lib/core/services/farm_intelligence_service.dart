import 'dart:async';
import 'dart:math';
import '../models/detection_record.dart';

/// Service for providing intelligent farm insights and analytics
class FarmIntelligenceService {
  FarmIntelligenceService._();
  
  static final FarmIntelligenceService instance = FarmIntelligenceService._();
  
  final List<DetectionRecord> _records = [];
  final StreamController<FarmInsight> _insightController = 
      StreamController<FarmInsight>.broadcast();
  
  Stream<FarmInsight> get insights => _insightController.stream;
  
  /// Add detection records and generate insights
  void addRecords(List<DetectionRecord> records) {
    _records.addAll(records);
    _generateInsights();
  }
  
  /// Generate intelligent insights based on detection patterns
  void _generateInsights() {
    if (_records.length < 5) return;
    
    // Equipment usage patterns
    final usagePatterns = _analyzeUsagePatterns();
    if (usagePatterns.isNotEmpty) {
      _insightController.add(FarmInsight(
        type: InsightType.usagePattern,
        title: 'Equipment Usage Pattern Detected',
        description: usagePatterns,
        priority: InsightPriority.medium,
        timestamp: DateTime.now(),
      ));
    }
    
    // Maintenance predictions
    final maintenanceAlerts = _predictMaintenanceNeeds();
    for (final alert in maintenanceAlerts) {
      _insightController.add(alert);
    }
    
    // Efficiency scores
    final efficiencyScores = _calculateEfficiencyScores();
    if (efficiencyScores.isNotEmpty) {
      _insightController.add(FarmInsight(
        type: InsightType.efficiency,
        title: 'Equipment Efficiency Update',
        description: efficiencyScores,
        priority: InsightPriority.low,
        timestamp: DateTime.now(),
      ));
    }
  }
  
  String _analyzeUsagePatterns() {
    final recentRecords = _records.where((r) => 
        r.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7)))
    ).toList();
    
    if (recentRecords.isEmpty) return '';
    
    final equipmentCounts = <String, int>{};
    for (final record in recentRecords) {
      equipmentCounts[record.predictedClass] = 
          (equipmentCounts[record.predictedClass] ?? 0) + 1;
    }
    
    final topEquipment = equipmentCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    return 'Most used equipment this week: ${topEquipment.key} (${topEquipment.value} detections)';
  }
  
  List<FarmInsight> _predictMaintenanceNeeds() {
    final insights = <FarmInsight>[];
    final equipmentUsage = <String, List<DetectionRecord>>{};
    
    // Group records by equipment
    for (final record in _records) {
      equipmentUsage.putIfAbsent(record.predictedClass, () => []).add(record);
    }
    
    // Analyze usage frequency for maintenance prediction
    for (final entry in equipmentUsage.entries) {
      final records = entry.value;
      if (records.length < 3) continue;
      
      final recentRecords = records.where((r) => 
          r.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 30)))
      ).toList();
      
      // High usage equipment might need maintenance
      if (recentRecords.length > 20) {
        insights.add(FarmInsight(
          type: InsightType.maintenance,
          title: 'Maintenance Alert: ${entry.key}',
          description: 'High usage detected (${recentRecords.length} times this month). Consider scheduling maintenance.',
          priority: InsightPriority.high,
          timestamp: DateTime.now(),
        ));
      }
    }
    
    return insights;
  }
  
  String _calculateEfficiencyScores() {
    final recentRecords = _records.where((r) => 
        r.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 14)))
    ).toList();
    
    if (recentRecords.isEmpty) return '';
    
    final avgConfidence = recentRecords
        .map((r) => r.confidence)
        .reduce((a, b) => a + b) / recentRecords.length;
    
    final efficiencyScore = (avgConfidence * 100).round();
    
    return 'Overall detection efficiency: $efficiencyScore%';
  }
  
  /// Get equipment statistics
  Map<String, EquipmentStats> getEquipmentStats() {
    final stats = <String, EquipmentStats>{};
    
    for (final record in _records) {
      final equipment = record.predictedClass;
      
      if (!stats.containsKey(equipment)) {
        stats[equipment] = EquipmentStats(
          name: equipment,
          totalDetections: 0,
          avgConfidence: 0.0,
          lastUsed: record.timestamp,
          usageTrend: UsageTrend.stable,
        );
      }
      
      final currentStats = stats[equipment]!;
      stats[equipment] = currentStats.copyWith(
        totalDetections: currentStats.totalDetections + 1,
        avgConfidence: (currentStats.avgConfidence * currentStats.totalDetections + record.confidence) / 
                       (currentStats.totalDetections + 1),
        lastUsed: record.timestamp.isAfter(currentStats.lastUsed) ? record.timestamp : currentStats.lastUsed,
      );
    }
    
    return stats;
  }
  
  void dispose() {
    _insightController.close();
  }
}

class FarmInsight {
  final InsightType type;
  final String title;
  final String description;
  final InsightPriority priority;
  final DateTime timestamp;
  
  const FarmInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.timestamp,
  });
}

enum InsightType {
  usagePattern,
  maintenance,
  efficiency,
  alert,
}

enum InsightPriority {
  low,
  medium,
  high,
}

class EquipmentStats {
  final String name;
  final int totalDetections;
  final double avgConfidence;
  final DateTime lastUsed;
  final UsageTrend usageTrend;
  
  const EquipmentStats({
    required this.name,
    required this.totalDetections,
    required this.avgConfidence,
    required this.lastUsed,
    required this.usageTrend,
  });
  
  EquipmentStats copyWith({
    String? name,
    int? totalDetections,
    double? avgConfidence,
    DateTime? lastUsed,
    UsageTrend? usageTrend,
  }) {
    return EquipmentStats(
      name: name ?? this.name,
      totalDetections: totalDetections ?? this.totalDetections,
      avgConfidence: avgConfidence ?? this.avgConfidence,
      lastUsed: lastUsed ?? this.lastUsed,
      usageTrend: usageTrend ?? this.usageTrend,
    );
  }
}

enum UsageTrend {
  increasing,
  decreasing,
  stable,
}
