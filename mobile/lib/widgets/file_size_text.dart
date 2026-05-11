import 'dart:math' as math;
import 'package:intl/intl.dart';

String formatFileSize(int bytes) {
  if (bytes == 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  final i = (math.log(bytes) / math.log(1024)).floor().clamp(0, units.length - 1);
  final value = bytes / math.pow(1024, i);
  if (value % 1 == 0) return '${value.toInt()} ${units[i]}';
  return '${value.toStringAsFixed(1)} ${units[i]}';
}

String formatRelativeDate(String? iso) {
  if (iso == null || iso.isEmpty) return 'Never expires';
  final d = DateTime.parse(iso);
  final now = DateTime.now();
  final diff = d.difference(now);

  if (diff.isNegative) return 'Expired';
  if (diff.inDays > 1) return 'in ${diff.inDays} days';
  if (diff.inDays == 1) return 'in 1 day';
  if (diff.inHours > 1) return 'in ${diff.inHours} hours';
  if (diff.inHours == 1) return 'in 1 hour';
  if (diff.inMinutes > 1) return 'in ${diff.inMinutes} minutes';
  return 'in less than a minute';
}

String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return 'Never';
  final d = DateTime.parse(iso);
  return DateFormat('MMM d, yyyy HH:mm').format(d);
}
