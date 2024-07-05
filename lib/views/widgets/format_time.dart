import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormatTime {
  static String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 1) {
      if (dateTime.year == now.year) {
        return DateFormat('MM/dd HH:mm').format(dateTime); // Same year: month/day hour:minute
      } else {
        return DateFormat('yyyy/MM/dd').format(dateTime); // Different year: year/month/day
      }
    } else {
      if (difference.inHours >= 1) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inMinutes} minutes ago';
      }
    }
  }

  static String formatCommentTime(dynamic createdAt) {
    if (createdAt == null) {
      return 'No time info';
    }
    
    DateTime dateTime;
    if (createdAt is Timestamp) {
      dateTime = createdAt.toDate();
    } else if (createdAt is DateTime) {
      dateTime = createdAt;
    } else {
      return 'Invalid time format';
    }

    return formatTime(dateTime);
  }
}