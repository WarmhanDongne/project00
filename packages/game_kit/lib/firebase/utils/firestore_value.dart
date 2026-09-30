// [firestore_value.dart] 는 여러 게임이 함께 사용하는 Firestore에서 받은 값을 안전한 Dart 값으로 변환하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [FirestoreValue] : Firestore에서 받은 값을 안전한 Dart 값으로 변환함
//
// 즉, 누락되거나 형식이 다른 서버 데이터도 안전하게 읽기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:cloud_firestore/cloud_firestore.dart';
// ============================================================

//==========[ 날짜 변환 ]==========
//[날짜] Firestore Timestamp와 이미 변환된 DateTime을 모두 허용
DateTime? firestoreDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

//==========[ 기본 값 변환 ]==========
//[문자열] 값이 없으면 호출한 곳에서 정한 기본값 사용
String firestoreString(Object? value, {String fallback = ''}) {
  return value?.toString() ?? fallback;
}

//[정수] 숫자와 숫자로 된 문자열을 받고, 바꿀 수 없으면 기본값 사용
int firestoreInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

//[문자열목록] 배열 형태만 받아 수정할 수 없는 새 목록으로 변환
List<String> firestoreStringList(Object? value) {
  if (value is! Iterable) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}
