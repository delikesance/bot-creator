import 'dart:async';
import 'dart:io';

import 'package:bot_creator/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:nyxx/nyxx.dart' hide Locale;
import "routes/home.dart";
import 'package:provider/provider.dart';
import 'routes/create.dart';
import 'routes/onboarding.dart';
import 'utils/app_diagnostics.dart';
import 'utils/bot_payload_builder.dart';
import 'utils/bot.dart';
import 'utils/database.dart';
import 'utils/analytics.dart';
import 'utils/ad_consent_service.dart';
import 'utils/ad_native_service.dart';
import 'utils/ad_reward_service.dart';
import 'utils/subscription_service.dart';
import 'utils/i18n.dart';
import 'utils/onboarding_manager.dart';

@pragma('vm:entry-point')
AppManager? _appManager;

@pragma('vm:entry-point')
AppManager get appManager => _appManager ??= AppManager();

@pragma('vm:entry-point')
set appManager(AppManager value) => _appManager = value;
List<String> currentLogList = [];
@pragma('vm:entry-point')
List<NyxxGateway> gateways = [];
FirebaseApp? firebaseApp;

bool get _isFirebaseSupported {
  if (kIsWeb) {
    return true;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return false;
    default:
      return false;
  }
}

bool get _isCrashlyticsSupported {
  if (kIsWeb) {
    return false;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return false;
    default:
      return false;
  }
}

Future<void> main() async {
  HttpOverrides.global = _WindowsHttpOverrides();

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppDiagnostics.initialize();
      AppDiagnostics.installGlobalErrorHandlers();
      try {
        FlutterForegroundTask.initCommunicationPort();
        await AppDiagnostics.logInfo(
          'Foreground task communication initialized',
        );
      } catch (error, stack) {
        await AppDiagnostics.logError(
          'Foreground task communication initialization failed',
          error,
          stack,
          fatal: false,
        );
      }

      await _bootstrapAndRunApp();
    },
    (error, stack) async {
      await AppDiagnostics.logError(
        'Uncaught zone error during bootstrap/runtime',
        error,
        stack,
        fatal: true,
      );
    },
  );
}

/// Windows TLS compatibility override.
class _WindowsHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    if (Platform.isWindows) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    }
    return client;
  }
}

Future<void> _bootstrapAndRunApp() async {
  var firebaseReady = false;

  if (_isFirebaseSupported) {
    try {
      await AppDiagnostics.logInfo(
        'Initializing Firebase',
        data: {'platform': defaultTargetPlatform.name},
      );
      firebaseApp = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout:
            () =>
                throw TimeoutException(
                  'Firebase initialization timed out after 10 seconds',
                ),
      );
      if (!firebaseApp!.isAutomaticDataCollectionEnabled) {
        await firebaseApp!.setAutomaticDataCollectionEnabled(true);
      }
      firebaseReady = true;
      await AppDiagnostics.logInfo('Firebase initialized');
    } catch (error, stack) {
      await AppDiagnostics.logError(
        'Firebase initialization failed',
        error,
        stack,
        fatal: false,
      );
    }
  }

  await AppDiagnostics.configureCrashlytics(
    crashlyticsSupported: _isCrashlyticsSupported,
    firebaseReady: firebaseReady,
  );

  await AdRewardService.initialize();
  await AdNativeService.initialize();
  await SubscriptionService.initialize();
  await loadDebugReplayCapturingState();

  try {
    appManager = AppManager();
    initRunnerAutoReload();
    final prefs = await SharedPreferences.getInstance();
    final onboardingManager = OnboardingManager(prefs);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          Provider(create: (_) => onboardingManager),
        ],
        child: const MyApp(),
      ),
    );
  } catch (error, stack) {
    await AppDiagnostics.logError(
      'Fatal startup error before runApp',
      error,
      stack,
      fatal: true,
    );
    runApp(StartupFailureApp(error: error.toString()));
  }
}

