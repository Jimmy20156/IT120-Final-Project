import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../core/models/record_filter.dart';
import '../../core/services/detection_storage_service.dart';

class ConfusionMatrixPage extends StatefulWidget {
  const ConfusionMatrixPage({super.key});

  @override
  State<ConfusionMatrixPage> createState() => _ConfusionMatrixPageState();
}

class _ConfusionMatrixPageState extends State<ConfusionMatrixPage> {
  RecordFilter _selectedFilter = RecordFilter.all;

  @override
  Widget build(BuildContext context) {
    final numClasses = AppColors.classNames.length;
    final storage = DetectionStorageService.instance;
    final matrix = storage.buildConfusionMatrix(numClasses, _selectedFilter);

    const double cellSize = 32.0;
    const double colorBarWidth = 4.0;
    const double labelHeight = 80.0;
    const double leftLabelWidth = 56.0;

    // Shortened class names for left-side labels (farm equipment)
    const List<String> shortClassNames = [
      'Cultivator',
      'Harrow',
      'Plough',
      'Rake',
      'Rotivator',
      'Seeder',
      'Truck',
      'Sprinkler',
      'Harvester',
      'Tractor',
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Confusion Matrix'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title row with help icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Confusion Matrix',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _showHelpDialog(context);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Filter dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.textSecondary.withOpacity(0.2),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RecordFilter>(
                    value: _selectedFilter,
                    isDense: true,
                    icon: const Icon(Icons.filter_list, size: 18),
                    items: RecordFilter.values.map((filter) {
                      return DropdownMenuItem(
                        value: filter,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFilterIcon(filter),
                              size: 14,
                              color: _getFilterColor(filter),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              filter.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (filter) {
                      if (filter != null) {
                        setState(() => _selectedFilter = filter);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Matrix grid
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Matrix rows
                        for (int row = 0; row < numClasses; row++)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Left-side label
                              SizedBox(
                                width: leftLabelWidth,
                                height: cellSize,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Text(
                                      shortClassNames[row],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary.withOpacity(0.8),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // Color bar indicator
                              Container(
                                width: colorBarWidth,
                                height: cellSize,
                                decoration: BoxDecoration(
                                  color: AppColors.classColors[row],
                                  borderRadius: BorderRadius.only(
                                    topLeft: row == 0
                                        ? const Radius.circular(4)
                                        : Radius.zero,
                                    bottomLeft: row == numClasses - 1
                                        ? const Radius.circular(4)
                                        : Radius.zero,
                                  ),
                                ),
                              ),
                              // Matrix cells
                              for (int col = 0; col < numClasses; col++)
                                _buildCell(
                                  count: matrix[row][col],
                                  isDiagonal: row == col,
                                  cellSize: cellSize,
                                ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        // Bottom labels
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: leftLabelWidth + colorBarWidth),
                            for (int col = 0; col < numClasses; col++)
                              SizedBox(
                                width: cellSize + 2, // Account for cell margin
                                height: labelHeight,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: SizedBox(
                                        width: labelHeight,
                                        child: Text(
                                          shortClassNames[col],
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary
                                                .withOpacity(0.8),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Prediction label
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: leftLabelWidth + colorBarWidth),
                            SizedBox(
                              width: (cellSize + 2) * numClasses,
                              child: const Center(
                                child: Text(
                                  'Prediction',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell({
    required int count,
    required bool isDiagonal,
    required double cellSize,
  }) {
    final bool hasValue = count > 0;
    final bool showBlue = isDiagonal && hasValue;

    return Container(
      width: cellSize,
      height: cellSize,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: showBlue
            ? AppColors.primaryBlue
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: showBlue
              ? Colors.white
              : AppColors.textSecondary.withOpacity(0.6),
        ),
      ),
    );
  }

  IconData _getFilterIcon(RecordFilter filter) {
    switch (filter) {
      case RecordFilter.all:
        return Icons.list;
      case RecordFilter.verified:
        return Icons.check_circle;
      case RecordFilter.notVerified:
        return Icons.pending;
    }
  }

  Color _getFilterColor(RecordFilter filter) {
    switch (filter) {
      case RecordFilter.all:
        return AppColors.primaryBlue;
      case RecordFilter.verified:
        return Colors.green;
      case RecordFilter.notVerified:
        return Colors.orange;
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confusion Matrix'),
        content: const Text(
          'A confusion matrix shows the performance of the classification model. '
          'Rows represent the actual (ground truth) classes, and columns represent '
          'the predicted classes.\n\n'
          'Diagonal cells (highlighted in blue) show correct predictions. '
          'Off-diagonal cells show misclassifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
