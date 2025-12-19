import 'dart:async';
import 'dart:collection';
import '../models/detection_record.dart';

/// Service for managing equipment detection timeline with interactive features
class TimelineService {
  TimelineService._();
  
  static final TimelineService instance = TimelineService._();
  
  final List<DetectionRecord> _records = [];
  final StreamController<TimelineUpdate> _timelineController = 
      StreamController<TimelineUpdate>.broadcast();
  
  Stream<TimelineUpdate> get timelineUpdates => _timelineController.stream;
  
  // Timeline view modes
  TimelineViewMode _currentViewMode = TimelineViewMode.day;
  TimelineViewMode get currentViewMode => _currentViewMode;
  
  DateTime _focusedDate = DateTime.now();
  DateTime get focusedDate => _focusedDate;
  
  // Filters
  Set<String> _equipmentFilters = {};
  Set<String> get equipmentFilters => _equipmentFilters;
  
  bool _showVerifiedOnly = false;
  bool get showVerifiedOnly => _showVerifiedOnly;
  
  // Timeline data
  List<TimelineEvent> _timelineEvents = [];
  List<TimelineEvent> get timelineEvents => _timelineEvents;
  
  /// Add detection records to timeline
  void addRecords(List<DetectionRecord> records) {
    _records.addAll(records);
    _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _rebuildTimeline();
    _timelineController.add(TimelineUpdate(
      type: TimelineUpdateType.recordsAdded,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Update all records (replace existing records with new ones)
  void updateRecords(List<DetectionRecord> records) {
    _records.clear();
    _records.addAll(records);
    _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _rebuildTimeline();
    _timelineController.add(TimelineUpdate(
      type: TimelineUpdateType.recordsAdded,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Add single detection record
  void addRecord(DetectionRecord record) {
    _records.add(record);
    _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _rebuildTimeline();
    _timelineController.add(TimelineUpdate(
      type: TimelineUpdateType.recordAdded,
      record: record,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Change timeline view mode
  void setViewMode(TimelineViewMode mode) {
    _currentViewMode = mode;
    _rebuildTimeline();
    _timelineController.add(TimelineUpdate(
      type: TimelineUpdateType.viewModeChanged,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Focus on specific date
  void focusOnDate(DateTime date) {
    _focusedDate = date;
    _rebuildTimeline();
    _timelineController.add(TimelineUpdate(
      type: TimelineUpdateType.dateChanged,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Toggle equipment filter
  void toggleEquipmentFilter(String equipmentName) {
    if (_equipmentFilters.contains(equipmentName)) {
      _equipmentFilters.remove(equipmentName);
    } else {
      _equipmentFilters.add(equipmentName);
    }
    _rebuildTimeline();
    _timelineController.add(TimelineUpdate(
      type: TimelineUpdateType.filterChanged,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Toggle verified only filter
  void toggleVerifiedOnly() {
    _showVerifiedOnly = !_showVerifiedOnly;
    _rebuildTimeline();
    _timelineController.add(TimelineUpdate(
      type: TimelineUpdateType.filterChanged,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Clear all filters
  void clearFilters() {
    _equipmentFilters.clear();
    _showVerifiedOnly = false;
    _rebuildTimeline();
    _timelineController.add(TimelineUpdate(
      type: TimelineUpdateType.filterChanged,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Rebuild timeline events based on current settings
  void _rebuildTimeline() {
    _timelineEvents.clear();
    
    // Filter records based on current settings
    var filteredRecords = _records.where((record) {
      // Date filter based on view mode
      if (!_isRecordInDateRange(record)) return false;
      
      // Equipment filter
      if (_equipmentFilters.isNotEmpty && 
          !_equipmentFilters.contains(record.predictedClass)) return false;
      
      // Verified filter
      if (_showVerifiedOnly && !record.isVerified) return false;
      
      return true;
    }).toList();
    
    // Group records by time periods based on view mode
    final groupedRecords = _groupRecordsByTimePeriod(filteredRecords);
    
    // Create timeline events
    for (final entry in groupedRecords.entries) {
      final period = entry.key;
      final records = entry.value;
      
      _timelineEvents.add(TimelineEvent(
        period: period,
        records: records,
        eventCount: records.length,
        uniqueEquipment: records.map((r) => r.predictedClass).toSet().length,
        avgConfidence: records.map((r) => r.confidence).reduce((a, b) => a + b) / records.length,
      ));
    }
    
    // Sort events by period
    _timelineEvents.sort((a, b) => b.period.compareTo(a.period));
  }
  
  bool _isRecordInDateRange(DetectionRecord record) {
    switch (_currentViewMode) {
      case TimelineViewMode.day:
        return _isSameDay(record.timestamp, _focusedDate);
      case TimelineViewMode.week:
        return _isSameWeek(record.timestamp, _focusedDate);
      case TimelineViewMode.month:
        return _isSameMonth(record.timestamp, _focusedDate);
      case TimelineViewMode.year:
        return _isSameYear(record.timestamp, _focusedDate);
    }
  }
  
  Map<DateTime, List<DetectionRecord>> _groupRecordsByTimePeriod(List<DetectionRecord> records) {
    final grouped = <DateTime, List<DetectionRecord>>{};
    
    for (final record in records) {
      DateTime period;
      
      switch (_currentViewMode) {
        case TimelineViewMode.day:
          period = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
          break;
        case TimelineViewMode.week:
          period = _getWeekStart(record.timestamp);
          break;
        case TimelineViewMode.month:
          period = DateTime(record.timestamp.year, record.timestamp.month, 1);
          break;
        case TimelineViewMode.year:
          period = DateTime(record.timestamp.year, 1, 1);
          break;
      }
      
      grouped.putIfAbsent(period, () => []).add(record);
    }
    
    return grouped;
  }
  
  DateTime _getWeekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  bool _isSameWeek(DateTime a, DateTime b) {
    final weekStartA = _getWeekStart(a);
    final weekStartB = _getWeekStart(b);
    return _isSameDay(weekStartA, weekStartB);
  }
  
  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
  
  bool _isSameYear(DateTime a, DateTime b) {
    return a.year == b.year;
  }
  
  /// Get timeline statistics
  TimelineStats getTimelineStats() {
    if (_timelineEvents.isEmpty) {
      return const TimelineStats(
        totalEvents: 0,
        totalDetections: 0,
        uniqueEquipment: 0,
        avgConfidence: 0.0,
        mostActivePeriod: null,
      );
    }
    
    int totalDetections = 0;
    Set<String> allEquipment = {};
    double totalConfidence = 0.0;
    TimelineEvent? mostActive;
    
    for (final event in _timelineEvents) {
      totalDetections += event.eventCount;
      allEquipment.addAll(event.records.map((r) => r.predictedClass));
      totalConfidence += event.avgConfidence;
      
      if (mostActive == null || event.eventCount > mostActive!.eventCount) {
        mostActive = event;
      }
    }
    
    return TimelineStats(
      totalEvents: _timelineEvents.length,
      totalDetections: totalDetections,
      uniqueEquipment: allEquipment.length,
      avgConfidence: totalConfidence / _timelineEvents.length,
      mostActivePeriod: mostActive?.period,
    );
  }
  
  /// Export timeline data
  Map<String, dynamic> exportTimelineData() {
    return {
      'viewMode': _currentViewMode.name,
      'focusedDate': _focusedDate.toIso8601String(),
      'equipmentFilters': _equipmentFilters.toList(),
      'showVerifiedOnly': _showVerifiedOnly,
      'events': _timelineEvents.map((e) => e.toJson()).toList(),
      'stats': getTimelineStats().toJson(),
    };
  }
  
  void dispose() {
    _timelineController.close();
  }
}

class TimelineEvent {
  final DateTime period;
  final List<DetectionRecord> records;
  final int eventCount;
  final int uniqueEquipment;
  final double avgConfidence;
  
  const TimelineEvent({
    required this.period,
    required this.records,
    required this.eventCount,
    required this.uniqueEquipment,
    required this.avgConfidence,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'period': period.toIso8601String(),
      'eventCount': eventCount,
      'uniqueEquipment': uniqueEquipment,
      'avgConfidence': avgConfidence,
      'records': records.map((r) => r.toJson()).toList(),
    };
  }
}

class TimelineUpdate {
  final TimelineUpdateType type;
  final DetectionRecord? record;
  final DateTime timestamp;
  
  const TimelineUpdate({
    required this.type,
    this.record,
    required this.timestamp,
  });
}

class TimelineStats {
  final int totalEvents;
  final int totalDetections;
  final int uniqueEquipment;
  final double avgConfidence;
  final DateTime? mostActivePeriod;
  
  const TimelineStats({
    required this.totalEvents,
    required this.totalDetections,
    required this.uniqueEquipment,
    required this.avgConfidence,
    this.mostActivePeriod,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'totalEvents': totalEvents,
      'totalDetections': totalDetections,
      'uniqueEquipment': uniqueEquipment,
      'avgConfidence': avgConfidence,
      'mostActivePeriod': mostActivePeriod?.toIso8601String(),
    };
  }
}

enum TimelineViewMode {
  day,
  week,
  month,
  year,
}

enum TimelineUpdateType {
  recordsAdded,
  recordAdded,
  viewModeChanged,
  dateChanged,
  filterChanged,
}
