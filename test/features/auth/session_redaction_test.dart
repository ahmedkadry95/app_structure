import 'package:app_structure/features/auth/domain/entities/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// الـ BlocObserver بيطبع كل state، و`AuthSuccess` شايلة `Session`.
/// من غير الـ toString المخصص، Equatable كان هيطبع كل الـ props —
/// وفيهم التوكن والـ nonce — مع كل لوجين ناجح.
void main() {
  const token = 'C0A8C2695C034F05AD591FC0D6915E38';
  const nonce = '941539017';

  const session = Session(
    sid: '787247435000157417',
    username: 'sysadmin',
    employeeName: 'SYSADMIN',
    token: token,
    nonce: nonce,
    subsidiaryName: 'Sofa',
    storeName: '001',
    currency: 'SAR',
  );

  test('toString مبيطبعش التوكن ولا الـ nonce', () {
    final text = session.toString();

    expect(text, isNot(contains(token)));
    expect(text, isNot(contains('C0A8C269')));
    expect(text, isNot(contains(nonce)));
    expect(text, contains('***'));
  });

  test('toString لسه بيدي معلومة مفيدة للتشخيص', () {
    final text = session.toString();

    expect(text, contains('sysadmin'));
    expect(text, contains('Sofa'));
    expect(text, contains('001'));
  });

  test('التوكن لسه في الـ props عشان المساواة تفضل صح', () {
    const other = Session(
      sid: '787247435000157417',
      username: 'sysadmin',
      employeeName: 'SYSADMIN',
      token: 'DIFFERENT_TOKEN',
      nonce: nonce,
      subsidiaryName: 'Sofa',
      storeName: '001',
      currency: 'SAR',
    );

    expect(
      session == other,
      isFalse,
      reason: 'إخفاء التوكن في العرض مالوش علاقة بالمساواة',
    );
    expect(session.props, contains(token));
  });
}
