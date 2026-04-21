// main.dart
// Purpose: App entry point. Initializes Flutter bindings then launches TruePriceApp.
// TODO(next-dev): Add Firebase.initializeApp() and other async initialization
//                 (e.g. SharedPreferences warm-up) here before runApp() if needed.

import 'package:flutter/material.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TruePriceApp());
}
