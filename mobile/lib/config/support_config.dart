class SupportConfig {
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'campusmart2@gmail.com',
  );
  static const String businessEmail = String.fromEnvironment(
    'SUPPORT_BUSINESS_EMAIL',
    defaultValue: supportEmail,
  );
  static const String whatsappNumber = String.fromEnvironment(
    'SUPPORT_WHATSAPP_NUMBER',
    defaultValue: '',
  );

  static String? get whatsappLink {
    final normalized = whatsappNumber.replaceAll(RegExp(r'\\D'), '');
    if (normalized.isEmpty) return null;
    return 'https://wa.me/$normalized';
  }

  static const String responseWindow = 'Usually within 24 business hours';
}
