/// جلسة Prism — الحقول اللي التطبيق محتاجها بس،
/// مش الـ 100+ حقل اللي السيرفر بيرجعهم.
class Session {
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
}