/// ── Direction artistique ──────────────────────────────────────────────────
/// Palette de marque partagée par la refonte du front.
const Color kBrandPurple = Color(0xFF7C5CFF);
const Color kBrandPurpleSoft = Color(0xFF9C86FF);
const Color kDangerColor = Color(0xFFE5484D);
const Color kOnlineColor = Color(0xFF3BD671);
const Color kScaffoldDark = Color(0xFF0B0B0F);

/// Central theme factory so every screen inherits the new art direction.
class AppTheme {
  const AppTheme._();

  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: kBrandPurple,
      brightness: brightness,
    );

    final scheme =
        isDark
            ? base.copyWith(
              primary: kBrandPurple,
              secondary: kBrandPurpleSoft,
              surface: const Color(0xFF121218),
              surfaceContainerLowest: const Color(0xFF0C0C11),
              surfaceContainerLow: const Color(0xFF141419),
              surfaceContainer: const Color(0xFF17171D),
              surfaceContainerHigh: const Color(0xFF1E1E26),
              surfaceContainerHighest: const Color(0xFF262630),
              onSurface: const Color(0xFFF3F3F6),
              onSurfaceVariant: const Color(0xFF9A9AA6),
              outline: const Color(0xFF2C2C36),
              outlineVariant: const Color(0xFF22222B),
              error: kDangerColor,
            )
            : base.copyWith(primary: kBrandPurple);

    final scaffoldBg = isDark ? kScaffoldDark : scheme.surface;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kBrandPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestTrackingAndEnableAnalytics());
    });
  }

  Future<void> _requestTrackingAndEnableAnalytics() async {
    await AdConsentService.requestTrackingTransparencyIfNeeded();
    try {
      await AppAnalytics.setCollectionEnabled(true);
    } catch (error, stack) {
      unawaited(
        AppDiagnostics.logError(
          'Analytics collection setup failed',
          error,
          stack,
          fatal: false,
        ),
      );
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    AppAnalytics.logAppOpen();
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final onboardingManager = context.read<OnboardingManager>();

    return MaterialApp(
      navigatorKey: MyApp.navigatorKey,
      title: AppStrings.t('app_title'),
      locale: Locale(localeProvider.locale.code),
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home:
          onboardingManager.isFirstRun
              ? OnboardingPage(
                onComplete: () {
                  // When onboarding completes, navigate to main app.
                  // Use the app navigator key instead of outer build context.
                  final navigator = MyApp.navigatorKey.currentState;
                  if (navigator != null) {
                    navigator.pushNamedAndRemoveUntil(
                      '/home',
                      (route) => false,
                    );
                  }
                },
              )
              : MyMainPage(title: AppStrings.t('app_title')),
      routes: {
        '/home': (context) => MyMainPage(title: AppStrings.t('app_title')),
      },
    );
  }
}

class MyMainPage extends StatefulWidget {
  const MyMainPage({super.key, required this.title});
  final String title;

  @override
  State<MyMainPage> createState() => _MyMainPageState();
}

class _MyMainPageState extends State<MyMainPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SafeArea(bottom: false, child: HomePage()),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AppCreatePage()),
          );
        },
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF15151B),
        elevation: 6,
        highlightElevation: 10,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          AppStrings.t('home_create_app'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _themeMode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> resetToDefault() async {
    _themeMode = ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class StartupFailureApp extends StatefulWidget {
  const StartupFailureApp({super.key, required this.error});

  final String error;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  String _diagnostics = 'Loading diagnostics...';
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final text = await AppDiagnostics.readLog(maxLines: 200);
    if (!mounted) {
      return;
    }
    setState(() {
      _diagnostics = text;
    });
  }

  Future<void> _copyDiagnostics() async {
    setState(() {
      _copying = true;
    });
    try {
      await AppDiagnostics.copyLogToClipboard(maxLines: 300);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics copied to clipboard')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _copying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bot Creator',
      home: Scaffold(
        appBar: AppBar(title: const Text('Startup Error')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bot Creator failed to start on this device.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(widget.error),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _copying ? null : _copyDiagnostics,
                    child: const Text('Copy diagnostics'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _loadDiagnostics,
                    child: const Text('Refresh diagnostics'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(_diagnostics),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
