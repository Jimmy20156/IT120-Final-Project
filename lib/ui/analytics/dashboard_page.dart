import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../../app_theme.dart';
import '../../core/models/record_filter.dart';
import '../../core/services/detection_storage_service.dart';
import '../../core/services/firebase_service.dart';
import 'confusion_matrix_page.dart';
import 'firebase_analytics_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoadingFirebaseData = false;

  @override
  void initState() {
    super.initState();
    
    // Listen for data changes
    DetectionStorageService.instance.dataChanges.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use unified Firebase service for main data, but keep storage for some legacy functions
    final storage = DetectionStorageService.instance;
    
    // Handle equipmentCounts type conversion safely
    Map<String, int> equipmentCounts = {};
    final classCounts = storage.getDetectionsPerClass(RecordFilter.all);
    
    // Convert int keys to string keys for display
    classCounts.forEach((classIndex, count) {
      if (classIndex >= 0 && classIndex < AppColors.classNames.length) {
        final className = AppColors.classNames[classIndex];
        equipmentCounts[className] = count;
      }
    });
    
    final classNames = AppColors.classNames;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FirebaseAnalyticsChart(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.cloud),
                      label: const Text('Firebase Analytics'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Total Detections Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textSecondary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Detections',
                        value: '${storage.getAllRecords().length}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              const SizedBox(height: 16),
              // Line + Bar Chart: Detections/Errors (bars) + Accuracy/ErrorRate (line)
              _DailyStatsChart(
                stats: storage.getDailyStats(7, RecordFilter.all),
                isErrorMode: false,
              ),
              const SizedBox(height: 16),
              Text(
                'Per-Class Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(
                  minHeight: 200,
                  maxHeight: 400,
                ),
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
                child: _buildPerClassList(equipmentCounts, classNames),
              ),
            ],
          ),
    );
  }

  Widget _buildPerClassList(
    Map<String, int> equipmentCounts,
    List<String> classNames,
  ) {
    final entries = equipmentCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final className = entry.key;
        final count = entry.value;
        final classIndex = classNames.indexOf(className);
        final color = classIndex >= 0 && classIndex < AppColors.classColors.length
            ? AppColors.classColors[classIndex]
            : AppColors.classColors[0];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Detections: $count',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Count',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHardestEquipmentList(DetectionStorageService storage) {
    final hardest = storage.getHardestClasses(RecordFilter.all, AppColors.classNames.length);
    final classNames = AppColors.classNames;

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: hardest.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final stat = hardest[index];
        final name = classNames[stat.classIndex];
        final accText = stat.accuracy < 0
            ? 'No data'
            : '${(stat.accuracy * 100).toStringAsFixed(1)}%';
        final isStruggling = stat.accuracy >= 0 && stat.accuracy < 0.7;

        return Row(
          children: [
            // Rank badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < 3 && stat.accuracy >= 0
                    ? Colors.red.withOpacity(0.15)
                    : AppColors.textSecondary.withOpacity(0.1),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: index < 3 && stat.accuracy >= 0
                        ? Colors.red
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 10,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: AppColors.classColors[stat.classIndex % AppColors.classColors.length],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Errors: ${stat.errorCount} / ${stat.sampleCount} samples',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Accuracy',
                  style: TextStyle(
                    fontSize: 12,
                    color: isStruggling ? Colors.red : AppColors.textSecondary,
                  ),
                ),
                Text(
                  accText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isStruggling ? Colors.red : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    this.valueColor,
  });

  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Line + Bar combo chart showing daily detections (bars) and accuracy (line).
class _DailyStatsChart extends StatelessWidget {
  const _DailyStatsChart({
    required this.stats,
    this.isErrorMode = false,
  });

  final List<DailyStats> stats;
  final bool isErrorMode;

  @override
  Widget build(BuildContext context) {
    final hasData = stats.any((s) => s.detectionCount > 0);
    final maxCount = stats.isEmpty ? 0.0 : stats.map((s) => s.detectionCount).reduce(max).toDouble();
    final maxY = maxCount == 0 ? 10.0 : (maxCount * 1.2).ceilToDouble();

    return Container(
      height: 220,
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
            children: [
              Text(
                isErrorMode ? 'Daily Errors' : 'Daily Activity',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _LegendItem(
                color: isErrorMode ? Colors.red : AppColors.primaryBlue,
                label: isErrorMode ? 'Errors' : 'Detections',
              ),
              const SizedBox(width: 12),
              _LegendItem(
                color: isErrorMode ? Colors.orange : Colors.green,
                label: isErrorMode ? 'Error Rate' : 'Accuracy',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: hasData
                ? BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final stat = stats[group.x.toInt()];
                            if (isErrorMode) {
                              final errorRate =
                                  (stat.avgConfidence * 100).toStringAsFixed(1);
                              return BarTooltipItem(
                                '${_formatDate(stat.date)}\n'
                                'Errors: ${stat.detectionCount}\n'
                                'Error Rate: $errorRate%',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              );
                            }
                            final accPercent =
                                (stat.accuracy * 100).toStringAsFixed(1);
                            return BarTooltipItem(
                              '${_formatDate(stat.date)}\n'
                              'Detections: ${stat.detectionCount}\n'
                              'Accuracy: $accPercent%',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= stats.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _shortDate(stats[index].date),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              // Map from bar scale back to percentage
                              final percent = (value / maxY) * 100;
                              if (percent < 0 ||
                                  percent > 100 ||
                                  value == meta.max ||
                                  value == meta.min) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                '${percent.toInt()}%',
                                style: TextStyle(
                                  color: isErrorMode ? Colors.orange : Colors.green,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.textSecondary.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarGroups(maxY),
                      extraLinesData: ExtraLinesData(
                        extraLinesOnTop: true,
                        horizontalLines: [],
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      'No data for the last 7 days',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
          // Accuracy line overlay using CustomPaint
          if (hasData)
            SizedBox(
              height: 0,
              child: CustomPaint(
                painter: _AccuracyLinePainter(
                  stats: stats,
                  maxY: maxY,
                  chartHeight: 120, // Approximate chart height
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(double maxY) {
    final barColor = isErrorMode ? Colors.red : AppColors.primaryBlue;
    final lineColor = isErrorMode ? Colors.orange : Colors.green;

    return List.generate(stats.length, (index) {
      final stat = stats[index];
      // In error mode: avgConfidence holds error rate
      final secondaryValue = isErrorMode ? stat.avgConfidence : stat.accuracy;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: stat.detectionCount.toDouble(),
            color: barColor,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            rodStackItems: [],
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: barColor.withOpacity(0.1),
            ),
          ),
          // Secondary metric as a thinner bar
          BarChartRodData(
            toY: secondaryValue * maxY, // Scale to same Y axis
            color: lineColor,
            width: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _shortDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for drawing accuracy line (optional overlay).
class _AccuracyLinePainter extends CustomPainter {
  _AccuracyLinePainter({
    required this.stats,
    required this.maxY,
    required this.chartHeight,
  });

  final List<DailyStats> stats;
  final double maxY;
  final double chartHeight;

  @override
  void paint(Canvas canvas, Size size) {
    // This is a placeholder - the accuracy is shown as the green bar
    // In a more complex implementation, you could draw an actual line here
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
