import 'package:equatable/equatable.dart';

class Session extends Equatable {
  final String sid;
  final String username;
  final String employeeName;
  final String token;
  final String nonce;
  final String subsidiaryName;
  final String storeName;
  final String currency;

  const Session({
    required this.sid,
    required this.username,
    required this.employeeName,
    required this.token,
    required this.nonce,
    required this.subsidiaryName,
    required this.storeName,
    required this.currency,
  });

  @override
  List<Object?> get props => [
    sid,
    username,
    employeeName,
    token,
    nonce,
    subsidiaryName,
    storeName,
    currency,
  ];

  /// التوكن والـ nonce بيفضلوا في الـ props (عشان المساواة تبقى صح) بس
  /// **ممنوع** يظهروا في أي نص.
  ///
  /// من غير الـ override ده، `Equatable.stringify` بيطبع كل الـ props،
  /// و`TalkerBlocObserver` بيطبع كل state — يعني التوكن كان هيتكتب
  /// في اللوج مع كل لوجين ناجح.
  @override
  String toString() =>
      'Session($username, $employeeName, $subsidiaryName/$storeName, '
      'token: ***)';
}
