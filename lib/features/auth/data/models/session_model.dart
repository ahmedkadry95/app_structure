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
        sid: json['sid'] as String? ?? '',
        username: json['username'] as String? ?? '',
        employeeName: json['employeename'] as String? ?? '',
        token: json['token'] as String? ?? '',
        nonce: json['nonce'] as String? ?? '',
        subsidiaryName: json['subsidiaryname'] as String? ?? '',
        storeName: json['storename'] as String? ?? '',
        currency: json['basecurrencycodealpha'] as String? ?? '',
      );

  /// Prism بيرجع اللوجين جوه Array: `[{...session...}]`
  /// الدالة دي بتتعامل مع Array أو Object عشان أي endpoint تاني.
  factory SessionModel.fromResponse(dynamic data) {
    final map = switch (data) {
      List() when data.isNotEmpty => data.first as Map<String, dynamic>,
      Map<String, dynamic>() => data,
      _ => throw const FormatException('شكل رد غير متوقع من السيرفر'),
    };
    return SessionModel.fromJson(map);
  }
}
