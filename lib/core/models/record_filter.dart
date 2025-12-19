/// Filter options for detection records.
enum RecordFilter {
  all('All'),
  verified('Verified'),
  notVerified('Not Verified');

  const RecordFilter(this.label);

  final String label;
}
