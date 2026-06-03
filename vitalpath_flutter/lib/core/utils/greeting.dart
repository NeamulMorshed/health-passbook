/// Time-of-day greeting, consistent across all portals.
String greetingForHour([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h >= 5 && h < 12) return 'Good Morning';
  if (h >= 12 && h < 17) return 'Good Afternoon';
  if (h >= 17 && h < 23) return 'Good Evening';
  return 'Good Night';
}
