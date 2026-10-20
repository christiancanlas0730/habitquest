/// Public client configuration supplied at build/run time.
///
/// The publishable (formerly anon) key is intended for client use and must
/// always be paired with the project's row-level security policies. Never put
/// a service-role key in this app.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  final String? supabaseUrl;
  final String? supabasePublishableKey;

  bool get isConfigured =>
      supabaseUrl != null && supabasePublishableKey != null;

  factory AppConfig.fromEnvironment() {
    final url = const String.fromEnvironment('SUPABASE_URL').trim();
    final key = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY').trim();
    final validUrl = Uri.tryParse(url);
    return AppConfig(
      supabaseUrl:
          validUrl != null &&
              (validUrl.scheme == 'https' || validUrl.host == 'localhost') &&
              validUrl.host.isNotEmpty
          ? url
          : null,
      supabasePublishableKey: key.isEmpty ? null : key,
    );
  }
}
