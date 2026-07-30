import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[MAIN] Supabase initializing...');
  await SupabaseService.initialize();
  debugPrint('[MAIN] Supabase initialized OK');
  debugPrint('[MAIN] Supabase URL: ${Supabase.instance.client.rest.url}');

  runApp(
    const ProviderScope(
      child: CJApp(),
    ),
  );
}
