import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

/// Helper class for Firebase operations with better error handling
class FirebaseHelper {
  FirebaseHelper._();
  static final FirebaseHelper instance = FirebaseHelper._();
  
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  /// Save detection record with detailed error logging
  Future<bool> saveDetectionRecord(Map<String, dynamic> detectionData) async {
    try {
      debugPrint('Firebase: Starting save for detection ${detectionData['id']}');
      
      // Check database connection
      final isConnected = await testConnection();
      if (!isConnected) {
        debugPrint('Firebase: Connection test failed');
        return false;
      }
      
      // Save the detection record
      final ref = _database.ref('equipment_detections/${detectionData['id']}');
      await ref.set(detectionData);
      
      // Verify the save
      final snapshot = await ref.get();
      if (snapshot.value != null) {
        debugPrint('Firebase: Successfully saved detection ${detectionData['id']}');
        return true;
      } else {
        debugPrint('Firebase: Save verification failed for detection ${detectionData['id']}');
        return false;
      }
    } catch (e) {
      debugPrint('Firebase: Error saving detection ${detectionData['id']}: $e');
      debugPrint('Firebase: Error details: ${e.runtimeType}');
      return false;
    }
  }
  
  /// Save capture progress with error handling
  Future<bool> saveCaptureProgress(Map<String, dynamic> progressData) async {
    try {
      debugPrint('Firebase: Starting save for progress ${progressData['equipmentClass']}');
      
      final ref = _database.ref('capture_progress/${progressData['equipmentIndex']}');
      await ref.set(progressData);
      
      debugPrint('Firebase: Successfully saved progress for ${progressData['equipmentClass']}');
      return true;
    } catch (e) {
      debugPrint('Firebase: Error saving progress for ${progressData['equipmentClass']}: $e');
      return false;
    }
  }
  
  /// Test basic Firebase connection
  Future<bool> testConnection() async {
    try {
      final ref = _database.ref('.info/connected');
      final snapshot = await ref.get();
      final connected = snapshot.value == true;
      debugPrint('Firebase: Connection test result: $connected');
      return connected;
    } catch (e) {
      debugPrint('Firebase: Connection test error: $e');
      return false;
    }
  }
  
  /// Get all detections with error handling
  Future<Map<String, dynamic>?> getAllDetections() async {
    try {
      final ref = _database.ref('equipment_detections');
      final snapshot = await ref.get();
      
      if (snapshot.value != null) {
        debugPrint('Firebase: Retrieved ${snapshot.value.runtimeType} from equipment_detections');
        return Map<String, dynamic>.from(snapshot.value as Map);
      } else {
        debugPrint('Firebase: No data found in equipment_detections');
        return null;
      }
    } catch (e) {
      debugPrint('Firebase: Error getting detections: $e');
      return null;
    }
  }
  
  /// Get capture progress data
  Future<Map<String, dynamic>?> getCaptureProgress() async {
    try {
      final ref = _database.ref('capture_progress');
      final snapshot = await ref.get();
      
      if (snapshot.value != null) {
        debugPrint('Firebase: Retrieved progress data');
        return Map<String, dynamic>.from(snapshot.value as Map);
      } else {
        debugPrint('Firebase: No progress data found');
        return null;
      }
    } catch (e) {
      debugPrint('Firebase: Error getting progress: $e');
      return null;
    }
  }
}
