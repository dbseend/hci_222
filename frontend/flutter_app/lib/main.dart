// main.dart
// Purpose: App entry point. Initializes Flutter bindings then launches TruePriceApp.
// TODO(next-dev): Add Firebase.initializeApp() and other async initialization
//                 (e.g. SharedPreferences warm-up) here before runApp() if needed.

import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/exchange_rate_service.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initializeFromDartDefine();
  await ExchangeRateService().loadEgpToKrwOnceOnAppLaunch();
  runApp(const TruePriceApp());
}
