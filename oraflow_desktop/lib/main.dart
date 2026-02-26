import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/dashboard.dart';
import 'services/config_service.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for custom window behavior
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hide the standard Windows title bar
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Migrate any plaintext config key into secure storage and preload API key
  try {
    await ConfigService.migrateFileKeyIntoSecureStorage();
  } catch (e) {
    // ignore migration errors
  }

  // Ensure AiService has loaded the API key before UI starts
  try {
    await AiService.instance.ensureApiKeyLoaded();
  } catch (e) {
    // ignore
  }

  runApp(const OraFlowApp());
}

class OraFlowApp extends StatelessWidget {
  const OraFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OraFlow',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        cardColor: const Color(0xFF1a1d23),
      ),
      home: const Dashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}
