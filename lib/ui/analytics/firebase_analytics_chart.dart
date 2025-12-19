import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_service.dart';
import '../../core/models/detection_record.dart';

class FirebaseAnalyticsChart extends StatefulWidget {
  const FirebaseAnalyticsChart({super.key});

  @override
  State<FirebaseAnalyticsChart> createState() => _FirebaseAnalyticsChartState();
}

class _FirebaseAnalyticsChartState extends State<FirebaseAnalyticsChart> {
  Map<String, dynamic>? _analyticsData;
  Map<String, int>? _dailyCounts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    
    try {
      final analyticsData = await FirebaseService.instance.getAnalyticsData();
      final dailyCounts = await FirebaseService.instance.getDailyDetectionCounts();
      
      setState(() {
        _analyticsData = analyticsData;
        _dailyCounts = dailyCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Analytics'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analyticsData == null
              ? const Center(child: Text('No analytics data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildEquipmentCountChart(),
                      const SizedBox(height: 24),
                      _buildConfidenceChart(),
                      const SizedBox(height: 24),
                      _buildDailyTrendChart(),
                      const SizedBox(height: 24),
                      _buildRecentDetections(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final totalDetections = _analyticsData!['totalDetections'] as int;
    final accuracy = (_analyticsData!['accuracy'] as double) * 100;
    
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total Detections',
            value: totalDetections.toString(),
            icon: Icons.analytics,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Accuracy',
            value: '${accuracy.toStringAsFixed(1)}%',
            icon: Icons.check_circle,
            color: accuracy >= 70 ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentCountChart() {
    final equipmentCounts = _analyticsData!['equipmentCounts'] as Map<String, int>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Equipment Detection Counts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: equipmentCounts.values.isNotEmpty 
                      ? (equipmentCounts.values.reduce((a, b) => a > b ? a : b) * 1.2).toDouble()
                      : 10,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.grey[800]!,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final equipment = equipmentCounts.keys.elementAt(group.x.toInt());
                        return BarTooltipItem(
                          '$equipment\n${rod.toY.round()} detections',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= equipmentCounts.length) return const SizedBox();
                          final equipment = equipmentCounts.keys.elementAt(value.toInt());
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                equipment.split(' ').last,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: equipmentCounts.entries.map((entry) {
                    final index = equipmentCounts.keys.toList().indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: _getEquipmentColor(entry.key),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceChart() {
    final avgConfidence = _analyticsData!['avgConfidenceByEquipment'] as Map<String, double>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average Confidence by Equipment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.grey[800]!,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final equipment = avgConfidence.keys.elementAt(group.x.toInt());
                        return BarTooltipItem(
                          '$equipment\n${(rod.toY * 100).toStringAsFixed(1)}%',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= avgConfidence.length) return const SizedBox();
                          final equipment = avgConfidence.keys.elementAt(value.toInt());
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                equipment.split(' ').last,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: avgConfidence.entries.map((entry) {
                    final index = avgConfidence.keys.toList().indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          color: _getConfidenceColor(entry.value),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTrendChart() {
    if (_dailyCounts == null || _dailyCounts!.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No daily trend data available'),
        ),
      );
    }

    final sortedDates = _dailyCounts!.keys.toList()..sort();
    final maxCount = _dailyCounts!.values.reduce((a, b) => a > b ? a : b).toDouble();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Detection Trend (Last 30 Days)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= sortedDates.length || index % 5 != 0) return const SizedBox();
                          final dateStr = sortedDates[index];
                          final parts = dateStr.split('-');
                          return Text('${parts[1]}/${parts[2]}', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sortedDates.asMap().entries.map((entry) {
                        final count = _dailyCounts![entry.value] ?? 0;
                        return FlSpot(entry.key.toDouble(), count.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: maxCount * 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDetections() {
    final recentDetections = _analyticsData!['recentDetections'] as List<DetectionRecord>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Detections',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentDetections.length,
              itemBuilder: (context, index) {
                final detection = recentDetections[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: detection.isCorrect ? Colors.green : Colors.red,
                    child: Icon(
                      detection.isCorrect ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(detection.predictedClass),
                  subtitle: Text(
                    'Expected: ${detection.groundTruthClass}\n'
                    'Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                  ),
                  trailing: Text(
                    '${detection.timestamp.hour}:${detection.timestamp.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getEquipmentColor(String equipment) {
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.red, Colors.teal, Colors.indigo, Colors.pink,
      Colors.amber, Colors.cyan,
    ];
    final index = equipment.hashCode.abs() % colors.length;
    return colors[index];
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
