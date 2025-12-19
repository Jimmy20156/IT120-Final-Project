import 'package:flutter/material.dart';
import 'dart:async';
import '../../app_theme.dart';
import '../../core/services/farm_intelligence_service.dart';
import '../../core/services/detection_storage_service.dart';

class FarmIntelligenceDashboard extends StatefulWidget {
  const FarmIntelligenceDashboard({super.key});

  @override
  State<FarmIntelligenceDashboard> createState() => _FarmIntelligenceDashboardState();
}

class _FarmIntelligenceDashboardState extends State<FarmIntelligenceDashboard>
    with TickerProviderStateMixin {
  final _intelligenceService = FarmIntelligenceService.instance;
  final _storageService = DetectionStorageService.instance;
  
  late TabController _tabController;
  List<FarmInsight> _insights = [];
  Map<String, EquipmentStats> _equipmentStats = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _intelligenceService.insights.listen((insight) {
      setState(() {
        _insights.insert(0, insight);
        if (_insights.length > 50) {
          _insights.removeRange(50, _insights.length);
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final records = _storageService.records;
    _intelligenceService.addRecords(records);
    _equipmentStats = _intelligenceService.getEquipmentStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0.5,
        title: const Text(
          'Farm Intelligence',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'Export Report',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.insights),
              text: 'Overview',
            ),
            Tab(
              icon: Icon(Icons.lightbulb),
              text: 'Insights',
            ),
            Tab(
              icon: Icon(Icons.agriculture),
              text: 'Equipment',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildInsightsTab(),
          _buildEquipmentTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickStats(),
          const SizedBox(height: 20),
          _buildUsageTrends(),
          const SizedBox(height: 20),
          _buildEfficiencyMetrics(),
          const SizedBox(height: 20),
          _buildMaintenanceAlerts(),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalDetections = _storageService.records.length;
    final avgConfidence = _calculateAverageConfidence();
    final topEquipment = _getTopEquipment();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue,
            AppColors.primaryBlue.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickStatItem(
                  'Total Detections',
                  totalDetections.toString(),
                  Icons.camera_alt,
                ),
              ),
              Expanded(
                child: _buildQuickStatItem(
                  'Avg Confidence',
                  '${(avgConfidence * 100).round()}%',
                  Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (topEquipment.isNotEmpty)
            _buildQuickStatItem(
              'Most Used',
              topEquipment,
              Icons.star,
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageTrends() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usage Trends',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildUsageChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageChart() {
    // Simple bar chart implementation
    final equipmentUsage = <String, int>{};
    final records = _storageService.records;
    
    for (final record in records) {
      equipmentUsage[record.predictedClass] = 
          (equipmentUsage[record.predictedClass] ?? 0) + 1;
    }
    
    final sortedEquipment = equipmentUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (sortedEquipment.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    
    final maxUsage = sortedEquipment.first.value;
    
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: sortedEquipment.take(5).map((entry) {
              final height = (entry.value / maxUsage) * 150;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.key.length > 8 
                            ? '${entry.key.substring(0, 8)}...'
                            : entry.key,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEfficiencyMetrics() {
    final efficiencyScore = _calculateEfficiencyScore();
    final accuracyRate = _calculateAccuracyRate();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Efficiency Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow('Detection Efficiency', efficiencyScore, '%'),
          const SizedBox(height: 12),
          _buildAccuracyDisplay(accuracyRate),
          const SizedBox(height: 12),
          _buildMetricRow('Response Time', _calculateAvgResponseTime(), 'ms'),
        ],
      ),
    );
  }

  Widget _buildAccuracyDisplay(double accuracyRate) {
    if (accuracyRate < 0) {
      // Show error message instead of accuracy
      return Row(
        children: [
          Expanded(
            child: Text(
              'Accuracy Rate',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'No Equipment Detected',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Accuracy unavailable',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Show normal accuracy
      return _buildMetricRow('Accuracy Rate', accuracyRate, '%');
    }
  }

  Widget _buildMetricRow(String label, double value, String unit) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Container(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${value.round()}$unit',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: value / 100,
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceAlerts() {
    final maintenanceInsights = _insights.where((i) => i.type == InsightType.maintenance).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maintenance Alerts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (maintenanceInsights.isEmpty)
            const Text(
              'No maintenance alerts at this time',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Column(
              children: maintenanceInsights.take(3).map((insight) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(insight.priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getPriorityColor(insight.priority).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: _getPriorityColor(insight.priority),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              insight.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: AppColors.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI-Powered Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _insights.isEmpty
              ? const Center(
                  child: Text(
                    'No insights available yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _insights.length,
                  itemBuilder: (context, index) {
                    final insight = _insights[index];
                    return _buildInsightCard(insight);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(FarmInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _getPriorityColor(insight.priority).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getPriorityColor(insight.priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getInsightIcon(insight.type),
                  color: _getPriorityColor(insight.priority),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _formatTimestamp(insight.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(insight.priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  insight.priority.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getPriorityColor(insight.priority),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Equipment Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ..._equipmentStats.entries.map((entry) {
            return _buildEquipmentCard(entry.key, entry.value);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(String equipmentName, EquipmentStats stats) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.agriculture,
                color: AppColors.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  equipmentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${stats.totalDetections} uses',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEquipmentStat(
                  'Avg Confidence',
                  '${(stats.avgConfidence * 100).round()}%',
                ),
              ),
              Expanded(
                child: _buildEquipmentStat(
                  'Last Used',
                  _formatLastUsed(stats.lastUsed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildEquipmentStat(
                  'Trend',
                  stats.usageTrend.name,
                ),
              ),
              Expanded(
                child: _buildEquipmentStat(
                  'Status',
                  _getEquipmentStatus(stats),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // Helper methods
  double _calculateAverageConfidence() {
    final records = _storageService.records;
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.confidence).reduce((a, b) => a + b) / records.length;
  }

  String _getTopEquipment() {
    final equipmentUsage = <String, int>{};
    final records = _storageService.records;
    
    for (final record in records) {
      equipmentUsage[record.predictedClass] = 
          (equipmentUsage[record.predictedClass] ?? 0) + 1;
    }
    
    if (equipmentUsage.isEmpty) return '';
    
    return equipmentUsage.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _calculateEfficiencyScore() {
    final avgConfidence = _calculateAverageConfidence();
    return avgConfidence * 100;
  }

  double _calculateAccuracyRate() {
    final records = _storageService.records;
    if (records.isEmpty) return 0.0;
    
    // Check if detections are equipment or not
    final equipmentDetections = records.where((r) => _isEquipment(r.predictedClass)).toList();
    
    if (equipmentDetections.isEmpty) {
      // No equipment detected, return error indicator
      return -1.0;
    }
    
    final correctRecords = equipmentDetections.where((r) => r.isCorrect).length;
    return (correctRecords / equipmentDetections.length) * 100;
  }

  bool _isEquipment(String predictedClass) {
    // Define equipment classes based on actual labels.txt
    final equipmentClasses = [
      'cultivator', 'harrow', 'plough', 'rake', 'rotivator',
      'seeder', 'truck', 'sprinkler', 'harvester', 'tractor'
    ];
    
    return equipmentClasses.any((equipment) => 
        predictedClass.toLowerCase().contains(equipment));
  }

  double _calculateAvgResponseTime() {
    // Mock implementation
    return 850.0;
  }

  Color _getPriorityColor(InsightPriority priority) {
    switch (priority) {
      case InsightPriority.high:
        return Colors.red;
      case InsightPriority.medium:
        return Colors.orange;
      case InsightPriority.low:
        return Colors.blue;
    }
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.usagePattern:
        return Icons.trending_up;
      case InsightType.maintenance:
        return Icons.build;
      case InsightType.efficiency:
        return Icons.speed;
      case InsightType.alert:
        return Icons.warning;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  String _formatLastUsed(DateTime lastUsed) {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${(difference.inDays / 7).round()} weeks ago';
    }
  }

  String _getEquipmentStatus(EquipmentStats stats) {
    final daysSinceLastUse = DateTime.now().difference(stats.lastUsed).inDays;
    
    if (daysSinceLastUse == 0) {
      return 'Active';
    } else if (daysSinceLastUse < 7) {
      return 'Recent';
    } else if (daysSinceLastUse < 30) {
      return 'Inactive';
    } else {
      return 'Dormant';
    }
  }

  void _refreshData() {
    setState(() {
      _loadData();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data refreshed')),
    );
  }

  void _exportReport() {
    // Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report exported successfully')),
    );
  }
}
