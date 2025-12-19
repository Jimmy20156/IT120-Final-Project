import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/detection_record.dart';
import '../models/capture_progress.dart';
import '../models/record_filter.dart';
import 'detection_storage_service.dart';

/// Firebase service for equipment detection data operations
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();
  
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final String _collection = 'equipment_detections';
  final String _progressCollection = 'capture_progress';
  
  // Offline queue for when Firebase is not available
  static final List<Map<String, dynamic>> _offlineQueue = [];
  static bool _isOnline = true;
  
  /// Quick connection test (Realtime Database only)
  Future<bool> quickConnectionTest() async {
    try {
      await _database.ref('connection_test').limitToFirst(1).get();
      _isOnline = true;
      return true;
    } catch (e) {
      _isOnline = false;
      return false;
    }
  }
  /// Save a detection record to Firebase Realtime Database with offline support
  Future<void> saveDetection(DetectionRecord record) async {
    try {
      debugPrint('Firebase: Attempting to save detection ${record.id}');
      
      // Check if online first
      final isOnline = await quickConnectionTest();
      
      if (isOnline) {
        // Save directly to Firebase
        await _database.ref('$_collection/${record.id}').set(record.toJson());
        debugPrint('Firebase: Detection saved successfully: ${record.id}');
        
        // Try to sync any offline data
        await _syncOfflineQueue();
      } else {
        // Add to offline queue
        debugPrint('Firebase: Offline - Adding detection to queue: ${record.id}');
        _offlineQueue.add({
          'type': 'detection',
          'data': record.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Firebase: Error saving detection ${record.id}: $e');
      // Add to offline queue as fallback
      _offlineQueue.add({
        'type': 'detection',
        'data': record.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
  
  /// Sync offline queue when connection is restored
  Future<void> _syncOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    
    debugPrint('Firebase: Syncing ${_offlineQueue.length} offline items');
    
    final queueCopy = List<Map<String, dynamic>>.from(_offlineQueue);
    _offlineQueue.clear();
    
    for (final item in queueCopy) {
      try {
        if (item['type'] == 'detection') {
          final data = Map<String, dynamic>.from(item['data']);
          await _database.ref('$_collection/${data['id']}').set(data);
          debugPrint('Firebase: Synced detection ${data['id']}');
        } else if (item['type'] == 'progress') {
          final data = Map<String, dynamic>.from(item['data']);
          await _database.ref('$_progressCollection/${data['equipmentIndex']}').set(data);
          debugPrint('Firebase: Synced progress for ${data['equipmentClass']}');
        }
      } catch (e) {
        debugPrint('Firebase: Failed to sync item, re-adding to queue: $e');
        _offlineQueue.add(item); // Re-add to queue if sync fails
      }
    }
  }
  
  /// Save capture progress with offline support
  Future<void> saveCaptureProgress(Map<String, dynamic> progressData) async {
    try {
      debugPrint('Firebase: Attempting to save progress for ${progressData['equipmentClass']}');
      
      final isOnline = await quickConnectionTest();
      
      if (isOnline) {
        await _database.ref('$_progressCollection/${progressData['equipmentIndex']}').set(progressData);
        debugPrint('Firebase: Progress saved successfully for ${progressData['equipmentClass']}');
        await _syncOfflineQueue();
      } else {
        debugPrint('Firebase: Offline - Adding progress to queue for ${progressData['equipmentClass']}');
        _offlineQueue.add({
          'type': 'progress',
          'data': progressData,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Firebase: Error saving progress for ${progressData['equipmentClass']}: $e');
      _offlineQueue.add({
        'type': 'progress',
        'data': progressData,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
  Stream<List<DetectionRecord>> getAllDetections() {
    return _database
        .ref(_collection)
        .orderByChild('timestamp')
        .onValue
        .map((event) {
          if (event.snapshot.value == null) return <DetectionRecord>[];
          
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final records = data.entries
              .map((entry) => DetectionRecord.fromJson(Map<String, dynamic>.from(entry.value as Map)))
              .toList()
              .where((record) => record.timestamp != null)
              .toList();
          
          // Sort by timestamp descending
          records.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
          
          return records;
        });
  }
  
  /// Get detections filtered by equipment type
  Stream<List<DetectionRecord>> getDetectionsByEquipment(String equipmentClass) {
    return _database
        .ref(_collection)
        .orderByChild('groundTruthClass')
        .equalTo(equipmentClass)
        .onValue
        .map((event) {
          if (event.snapshot.value == null) return <DetectionRecord>[];
          
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final records = data.entries
              .map((entry) => DetectionRecord.fromJson(Map<String, dynamic>.from(entry.value as Map)))
              .toList()
              .where((record) => record.timestamp != null)
              .toList();
          
          // Sort by timestamp descending
          records.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
          
          return records;
        });
  }
  
  /// Get detections within a date range
  Stream<List<DetectionRecord>> getDetectionsByDateRange(DateTime start, DateTime end) {
    return _database
        .ref(_collection)
        .orderByChild('timestamp')
        .startAt(start.millisecondsSinceEpoch)
        .endAt(end.millisecondsSinceEpoch)
        .onValue
        .map((event) {
          if (event.snapshot.value == null) return <DetectionRecord>[];
          
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final records = data.entries
              .map((entry) => DetectionRecord.fromJson(Map<String, dynamic>.from(entry.value as Map)))
              .where((record) => record.timestamp != null)
              .where((record) => record.timestamp!.isAfter(start) && record.timestamp!.isBefore(end))
              .toList();
          
          // Sort by timestamp descending
          records.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
          
          return records;
        });
  }
  
  /// Get analytics data for charts
  Future<Map<String, dynamic>> getAnalyticsData() async {
    try {
      final snapshot = await _database.ref(_collection).get();
      if (snapshot.value == null) {
        return {
          'totalDetections': 0,
          'equipmentCounts': <String, int>{},
          'avgConfidenceByEquipment': <String, double>{},
          'accuracy': 0.0,
          'recentDetections': <DetectionRecord>[],
        };
      }
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final detections = data.entries
          .map((entry) => DetectionRecord.fromJson(Map<String, dynamic>.from(entry.value as Map)))
          .toList();
      
      // Count detections by equipment type
      final equipmentCounts = <String, int>{};
      final confidenceByEquipment = <String, List<double>>{};
      
      for (final detection in detections) {
        equipmentCounts[detection.groundTruthClass] = 
            (equipmentCounts[detection.groundTruthClass] ?? 0) + 1;
        
        confidenceByEquipment[detection.groundTruthClass] ??= [];
        confidenceByEquipment[detection.groundTruthClass]!.add(detection.confidence);
      }
      
      // Calculate average confidence by equipment
      final avgConfidenceByEquipment = <String, double>{};
      confidenceByEquipment.forEach((equipment, confidences) {
        final total = confidences.reduce((a, b) => a + b);
        avgConfidenceByEquipment[equipment] = total / confidences.length;
      });
      
      // Calculate accuracy - only use records with valid ground truth
      final validDetections = detections.where((d) => d.groundTruthIndex >= 0).toList();
      final correctDetections = validDetections.where((d) => d.isCorrect).length;
      final accuracy = validDetections.isNotEmpty ? correctDetections / validDetections.length : 0.0;
      
      debugPrint('Firebase: Total detections: ${detections.length}');
      debugPrint('Firebase: Valid detections (ground truth >= 0): ${validDetections.length}');
      debugPrint('Firebase: Correct detections: $correctDetections');
      debugPrint('Firebase: Calculated accuracy: $accuracy');
      
      // Sort by timestamp and get recent detections
      detections.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
      
      return {
        'totalDetections': detections.length,
        'equipmentCounts': equipmentCounts,
        'avgConfidenceByEquipment': avgConfidenceByEquipment,
        'accuracy': accuracy,
        'recentDetections': detections.take(10).toList(),
      };
    } catch (e) {
      throw Exception('Failed to get analytics data: $e');
    }
  }
  
  /// Get daily detection counts for the last 30 days
  Future<Map<String, int>> getDailyDetectionCounts() async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      final snapshot = await _database.ref(_collection).get();
      if (snapshot.value == null) return <String, int>{};
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final dailyCounts = <String, int>{};
      
      for (final entry in data.entries) {
        final detection = DetectionRecord.fromJson(Map<String, dynamic>.from(entry.value as Map));
        if (detection.timestamp != null && detection.timestamp!.isAfter(thirtyDaysAgo)) {
          final dayKey = '${detection.timestamp!.year}-${detection.timestamp!.month.toString().padLeft(2, '0')}-${detection.timestamp!.day.toString().padLeft(2, '0')}';
          dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
        }
      }
      
      return dailyCounts;
    } catch (e) {
      throw Exception('Failed to get daily counts: $e');
    }
  }
  
  /// Delete a detection record
  Future<void> deleteDetection(String recordId) async {
    try {
      await _database.ref('$_collection/$recordId').remove();
    } catch (e) {
      throw Exception('Failed to delete detection: $e');
    }
  }
  
  /// Get real-time analytics data from Firebase with local fallback
  Future<Map<String, dynamic>> getRealTimeAnalytics() async {
    try {
      // Try Firebase first
      final snapshot = await _database.ref('equipment_detections').get();
      
      if (snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final detections = data.entries
            .map((entry) => Map<String, dynamic>.from(entry.value as Map))
            .toList();
        
        // Count detections by equipment type
        final equipmentCounts = <String, int>{};
        final confidenceByEquipment = <String, List<double>>{};
        
        for (final detection in detections) {
          final equipmentClass = detection['groundTruthClass'] as String;
          equipmentCounts[equipmentClass] = (equipmentCounts[equipmentClass] ?? 0) + 1;
          
          confidenceByEquipment[equipmentClass] ??= [];
          confidenceByEquipment[equipmentClass]!.add(detection['confidence'] as double);
        }
        
        // Calculate average confidence by equipment
        final avgConfidenceByEquipment = <String, double>{};
        confidenceByEquipment.forEach((equipment, confidences) {
          final total = confidences.reduce((a, b) => a + b);
          avgConfidenceByEquipment[equipment] = total / confidences.length;
        });
        
        // Calculate accuracy - only use records with valid ground truth
        final validDetections = detections.where((d) => (d['groundTruthIndex'] as int? ?? -1) >= 0).toList();
        final correctDetections = validDetections.where((d) => d['isCorrect'] == true).length;
        final accuracy = validDetections.isNotEmpty ? correctDetections / validDetections.length : 0.0;
        
        debugPrint('Firebase (fallback): Total detections: ${detections.length}');
        debugPrint('Firebase (fallback): Valid detections (ground truth >= 0): ${validDetections.length}');
        debugPrint('Firebase (fallback): Correct detections: $correctDetections');
        debugPrint('Firebase (fallback): Calculated accuracy: $accuracy');
        
        return {
          'status': 'success',
          'totalDetections': detections.length,
          'equipmentCounts': equipmentCounts,
          'avgConfidenceByEquipment': avgConfidenceByEquipment,
          'accuracy': accuracy,
          'recentDetections': detections.take(10).toList(),
          'source': 'firebase',
        };
      }
    } catch (e) {
      debugPrint('Firebase: Analytics failed, falling back to local: $e');
    }
    
    // Fallback to local storage
    return _getLocalAnalytics();
  }
  
  /// Get analytics from local storage (fallback)
  Map<String, dynamic> _getLocalAnalytics() {
    try {
      // Import here to avoid circular dependency
      final storage = DetectionStorageService.instance;
      final totalDetections = storage.getTotalDetections(RecordFilter.all);
      final accuracy = storage.getAccuracy(RecordFilter.all);
      final perClassCounts = storage.getDetectionsPerClass(RecordFilter.all);
      
      return {
        'status': 'success',
        'totalDetections': totalDetections,
        'equipmentCounts': perClassCounts,
        'avgConfidenceByEquipment': <String, double>{},
        'accuracy': accuracy,
        'recentDetections': <Map<String, dynamic>>[],
        'source': 'local',
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'totalDetections': 0,
        'equipmentCounts': <String, int>{},
        'avgConfidenceByEquipment': <String, double>{},
        'accuracy': 0.0,
        'recentDetections': <Map<String, dynamic>>[],
        'source': 'error',
      };
    }
  }
  
  /// Get capture progress data from Firebase
  Future<Map<String, dynamic>> getCaptureProgress() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      final snapshot = await _database.ref('capture_progress').get();
      
      stopwatch.stop();
      debugPrint('Firebase progress read time: ${stopwatch.elapsedMilliseconds}ms');
      
      if (snapshot.value == null) {
        return {
          'status': 'no_data',
          'totalEquipmentClasses': 0,
          'completedClasses': 0,
          'overallPercentage': 0.0,
          'totalCaptures': 0,
          'totalTargetCaptures': 0,
          'progressByClass': <Map<String, dynamic>>[],
          'readTime': '${stopwatch.elapsedMilliseconds}ms',
        };
      }
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final progressList = data.entries
          .map((entry) => Map<String, dynamic>.from(entry.value as Map))
          .toList();
      
      int totalCaptures = 0;
      int totalTargetCaptures = 0;
      int completedClasses = 0;
      
      for (final progress in progressList) {
        totalCaptures += progress['totalCaptures'] as int;
        totalTargetCaptures += progress['targetCaptures'] as int;
        
        if ((progress['percentageComplete'] as double) >= 100.0) {
          completedClasses++;
        }
      }
      
      final overallPercentage = totalTargetCaptures > 0 
          ? (totalCaptures / totalTargetCaptures) * 100.0 
          : 0.0;
      
      return {
        'status': 'success',
        'totalEquipmentClasses': progressList.length,
        'completedClasses': completedClasses,
        'overallPercentage': overallPercentage,
        'totalCaptures': totalCaptures,
        'totalTargetCaptures': totalTargetCaptures,
        'progressByClass': progressList,
        'readTime': '${stopwatch.elapsedMilliseconds}ms',
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'totalEquipmentClasses': 0,
        'completedClasses': 0,
        'overallPercentage': 0.0,
        'totalCaptures': 0,
        'totalTargetCaptures': 0,
        'progressByClass': <Map<String, dynamic>>[],
      };
    }
  }

  /// Clear all detection records from Firebase Realtime Database
  Future<void> clearAllDetections() async {
    try {
      debugPrint('Firebase: Clearing all detection records...');
      
      // Check if online first
      final isOnline = await quickConnectionTest();
      
      if (!isOnline) {
        throw Exception('Firebase is not connected. Cannot clear data.');
      }
      
      // Clear all detection records
      await _database.ref(_collection).remove();
      
      debugPrint('Firebase: All detection records cleared successfully');
    } catch (e) {
      debugPrint('Firebase: Failed to clear detection records: $e');
      rethrow;
    }
  }
}
