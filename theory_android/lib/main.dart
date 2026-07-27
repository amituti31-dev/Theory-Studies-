import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/exam_screen.dart';
import 'screens/home_screen.dart';
import 'screens/license_screen.dart';
import 'services/edge_tts_service.dart';
import 'services/local_stt_service.dart';
import 'services/question_service.dart';
import 'services/voice_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuestionService.load();
  VoiceService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const TheoryApp(),
    ),
  );
}

class TheoryApp extends StatefulWidget {
  const TheoryApp({super.key});

  @override
  State<TheoryApp> createState() => _TheoryAppState();
}

class _TheoryAppState extends State<TheoryApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        LocalSttService.shutdown();
        EdgeTtsService.shutdown();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppProvider>().themeMode;
    return MaterialApp(
      title: 'Theory Studies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('he', 'IL'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const LicenseScreen(),
        '/home': (ctx) => const HomeScreen(),
        '/exam': (ctx) => const ExamScreen(),
      },
    );
  }
}
