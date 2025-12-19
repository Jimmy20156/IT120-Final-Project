import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import '../../app_theme.dart';
import '../../core/services/smart_scanner_service.dart';
import '../../core/services/detection_storage_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/models/detection_record.dart';

class ARCameraDetectionPage extends StatefulWidget {
  final double confidenceThreshold;
  final bool isARMode;
  
  const ARCameraDetectionPage({
    super.key,
    required this.confidenceThreshold,
    required this.isARMode,
  });

  @override
  State<ARCameraDetectionPage> createState() => _ARCameraDetectionPageState();
}

class _ARCameraDetectionPageState extends State<ARCameraDetectionPage>
    with WidgetsBindingObserver {
  late CameraController _cameraController;
  final _scannerService = SmartScannerService.instance;
  final _storageService = DetectionStorageService.instance;
  final _firebaseService = FirebaseService.instance;
  final _imagePicker = ImagePicker();
  
  bool _isCameraInitialized = false;
  ScanResult? _lastScanResult;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        
        await _cameraController.initialize();
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to initialize camera: $e');
    }
  }

  Future<void> _captureManualPhoto() async {
    if (_cameraController.value.isTakingPicture) return;
    
    try {
      final image = await _cameraController.takePicture();
      final result = await _scannerService.classifyImage(File(image.path));
      
      if (result != null) {
        // Save detection record to local storage and Firebase
        await _saveDetectionResult(result);
        
        _showDetailedResults(result, File(image.path));
      }
    } catch (e) {
      _showErrorDialog('Failed to capture photo: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        final result = await _scannerService.classifyImage(File(image.path));
        
        if (result != null) {
          // Save detection record to local storage and Firebase
          await _saveDetectionResult(result);
          
          _showDetailedResults(result, File(image.path));
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image from gallery: $e');
    }
  }

  Future<void> _saveDetectionResult(ScanResult result) async {
    try {
      // Create detection record
      final record = DetectionRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        groundTruthClass: result.predictedClass,
        groundTruthIndex: result.predictedIndex,
        predictedClass: result.predictedClass,
        predictedIndex: result.predictedIndex,
        confidence: result.confidence,
        scores: result.scores,
      );

      // Save to local storage
      await _storageService.saveRecord(record);
      debugPrint('Local: Detection saved: ${record.id}');

      // Save to Firebase
      try {
        await _firebaseService.saveDetection(record);
        debugPrint('Firebase: Detection save initiated: ${record.id}');
      } catch (e) {
        debugPrint('Firebase: Detection save failed: $e');
        // Continue even if Firebase save fails
      }

    } catch (e) {
      debugPrint('Failed to save detection result: $e');
    }
  }

  void _showDetailedResults(ScanResult result, File imageFile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detection Results',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  imageFile,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      result.predictedClass,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'All Equipment Classes',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildClassScoresList(result),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassScoresList(ScanResult result) {
    // Create list of (index, score, label) tuples and sort by score descending
    final classScores = <Map<String, dynamic>>[];
    for (int i = 0; i < result.scores.length; i++) {
      final score = result.scores[i];
      final label = i < _scannerService.labels.length 
          ? _scannerService.labels[i] 
          : 'Unknown Class $i';
      
      classScores.add({
        'index': i,
        'score': score,
        'label': label,
      });
    }
    
    // Sort by score descending
    classScores.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    
    return ListView.builder(
      itemCount: classScores.length,
      itemBuilder: (context, index) {
        final classData = classScores[index];
        final score = classData['score'] as double;
        final label = classData['label'] as String;
        final isTopPrediction = label == result.predictedClass;
        final percentage = (score * 100).toStringAsFixed(1);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isTopPrediction 
                ? AppColors.primaryBlue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: isTopPrediction 
                ? Border.all(color: AppColors.primaryBlue.withOpacity(0.3))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isTopPrediction ? FontWeight.bold : FontWeight.normal,
                        color: isTopPrediction ? AppColors.primaryBlue : null,
                      ),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isTopPrediction ? AppColors.primaryBlue : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                ),
                child: LinearProgressIndicator(
                  value: score,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isTopPrediction ? AppColors.primaryBlue : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildAROverlay() {
    if (_lastScanResult == null) return const SizedBox.shrink();
    
    return Positioned(
      top: 100,
      left: 50,
      right: 50,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          children: [
            const Text(
              'DETECTED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _lastScanResult!.predictedClass,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(_lastScanResult!.confidence * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CameraPreview(_cameraController),
          ),
          
          // AR Overlay
          if (widget.isARMode && _lastScanResult != null)
            _buildAROverlay(),
          
          // Top controls
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Camera Ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom controls
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                FloatingActionButton(
                  onPressed: _pickImageFromGallery,
                  backgroundColor: AppColors.primaryBlue,
                  heroTag: "gallery",
                  child: const Icon(Icons.photo_library, color: Colors.white),
                ),
                // Camera button
                FloatingActionButton(
                  onPressed: _captureManualPhoto,
                  backgroundColor: AppColors.primaryBlue,
                  heroTag: "camera",
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Detection result overlay
          if (_lastScanResult != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lastScanResult!.predictedClass,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${(_lastScanResult!.confidence * 100).round()}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
