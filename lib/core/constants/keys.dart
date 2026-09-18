/// MAVIO API Keys Configuration
///
/// All secrets are loaded from build-time environment variables via
/// `--dart-define` or `--dart-define-from-file=.env`.
///
/// Build command example:
/// ```
/// flutter run --dart-define-from-file=.env
/// ```
class SupabaseKeys {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vknnbpjulrywcoipuvid.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_usbWTrXeiD8b-_9XP4Ialw_aL2TJUOG',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

class OneSignalKeys {
  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '2633169a-2c5f-4856-bfd3-12361105dc17',
  );

  static const String restApiKey = String.fromEnvironment(
    'ONESIGNAL_REST_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => appId.isNotEmpty && restApiKey.isNotEmpty;
}
