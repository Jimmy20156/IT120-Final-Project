import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../app_theme.dart';
import '../../core/services/timeline_service.dart';
import '../../core/services/detection_storage_service.dart';
import '../../core/models/detection_record.dart';

class EquipmentTimelinePage extends StatefulWidget {
  const EquipmentTimelinePage({super.key});

  @override
  State<EquipmentTimelinePage> createState() => _EquipmentTimelinePageState();
}

class _EquipmentTimelinePageState extends State<EquipmentTimelinePage>
    with TickerProviderStateMixin {
  final _timelineService = TimelineService.instance;
  final _storageService = DetectionStorageService.instance;
  
  late TabController _viewModeController;
  TimelineViewMode _currentViewMode = TimelineViewMode.day;
  
  DateTime _focusedDate = DateTime.now();
  Set<String> _selectedEquipment = {};
  bool _showVerifiedOnly = false;
  
  @override
  void initState() {
    super.initState();
    _viewModeController = TabController(length: 4, vsync: this);
    _viewModeController.addListener(() {
      setState(() {
        switch (_viewModeController.index) {
          case 0:
            _currentViewMode = TimelineViewMode.day;
            break;
          case 1:
            _currentViewMode = TimelineViewMode.week;
            break;
          case 2:
            _currentViewMode = TimelineViewMode.month;
            break;
          case 3:
            _currentViewMode = TimelineViewMode.year;
            break;
        }
        _timelineService.setViewMode(_currentViewMode);
      });
    });
    
    // Listen for data changes
    DetectionStorageService.instance.dataChanges.listen((_) {
      if (mounted) {
        _refreshData();
      }
    });
    
    _loadData();
  }

  @override
  void didUpdateWidget(EquipmentTimelinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshData();
  }

  Future<void> _refreshData() async {
    // Reload storage data
    await _storageService.loadRecords();
    // Update timeline service data
    final records = _storageService.records;
    _timelineService.updateRecords(records);
    setState(() {});
  }

  @override
  void dispose() {
    _viewModeController.dispose();
    super.dispose();
  }

  void _loadData() {
    final records = _storageService.records;
    _timelineService.addRecords(records);
    _timelineService.focusOnDate(_focusedDate);
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
          'Equipment Timeline',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filters',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportTimeline,
            tooltip: 'Export',
          ),
        ],
        bottom: TabBar(
          controller: _viewModeController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Day'),
            Tab(text: 'Week'),
            Tab(text: 'Month'),
            Tab(text: 'Year'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDateNavigator(),
          _buildTimelineStats(),
          Expanded(
            child: _buildTimelineContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateNavigator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: _navigatePrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _showDatePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatFocusedDate(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _navigateNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStats() {
    final stats = _timelineService.getTimelineStats();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withOpacity(0.1),
            AppColors.primaryBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Events', stats.totalEvents.toString(), Icons.event),
          _buildStatItem('Detections', stats.totalDetections.toString(), Icons.camera_alt),
          _buildStatItem('Equipment', stats.uniqueEquipment.toString(), Icons.agriculture),
          _buildStatItem('Accuracy', '${(stats.avgConfidence * 100).round()}%', Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineContent() {
    final events = _timelineService.timelineEvents;
    
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              color: AppColors.primaryBlue,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No detection history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start scanning equipment to see your timeline',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildTimelineEvent(event, index == events.length - 1);
      },
    );
  }

  Widget _buildTimelineEvent(TimelineEvent event, bool isLast) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line and dot
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 80,
                    color: AppColors.primaryBlue.withOpacity(0.3),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            
            // Event content
            Expanded(
              child: Container(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatEventPeriod(event.period),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${event.eventCount} detections',
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
                        _buildEventMetric('Equipment', '${event.uniqueEquipment} types'),
                        const SizedBox(width: 16),
                        _buildEventMetric('Avg Confidence', '${(event.avgConfidence * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (event.records.isNotEmpty)
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: event.records.length.clamp(0, 5),
                          itemBuilder: (context, index) {
                            final record = event.records[index];
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: record.isVerified 
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    record.predictedClass,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${(record.confidence * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _showEventDetails(event),
                          child: const Text('View Details'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEventMetric(String label, String value) {
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

  String _formatFocusedDate() {
    switch (_currentViewMode) {
      case TimelineViewMode.day:
        return DateFormat('MMM dd, yyyy').format(_focusedDate);
      case TimelineViewMode.week:
        final weekStart = _getWeekStart(_focusedDate);
        final weekEnd = weekStart.add(const Duration(days: 6));
        return '${DateFormat('MMM dd').format(weekStart)} - ${DateFormat('MMM dd, yyyy').format(weekEnd)}';
      case TimelineViewMode.month:
        return DateFormat('MMMM yyyy').format(_focusedDate);
      case TimelineViewMode.year:
        return DateFormat('yyyy').format(_focusedDate);
    }
  }

  String _formatEventPeriod(DateTime period) {
    switch (_currentViewMode) {
      case TimelineViewMode.day:
        return DateFormat('EEEE, MMM dd').format(period);
      case TimelineViewMode.week:
        return 'Week of ${DateFormat('MMM dd').format(period)}';
      case TimelineViewMode.month:
        return DateFormat('MMMM').format(period);
      case TimelineViewMode.year:
        return DateFormat('yyyy').format(period);
    }
  }

  DateTime _getWeekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  void _navigatePrevious() {
    setState(() {
      switch (_currentViewMode) {
        case TimelineViewMode.day:
          _focusedDate = _focusedDate.subtract(const Duration(days: 1));
          break;
        case TimelineViewMode.week:
          _focusedDate = _focusedDate.subtract(const Duration(days: 7));
          break;
        case TimelineViewMode.month:
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
          break;
        case TimelineViewMode.year:
          _focusedDate = DateTime(_focusedDate.year - 1, 1, 1);
          break;
      }
      _timelineService.focusOnDate(_focusedDate);
    });
  }

  void _navigateNext() {
    setState(() {
      switch (_currentViewMode) {
        case TimelineViewMode.day:
          _focusedDate = _focusedDate.add(const Duration(days: 1));
          break;
        case TimelineViewMode.week:
          _focusedDate = _focusedDate.add(const Duration(days: 7));
          break;
        case TimelineViewMode.month:
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
          break;
        case TimelineViewMode.year:
          _focusedDate = DateTime(_focusedDate.year + 1, 1, 1);
          break;
      }
      _timelineService.focusOnDate(_focusedDate);
    });
  }

  void _showDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _focusedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null) {
        setState(() {
          _focusedDate = date;
          _timelineService.focusOnDate(_focusedDate);
        });
      }
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timeline Filters'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Equipment Filters'),
                const SizedBox(height: 8),
                // Add equipment filter checkboxes here
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Show Verified Only'),
                  value: _showVerifiedOnly,
                  onChanged: (value) {
                    setDialogState(() {
                      _showVerifiedOnly = value ?? false;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _timelineService.toggleVerifiedOnly();
              });
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(TimelineEvent event) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Event Details',
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
              Expanded(
                child: ListView.builder(
                  itemCount: event.records.length,
                  itemBuilder: (context, index) {
                    final record = event.records[index];
                    return ListTile(
                      leading: Icon(
                        record.isVerified ? Icons.verified : Icons.camera_alt,
                        color: record.isVerified ? Colors.green : AppColors.primaryBlue,
                      ),
                      title: Text(record.predictedClass),
                      subtitle: Text(
                        '${DateFormat('HH:mm').format(record.timestamp)} - ${(record.confidence * 100).round()}% confidence',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showRecordDetails(record),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordDetails(DetectionRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.predictedClass),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Time', DateFormat('HH:mm:ss').format(record.timestamp)),
            _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(record.timestamp)),
            _buildDetailRow('Confidence', '${(record.confidence * 100).round()}%'),
            _buildDetailRow('Verified', record.isVerified ? 'Yes' : 'No'),
            _buildDetailRow('Correct', record.isCorrect ? 'Yes' : 'No'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _exportTimeline() {
    final data = _timelineService.exportTimelineData();
    // Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timeline exported successfully')),
    );
  }
}
