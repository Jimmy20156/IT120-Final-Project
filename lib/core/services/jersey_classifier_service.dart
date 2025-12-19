import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class JerseyClassifierService {
  JerseyClassifierService._();

  static final JerseyClassifierService instance = JerseyClassifierService._();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _modelLoaded = false;
  int _inputHeight = 224;
  int _inputWidth = 224;

  List<String> get labels => _labels;

  Future<void> ensureModelLoaded() async {
    if (_modelLoaded) return;

    // Load the model from assets using rootBundle
    final modelData = await rootBundle.load('assets/model_unquant.tflite');
    final buffer = modelData.buffer.asUint8List();
    _interpreter = Interpreter.fromBuffer(buffer);

    // Get input shape from interpreter
    final inputShape = _interpreter!.getInputTensor(0).shape;
    _inputHeight = inputShape[1];
    _inputWidth = inputShape[2];

    // Load labels
    final labelsData = await rootBundle.loadString('assets/labels.txt');
    _labels = labelsData
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _modelLoaded = true;
  }

  Future<ClassificationResult?> classifyImage(File imageFile) async {
    await ensureModelLoaded();

    if (_interpreter == null) return null;

    // Read and decode image
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    return _runInference(image);
  }

  /// Classify a CameraImage frame for real-time detection
  ClassificationResult? classifyCameraImage(CameraImage cameraImage) {
    if (_interpreter == null || !_modelLoaded) return null;

    try {
      // Convert CameraImage to img.Image
      final image = _convertCameraImage(cameraImage);
      if (image == null) return null;

      return _runInference(image);
    } catch (e) {
      return null;
    }
  }

  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      // Handle YUV420 format (most common on Android)
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(cameraImage);
      }
      // Handle BGRA8888 format (iOS)
      else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(cameraImage);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x * yPixelStride;
        final int uvIndex =
            (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final double yValue = yBytes[yIndex].toDouble();
        final double uValue = uBytes[uvIndex].toDouble() - 128.0;
        final double vValue = vBytes[uvIndex].toDouble() - 128.0;

        int r = (yValue + 1.402 * vValue).round().clamp(0, 255);
        int g = (yValue - 0.344136 * uValue - 0.714136 * vValue)
            .round()
            .clamp(0, 255);
        int b = (yValue + 1.772 * uValue).round().clamp(0, 255);

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  img.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    final plane = cameraImage.planes[0];
    final width = cameraImage.width;
    final height = cameraImage.height;

    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = y * plane.bytesPerRow + x * 4;
        final b = plane.bytes[index];
        final g = plane.bytes[index + 1];
        final r = plane.bytes[index + 2];
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  ClassificationResult? _runInference(img.Image image) {
    // Resize image to model input size
    final resizedImage = img.copyResize(
      image,
      width: _inputWidth,
      height: _inputHeight,
    );

    // Prepare input tensor (normalize to 0-1 range)
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputHeight,
        (y) => List.generate(
          _inputWidth,
          (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    // Prepare output tensor
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final numClasses = outputShape[1];
    final output = List.generate(1, (_) => List.filled(numClasses, 0.0));

    // Run inference
    _interpreter!.run(input, output);

    final scores = output[0];

    // Find top result
    int topIndex = 0;
    double topConfidence = scores[0];
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > topConfidence) {
        topConfidence = scores[i];
        topIndex = i;
      }
    }

    final topLabel = topIndex < _labels.length ? _labels[topIndex] : 'Unknown';

    return ClassificationResult(
      topLabel: topLabel,
      topIndex: topIndex,
      topConfidence: topConfidence,
      scores: scores,
    );
  }

  /// Get clean label name (remove index prefix if present)
  String cleanLabel(String label) {
    if (label.contains(' ')) {
      final parts = label.split(' ');
      if (int.tryParse(parts[0]) != null) {
        return parts.sublist(1).join(' ');
      }
    }
    return label;
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }
}

class ClassificationResult {
  const ClassificationResult({
    required this.topLabel,
    required this.topIndex,
    required this.topConfidence,
    required this.scores,
  });

  final String topLabel;
  final int topIndex;
  final double topConfidence;
  final List<double> scores;
}
