import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? firestoreDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String firestoreString(Object? value, {String fallback = ''}) {
  return value?.toString() ?? fallback;
}

int firestoreInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> firestoreStringList(Object? value) {
  if (value is! Iterable) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}
