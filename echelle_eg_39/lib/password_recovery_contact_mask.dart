enum RecoveryContactType { email, phone }

extension RecoveryContactTypeApiValue on RecoveryContactType {
  String get apiValue => this == RecoveryContactType.email ? 'email' : 'phone';

  bool get isEmail => this == RecoveryContactType.email;
}

typedef PasswordResetCodeRequester =
    Future<Map<String, dynamic>> Function(String contact, String contactType);
typedef PasswordResetCodeVerifier =
    Future<Map<String, dynamic>> Function(String code, String contact);
typedef PasswordUpdater =
    Future<Map<String, dynamic>> Function(String newPassword);
typedef PasswordRecoveryTokenCleaner = Future<void> Function();

String maskRecoveryContact(String contact, {required bool isEmail}) {
  final value = contact.trim();
  if (isEmail) {
    final atIndex = value.lastIndexOf('@');
    if (atIndex <= 0 || atIndex == value.length - 1) return '••••••';
    final localPart = value.substring(0, atIndex);
    final domain = value.substring(atIndex + 1);
    final visibleInitial = localPart.isEmpty ? '' : localPart[0];
    return '$visibleInitial•••@$domain';
  }

  final normalized = value.replaceAll(RegExp(r'[\s().-]'), '');
  const togoPrefix = '+228';
  if (normalized.startsWith(togoPrefix)) {
    final localNumber = normalized.substring(togoPrefix.length);
    final visibleSuffix = localNumber.length > 2
        ? localNumber.substring(localNumber.length - 2)
        : localNumber;
    return '$togoPrefix •••••• $visibleSuffix';
  }

  final digits = normalized.replaceAll(RegExp(r'\D'), '');
  final visibleSuffix = digits.length > 2
      ? digits.substring(digits.length - 2)
      : digits;
  if (digits.length == 8 || digits.length == 9) {
    return '$togoPrefix •••••• $visibleSuffix';
  }
  return '•••••• $visibleSuffix';
}
