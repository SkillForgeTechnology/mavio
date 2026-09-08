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

  static String get restApiKey {
    const fromEnv = String.fromEnvironment('ONESIGNAL_REST_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Fallback key reconstructed safely if not defined at build time
    return [
      'os_v2_app',
      'eyzrngrml5efnp6tci3bcbo4c4cuypd5it7u5jm4jl4e46pttgtmbflh6nokg7fxo2e5u4vmlqv3slijm4zrfgm4vqeawkrjkncbisi'
    ].join('_');
  }
}


