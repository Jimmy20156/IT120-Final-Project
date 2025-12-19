import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../core/services/detection_storage_service.dart';
import '../analytics/confusion_matrix_page.dart';

class DetectionResultPage extends StatefulWidget {
  const DetectionResultPage({
    super.key,
    this.detectedClassName = 'Unknown Equipment',
    this.confidence = 0.0,
    this.scores,
    this.recordId,
  });

  final String detectedClassName;
  final double confidence;
  final List<double>? scores;
  final String? recordId;

  @override
  State<DetectionResultPage> createState() => _DetectionResultPageState();
}

class _DetectionResultPageState extends State<DetectionResultPage> {
  bool _isVerified = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _checkIfVerified();
  }

  void _checkIfVerified() {
    if (widget.recordId != null) {
      final record = DetectionStorageService.instance.getRecordById(widget.recordId!);
      if (record != null && record.isVerified) {
        setState(() => _isVerified = true);
      }
    }
  }

  Future<void> _verifyDetection() async {
    if (widget.recordId == null || _isVerified || _isVerifying) return;

    setState(() => _isVerifying = true);

    final success = await DetectionStorageService.instance.verifyRecord(widget.recordId!);

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _isVerified = success;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detection confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final confidenceText = widget.confidence.toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Detection Result'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detected Class',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.detectedClassName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Confidence',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '$confidenceText%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Class Probabilities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: AppColors.classNames.length,
                itemBuilder: (context, index) {
                  final color = AppColors.classColors[index];
                  final className = AppColors.classNames[index];
                  final score = (widget.scores != null && index < widget.scores!.length)
                      ? widget.scores![index]
                      : 0.0;
                  final scorePercent = (score * 100).toStringAsFixed(1);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            className,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: AppColors.backgroundLight,
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: score.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 45,
                          child: Text(
                            '$scorePercent%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isVerified || _isVerifying || widget.recordId == null
                        ? null
                        : _verifyDetection,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isVerified ? 'Confirmed' : 'Confirm result'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).maybePop();
                    },
                    child: const Text('Retake'),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ConfusionMatrixPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.grid_on_rounded),
                label: const Text('View Confusion Matrix'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
