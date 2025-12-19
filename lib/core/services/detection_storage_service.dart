import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/detection_record.dart';
import '../models/record_filter.dart';

/// Service for persisting and retrieving detection records locally.
class DetectionStorageService {
  DetectionStorageService._();

  static final DetectionStorageService instance = DetectionStorageService._();

  static const String _storageKey = 'detection_records';

  List<DetectionRecord> _cachedRecords = [];
  bool _isLoaded = false;
  
  // Stream controller for notifying when data changes
  final _dataChangeController = StreamController<void>.broadcast();
  Stream<void> get dataChanges => _dataChangeController.stream;

  /// Get all stored detection records.
  List<DetectionRecord> get records => List.unmodifiable(_cachedRecords);

  /// Load records from storage. Call this once at app startup.
  Future<void> loadRecords() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];

    _cachedRecords = jsonList
        .map((json) => DetectionRecord.decode(json))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first

    _isLoaded = true;
  }

  /// Save a new detection record.
  Future<void> saveRecord(DetectionRecord record) async {
    await loadRecords(); // Ensure loaded

    _cachedRecords.insert(0, record); // Add to front (newest first)

    await _persistRecords();
    
    // Notify listeners that data has changed
    _dataChangeController.add(null);
  }

  /// Delete a record by ID.
  Future<void> deleteRecord(String id) async {
    await loadRecords();

    _cachedRecords.removeWhere((r) => r.id == id);

    await _persistRecords();
    
    // Notify listeners that data has changed
    _dataChangeController.add(null);
  }

  /// Clear all records.
  Future<void> clearAllRecords() async {
    _cachedRecords.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    
    // Notify listeners that data has changed
    _dataChangeController.add(null);
  }

  /// Mark a record as verified by ID.
  Future<bool> verifyRecord(String id) async {
    await loadRecords();

    final index = _cachedRecords.indexWhere((r) => r.id == id);
    if (index == -1) return false;

    _cachedRecords[index] = _cachedRecords[index].copyWith(isVerified: true);

    await _persistRecords();
    
    // Notify listeners that data has changed
    _dataChangeController.add(null);
    
    return true;
  }

  /// Get a record by ID.
  DetectionRecord? getRecordById(String id) {
    try {
      return _cachedRecords.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Dispose the stream controller.
  void dispose() {
    _dataChangeController.close();
  }

  /// Persist current records to storage.
  Future<void> _persistRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _cachedRecords.map((r) => r.encode()).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Analytics helpers (with filter support)
  // ─────────────────────────────────────────────────────────────────────────

  /// Get filtered records based on the filter option.
  List<DetectionRecord> getFilteredRecords(RecordFilter filter) {
    return _cachedRecords.where((r) {
      if (r.groundTruthIndex < 0) return false;
      switch (filter) {
        case RecordFilter.all:
          return true;
        case RecordFilter.verified:
          return r.isVerified;
        case RecordFilter.notVerified:
          return !r.isVerified;
      }
    }).toList();
  }

  /// Get all records without any filtering.
  List<DetectionRecord> getAllRecords() {
    return _cachedRecords;
  }

  /// Total number of detections based on filter.
  int getTotalDetections(RecordFilter filter) =>
      getFilteredRecords(filter).length;

  /// Number of correct predictions based on filter.
  int getCorrectPredictions(RecordFilter filter) =>
      getFilteredRecords(filter).where((r) => r.isCorrect).length;

  /// Overall accuracy (0.0 - 1.0) based on filter.
  double getAccuracy(RecordFilter filter) {
    final total = getTotalDetections(filter);
    return total == 0 ? 0.0 : getCorrectPredictions(filter) / total;
  }

  /// Get accuracy for a specific class index based on filter.
  double getAccuracyForClass(int classIndex, RecordFilter filter) {
    final classRecords = getFilteredRecords(filter)
        .where((r) => r.groundTruthIndex == classIndex)
        .toList();
    if (classRecords.isEmpty) return 0.0;

    final correct = classRecords.where((r) => r.isCorrect).length;
    return correct / classRecords.length;
  }

  /// Build a confusion matrix based on filter.
  /// Returns a 2D list where [actual][predicted] = count.
  List<List<int>> buildConfusionMatrix(int numClasses, RecordFilter filter) {
    final matrix = List.generate(
      numClasses,
      (_) => List.filled(numClasses, 0),
    );

    for (final record in getFilteredRecords(filter)) {
      final gi = record.groundTruthIndex;
      final pi = record.predictedIndex;
      if (gi >= 0 && gi < numClasses && pi >= 0 && pi < numClasses) {
        matrix[gi][pi]++;
      }
    }

    return matrix;
  }

  /// Get detection counts per class based on filter.
  Map<int, int> getDetectionsPerClass(RecordFilter filter) {
    final counts = <int, int>{};
    for (final record in getFilteredRecords(filter)) {
      counts[record.groundTruthIndex] =
          (counts[record.groundTruthIndex] ?? 0) + 1;
    }
    return counts;
  }

  /// Get records from the last N days.
  List<DetectionRecord> recordsFromLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _cachedRecords.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  /// Get daily statistics for the last N days (for line+bar chart).
  /// Returns a list of DailyStats sorted by date (oldest first).
  List<DailyStats> getDailyStats(int days, RecordFilter filter) {
    final now = DateTime.now();
    final Map<String, List<DetectionRecord>> byDay = {};

    // Initialize all days in range with empty lists
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      byDay[key] = [];
    }

    // Group filtered records by day
    for (final record in getFilteredRecords(filter)) {
      final key = _dateKey(record.timestamp);
      if (byDay.containsKey(key)) {
        byDay[key]!.add(record);
      }
    }

    // Convert to DailyStats list
    final stats = <DailyStats>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final records = byDay[key]!;
      final count = records.length;
      final correct = records.where((r) => r.isCorrect).length;
      final accuracy = count == 0 ? 0.0 : correct / count;
      final avgConfidence = count == 0
          ? 0.0
          : records.map((r) => r.confidence).reduce((a, b) => a + b) / count;

      stats.add(DailyStats(
        date: DateTime(date.year, date.month, date.day),
        detectionCount: count,
        accuracy: accuracy,
        avgConfidence: avgConfidence,
      ));
    }

    return stats;
  }

  /// Generate a date key string for grouping (YYYY-MM-DD).
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ─────────────────────────────────────────────────────────────────────────
  // Additional analytics for improvements
  // ─────────────────────────────────────────────────────────────────────────

  /// Get verification rate (0.0 - 1.0) based on filter.
  double getVerificationRate(RecordFilter filter) {
    final filtered = getFilteredRecords(filter);
    if (filtered.isEmpty) return 0.0;
    final verified = filtered.where((r) => r.isVerified).length;
    return verified / filtered.length;
  }

  /// Get number of incorrect predictions based on filter.
  int getIncorrectPredictions(RecordFilter filter) =>
      getFilteredRecords(filter).where((r) => !r.isCorrect).length;

  /// Get error rate (0.0 - 1.0) based on filter.
  double getErrorRate(RecordFilter filter) {
    final total = getTotalDetections(filter);
    return total == 0 ? 0.0 : getIncorrectPredictions(filter) / total;
  }

  /// Get daily error statistics for line+bar chart (errors-only view).
  List<DailyStats> getDailyErrorStats(int days, RecordFilter filter) {
    final now = DateTime.now();
    final Map<String, List<DetectionRecord>> byDay = {};

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      byDay[key] = [];
    }

    for (final record in getFilteredRecords(filter)) {
      final key = _dateKey(record.timestamp);
      if (byDay.containsKey(key)) {
        byDay[key]!.add(record);
      }
    }

    final stats = <DailyStats>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final records = byDay[key]!;
      final count = records.length;
      final errors = records.where((r) => !r.isCorrect).length;
      final errorRate = count == 0 ? 0.0 : errors / count;

      stats.add(DailyStats(
        date: DateTime(date.year, date.month, date.day),
        detectionCount: errors, // Show error count in bars
        accuracy: 1.0 - errorRate, // Inverse for consistency
        avgConfidence: errorRate, // Repurpose for error rate display
      ));
    }

    return stats;
  }

  /// Get per-class accuracy stats sorted by accuracy ascending (hardest first).
  List<ClassAccuracyStats> getHardestClasses(RecordFilter filter, int numClasses) {
    final stats = <ClassAccuracyStats>[];

    for (int i = 0; i < numClasses; i++) {
      final classRecords = getFilteredRecords(filter)
          .where((r) => r.groundTruthIndex == i)
          .toList();
      final count = classRecords.length;
      final correct = classRecords.where((r) => r.isCorrect).length;
      final accuracy = count == 0 ? -1.0 : correct / count; // -1 means no data

      stats.add(ClassAccuracyStats(
        classIndex: i,
        sampleCount: count,
        accuracy: accuracy,
        errorCount: count - correct,
      ));
    }

    // Sort by accuracy ascending (hardest first), but put no-data at the end
    stats.sort((a, b) {
      if (a.accuracy < 0 && b.accuracy < 0) return 0;
      if (a.accuracy < 0) return 1;
      if (b.accuracy < 0) return -1;
      return a.accuracy.compareTo(b.accuracy);
    });

    return stats;
  }

  /// Get records with advanced filtering for history page.
  List<DetectionRecord> getAdvancedFilteredRecords({
    RecordFilter verificationFilter = RecordFilter.all,
    int? classIndex,
    bool? isCorrect,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _cachedRecords.where((r) {
      if (r.groundTruthIndex < 0) return false;

      // Verification filter
      switch (verificationFilter) {
        case RecordFilter.verified:
          if (!r.isVerified) return false;
        case RecordFilter.notVerified:
          if (r.isVerified) return false;
        case RecordFilter.all:
          break;
      }

      // Class filter
      if (classIndex != null && r.groundTruthIndex != classIndex) {
        return false;
      }

      // Correct/incorrect filter
      if (isCorrect != null && r.isCorrect != isCorrect) {
        return false;
      }

      // Search query filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchesPredicted = r.predictedClass.toLowerCase().contains(query);
        final matchesGroundTruth = r.groundTruthClass.toLowerCase().contains(query);
        if (!matchesPredicted && !matchesGroundTruth) return false;
      }

      // Date range filter
      if (startDate != null) {
        final recordDate = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        if (recordDate.isBefore(start)) return false;
      }
      if (endDate != null) {
        final recordDate = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        final end = DateTime(endDate.year, endDate.month, endDate.day);
        if (recordDate.isAfter(end)) return false;
      }

      return true;
    }).toList();
  }

  /// Delete multiple records by IDs.
  Future<void> deleteRecords(List<String> ids) async {
    await loadRecords();
    _cachedRecords.removeWhere((r) => ids.contains(r.id));
    await _persistRecords();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Export functionality
  // ─────────────────────────────────────────────────────────────────────────

  /// Export all records as JSON string.
  String exportToJson({RecordFilter filter = RecordFilter.all}) {
    final records = getFilteredRecords(filter);
    final data = records.map((r) => r.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'totalRecords': records.length,
      'records': data,
    });
  }

  /// Export all records as CSV string.
  String exportToCsv({RecordFilter filter = RecordFilter.all}) {
    final records = getFilteredRecords(filter);
    final buffer = StringBuffer();

    // Header
    buffer.writeln('ID,Timestamp,Ground Truth,Ground Truth Index,Predicted,Predicted Index,Confidence,Is Correct,Is Verified');

    // Data rows
    for (final r in records) {
      buffer.writeln(
        '${r.id},'
        '${r.timestamp.toIso8601String()},'
        '"${r.groundTruthClass}",'
        '${r.groundTruthIndex},'
        '"${r.predictedClass}",'
        '${r.predictedIndex},'
        '${r.confidence.toStringAsFixed(4)},'
        '${r.isCorrect},'
        '${r.isVerified}'
      );
    }

    return buffer.toString();
  }
}

/// Holds daily aggregated statistics.
class DailyStats {
  final DateTime date;
  final int detectionCount;
  final double accuracy;
  final double avgConfidence;

  DailyStats({
    required this.date,
    required this.detectionCount,
    required this.accuracy,
    required this.avgConfidence,
  });
}

/// Holds per-class accuracy statistics.
class ClassAccuracyStats {
  final int classIndex;
  final int sampleCount;
  final double accuracy; // -1 means no data
  final int errorCount;

  ClassAccuracyStats({
    required this.classIndex,
    required this.sampleCount,
    required this.accuracy,
    required this.errorCount,
  });
}
