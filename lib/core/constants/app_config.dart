abstract final class AppConfig {
  static const String supabaseUrl = 'https://mrsddrnrngyqxaclcxmn.supabase.co';

  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yc2Rkcm5ybmd5cXhhY2xjeG1uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxMTg3OTksImV4cCI6MjA5OTY5NDc5OX0.7n8p-JcFX93Sj28NshJVkLTGKc7QzaCy0mnP5QlAAOA';

  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw Exception('SUPABASE_URL not configured');
    }
    if (supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY not configured');
    }
  }
}
