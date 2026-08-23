import '../../domain/entities/session.dart';

class SessionModel extends Session {
  const SessionModel({
    required super.sid,
    required super.username,
    required super.employeeName,
    required super.token,
    required super.nonce,
    required super.subsidiaryName,
    required super.storeName,
    required super.currency,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
    sid: _str(json['sid']),
    username: _str(json['username']),
    employeeName: _str(json['employeename']),
    token: _str(json['token']),
    nonce: _str(json['nonce']),
    subsidiaryName: _str(json['subsidiaryname']),
    storeName: _str(json['storename']),
    currency: _str(json['basecurrencycodealpha']),
  );

  static String _str(dynamic v) => v?.toString() ?? '';


  factory SessionModel.fromResponse(dynamic data) {
    final map = switch (data) {
      final List<dynamic> l when l.isNotEmpty && l.first is Map => l.first,
      final Map<Object?, Object?> m => m,
      _ => throw const FormatException('شكل رد غير متوقع من السيرفر'),
    };
    return SessionModel.fromJson((map as Map).cast<String, dynamic>());
  }
}
