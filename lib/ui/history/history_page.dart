import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';
import '../../core/models/detection_record.dart';
import '../../core/models/history_filter.dart';
import '../../core/models/record_filter.dart';
import '../../core/services/detection_storage_service.dart';
import '../detection/detection_result_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryFilter _filter = const HistoryFilter();
  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = DetectionStorageService.instance;
    final records = storage.getAdvancedFilteredRecords(
      verificationFilter: _filter.verificationFilter,
      classIndex: _filter.classIndex,
      isCorrect: _filter.isCorrect,
      searchQuery: _filter.searchQuery,
      startDate: _filter.startDate,
      endDate: _filter.endDate,
    );
    final totalRecords = storage.records.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              if (_isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                  },
                ),
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ] else ...[
                const Text(
                  'Detection History',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              const Spacer(),
              if (_isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              ] else ...[
                // Export button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: _handleMenuAction,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'export_json',
                      child: Row(
                        children: [
                          Icon(Icons.code, size: 20),
                          SizedBox(width: 8),
                          Text('Export as JSON'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export_csv',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart, size: 20),
                          SizedBox(width: 8),
                          Text('Export as CSV'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'select',
                      child: Row(
                        children: [
                          Icon(Icons.checklist, size: 20),
                          SizedBox(width: 8),
                          Text('Select items'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Clear all', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                // Filter button
                _FilterButton(
                  filter: _filter,
                  onFilterChanged: (newFilter) {
                    setState(() => _filter = newFilter);
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by team name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _filter = _filter.copyWith(clearSearchQuery: true);
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _filter = _filter.copyWith(searchQuery: value);
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            _filter.hasActiveFilters
                ? '${records.length} of $totalRecords records'
                : '$totalRecords detection${totalRecords == 1 ? '' : 's'} recorded',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          // Active filter chips
          if (_filter.hasActiveFilters) ...[  
            const SizedBox(height: 8),
            _ActiveFilterChips(
              filter: _filter,
              onFilterChanged: (newFilter) {
                setState(() => _filter = newFilter);
              },
            ),
          ],
          const SizedBox(height: 12),
          if (records.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No detections yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Go to Detect tab to start scanning equipment',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final record = records[index];
                  return _buildRecordCard(context, record);
                },
              ),
            ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    final storage = DetectionStorageService.instance;
    switch (action) {
      case 'export_json':
        final json = storage.exportToJson(filter: _filter.verificationFilter);
        Clipboard.setData(ClipboardData(text: json));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON copied to clipboard')),
        );
        break;
      case 'export_csv':
        final csv = storage.exportToCsv(filter: _filter.verificationFilter);
        Clipboard.setData(ClipboardData(text: csv));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied to clipboard')),
        );
        break;
      case 'select':
        setState(() => _isSelectionMode = true);
        break;
      case 'clear_all':
        _showClearAllDialog();
        break;
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Records'),
        content: const Text(
          'Are you sure you want to delete all detection records? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DetectionStorageService.instance.clearAllRecords();
              if (mounted) setState(() {});
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} record(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DetectionStorageService.instance.deleteRecords(_selectedIds.toList());
              if (mounted) {
                setState(() {
                  _selectedIds.clear();
                  _isSelectionMode = false;
                });
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, DetectionRecord record) {
    final isCorrect = record.isCorrect;
    final colorIndex = record.predictedIndex % AppColors.classColors.length;
    final accentColor = AppColors.classColors[colorIndex];
    final isSelected = _selectedIds.contains(record.id);

    return GestureDetector(
      onTap: () async {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(record.id);
            } else {
              _selectedIds.add(record.id);
            }
          });
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetectionResultPage(
              detectedClassName: record.predictedClass,
              confidence: record.confidence * 100,
              scores: record.scores,
              recordId: record.id,
            ),
          ),
        );
        // Refresh the list when returning (in case verification status changed)
        if (mounted) setState(() {});
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedIds.add(record.id);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryBlue.withOpacity(0.1) 
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: AppColors.primaryBlue, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Selection checkbox or Color indicator
            if (_isSelectionMode)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.primaryBlue 
                      : accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.sports_basketball,
                  color: isSelected ? Colors.white : accentColor,
                  size: 24,
                ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.sports_basketball,
                  color: accentColor,
                  size: 24,
                ),
              ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.predictedClass,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (record.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 10,
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
                  Row(
                    children: [
                      Text(
                        'Selected: ${record.groundTruthClass}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isCorrect ? Icons.check : Icons.close,
                        size: 14,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${(record.confidence * 100).toStringAsFixed(1)}% confidence',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimestamp(record.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }
}

/// Filter button that opens a bottom sheet with filter options.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.filter,
    required this.onFilterChanged,
  });

  final HistoryFilter filter;
  final ValueChanged<HistoryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: () => _showFilterSheet(context),
          icon: const Icon(Icons.filter_list),
          color: filter.hasActiveFilters
              ? AppColors.primaryBlue
              : AppColors.textSecondary,
        ),
        if (filter.hasActiveFilters)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${filter.activeFilterCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        filter: filter,
        onFilterChanged: onFilterChanged,
      ),
    );
  }
}

/// Bottom sheet with filter options.
class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({
    required this.filter,
    required this.onFilterChanged,
  });

  final HistoryFilter filter;
  final ValueChanged<HistoryFilter> onFilterChanged;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late HistoryFilter _tempFilter;

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Filter History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _tempFilter = const HistoryFilter();
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Verification filter
          const Text(
            'Verification Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: RecordFilter.values.map((f) {
              final isSelected = _tempFilter.verificationFilter == f;
              return ChoiceChip(
                label: Text(f.label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _tempFilter = _tempFilter.copyWith(verificationFilter: f);
                  });
                },
                selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Correct/incorrect filter
          const Text(
            'Result',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _tempFilter.isCorrect == null,
                onSelected: (selected) {
                  setState(() {
                    _tempFilter = _tempFilter.copyWith(clearIsCorrect: true);
                  });
                },
                selectedColor: AppColors.primaryBlue.withOpacity(0.2),
              ),
              ChoiceChip(
                label: const Text('Correct'),
                selected: _tempFilter.isCorrect == true,
                onSelected: (selected) {
                  setState(() {
                    _tempFilter = _tempFilter.copyWith(isCorrect: true);
                  });
                },
                selectedColor: Colors.green.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _tempFilter.isCorrect == true
                      ? Colors.green
                      : AppColors.textPrimary,
                ),
              ),
              ChoiceChip(
                label: const Text('Incorrect'),
                selected: _tempFilter.isCorrect == false,
                onSelected: (selected) {
                  setState(() {
                    _tempFilter = _tempFilter.copyWith(isCorrect: false);
                  });
                },
                selectedColor: Colors.red.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _tempFilter.isCorrect == false
                      ? Colors.red
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Class filter
          const Text(
            'Team/Class',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppColors.classNames.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _tempFilter.classIndex == null;
                  return ChoiceChip(
                    label: const Text('All'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _tempFilter = _tempFilter.copyWith(clearClassIndex: true);
                      });
                    },
                    selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                  );
                }
                final classIndex = index - 1;
                final isSelected = _tempFilter.classIndex == classIndex;
                return ChoiceChip(
                  label: Text(AppColors.classNames[classIndex]),
                  selected: isSelected,
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.classColors[classIndex],
                    radius: 8,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _tempFilter = _tempFilter.copyWith(classIndex: classIndex);
                    });
                  },
                  selectedColor: AppColors.classColors[classIndex].withOpacity(0.2),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Date range filter
          const Text(
            'Date Range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(isStart: true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _tempFilter.startDate != null
                        ? _formatDate(_tempFilter.startDate!)
                        : 'Start Date',
                    style: TextStyle(
                      color: _tempFilter.startDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(isStart: false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _tempFilter.endDate != null
                        ? _formatDate(_tempFilter.endDate!)
                        : 'End Date',
                    style: TextStyle(
                      color: _tempFilter.endDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onFilterChanged(_tempFilter);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart 
          ? (_tempFilter.startDate ?? now)
          : (_tempFilter.endDate ?? now),
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _tempFilter = _tempFilter.copyWith(startDate: picked);
        } else {
          _tempFilter = _tempFilter.copyWith(endDate: picked);
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Shows active filter chips that can be tapped to remove.
class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.filter,
    required this.onFilterChanged,
  });

  final HistoryFilter filter;
  final ValueChanged<HistoryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (filter.verificationFilter != RecordFilter.all)
          _buildChip(
            label: filter.verificationFilter.label,
            color: filter.verificationFilter == RecordFilter.verified
                ? Colors.green
                : Colors.orange,
            onRemove: () {
              onFilterChanged(
                filter.copyWith(verificationFilter: RecordFilter.all),
              );
            },
          ),
        if (filter.isCorrect != null)
          _buildChip(
            label: filter.isCorrect! ? 'Correct' : 'Incorrect',
            color: filter.isCorrect! ? Colors.green : Colors.red,
            onRemove: () {
              onFilterChanged(filter.copyWith(clearIsCorrect: true));
            },
          ),
        if (filter.classIndex != null)
          _buildChip(
            label: AppColors.classNames[filter.classIndex!],
            color: AppColors.classColors[filter.classIndex!],
            onRemove: () {
              onFilterChanged(filter.copyWith(clearClassIndex: true));
            },
          ),
        if (filter.startDate != null || filter.endDate != null)
          _buildChip(
            label: _formatDateRange(filter.startDate, filter.endDate),
            color: AppColors.primaryBlue,
            onRemove: () {
              onFilterChanged(filter.copyWith(
                clearStartDate: true,
                clearEndDate: true,
              ));
            },
          ),
      ],
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      return '${start.month}/${start.day} - ${end.month}/${end.day}';
    } else if (start != null) {
      return 'From ${start.month}/${start.day}';
    } else if (end != null) {
      return 'Until ${end.month}/${end.day}';
    }
    return '';
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
