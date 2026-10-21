const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// When something was saved, by calendar day: "Today", "Yesterday",
/// "Oct 14", or "Oct 14, 2025" for another year.
String savedOn(DateTime time, {DateTime? now}) {
  final t = time.toLocal();
  final n = (now ?? DateTime.now()).toLocal();
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(n.year, n.month, n.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  final date = '${_months[t.month - 1]} ${t.day}';
  return t.year == n.year ? date : '$date, ${t.year}';
}
