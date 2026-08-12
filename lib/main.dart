import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sem isso, o Flutter Web usa rotas com "#" (ex: /#/dashboard) — e esse
  // mesmo "#" é onde o Supabase coloca o token do link de redefinição de
  // senha (#access_token=...&type=recovery). Os dois brigam pelo mesmo
  // pedaço da URL, e o roteador do Flutter "engolia" o token como se
  // fosse um nome de rota inválido antes do Supabase conseguir lê-lo —
  // por isso o link caía direto na tela de login em vez da de redefinir
  // senha. Trocando pra rota baseada em path (sem "#"), o "#" da URL fica
  // livre só pro Supabase usar.
  usePathUrlStrategy();

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
