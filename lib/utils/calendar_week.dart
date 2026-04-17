/// Monday (local) of the week that contains [date], date-only.
DateTime mondayOfWeekContaining(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
  return DateTime(monday.year, monday.month, monday.day);
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
