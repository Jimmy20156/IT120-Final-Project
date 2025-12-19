import 'record_filter.dart';

/// Advanced filter options for history page.
class HistoryFilter {
  final RecordFilter verificationFilter;
  final int? classIndex; // null = all classes
  final bool? isCorrect; // null = all, true = correct only, false = incorrect only
  final String? searchQuery; // Search by team name
  final DateTime? startDate; // Date range start
  final DateTime? endDate; // Date range end

  const HistoryFilter({
    this.verificationFilter = RecordFilter.all,
    this.classIndex,
    this.isCorrect,
    this.searchQuery,
    this.startDate,
    this.endDate,
  });

  HistoryFilter copyWith({
    RecordFilter? verificationFilter,
    int? classIndex,
    bool? isCorrect,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    bool clearClassIndex = false,
    bool clearIsCorrect = false,
    bool clearSearchQuery = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return HistoryFilter(
      verificationFilter: verificationFilter ?? this.verificationFilter,
      classIndex: clearClassIndex ? null : (classIndex ?? this.classIndex),
      isCorrect: clearIsCorrect ? null : (isCorrect ?? this.isCorrect),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  /// Check if any filter is active (not default).
  bool get hasActiveFilters =>
      verificationFilter != RecordFilter.all ||
      classIndex != null ||
      isCorrect != null ||
      (searchQuery != null && searchQuery!.isNotEmpty) ||
      startDate != null ||
      endDate != null;

  /// Count of active filters.
  int get activeFilterCount {
    int count = 0;
    if (verificationFilter != RecordFilter.all) count++;
    if (classIndex != null) count++;
    if (isCorrect != null) count++;
    if (searchQuery != null && searchQuery!.isNotEmpty) count++;
    if (startDate != null || endDate != null) count++;
    return count;
  }
}
