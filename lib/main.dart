// main.dart - Minimal Bootstrap
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'services/storage_service.dart';
import 'viewmodels/app_lock_viewmodel.dart';
import 'viewmodels/mail_sync_viewmodel.dart';
import 'viewmodels/theme_viewmodel.dart';
import 'viewmodels/transaction_viewmodel.dart';
import 'views/home/home_screen.dart';
import 'views/lock/lock_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'views/loading_screen.dart';
import 'views/widgets/theme_switcher.dart';
import 'views/onboarding/onboarding_screen.dart';
import 'views/lock/decryption_screen.dart';
import 'services/cloud_backup_service.dart';
import 'services/crypto_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  await StorageService().init();
  await CryptoService().loadKeyFromSecureStorage();
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Theme management
        ChangeNotifierProvider(create: (_) => ThemeViewModel()..loadTheme()),
        // Transaction business logic
        ChangeNotifierProvider(
          create: (_) => TransactionViewModel()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => AppLockViewModel()..initialize()),
        ChangeNotifierProvider(create: (_) => CloudBackupService()),
        ChangeNotifierProvider(create: (_) => MailSyncViewModel()),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeVm, _) {
          return ThemeSwitcherWrapper(
            initialThemeMode: themeVm.themeMode,
            animationDuration: const Duration(seconds: 1, milliseconds: 500),
            animationCurve: Curves.easeInOut,
            builder: (context, themeMode) {
              return MaterialApp(
                title: 'X-pense',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: themeVm.themeMode,
                scrollBehavior: const _FluidScrollBehavior(),
                themeAnimationDuration: Duration.zero,
                builder: (context, child) {
                  final mediaQuery = MediaQuery.of(context);
                  final systemScale = mediaQuery.textScaler.scale(1.0);
                  final shortestSide = mediaQuery.size.shortestSide;

                  double deviceFactor;
                  if (shortestSide < 360) {
                    deviceFactor = 0.90;
                  } else if (shortestSide < 400) {
                    deviceFactor = 0.95;
                  } else if (shortestSide > 720) {
                    deviceFactor = 1.08;
                  } else {
                    deviceFactor = 1.0;
                  }

                  final adaptiveScaler = TextScaler.linear(
                    (systemScale * deviceFactor).clamp(0.85, 1.20),
                  );

                  return MediaQuery(
                    data: mediaQuery.copyWith(textScaler: adaptiveScaler),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: const _InitialRouteHandler(),
              );
            },
          );
        },
      ),
    );
  }
}

/// Route handler that shows loading screen or home based on initialization
class _InitialRouteHandler extends StatefulWidget {
  const _InitialRouteHandler({Key? key}) : super(key: key);

  @override
  State<_InitialRouteHandler> createState() => _InitialRouteHandlerState();
}

class _InitialRouteHandlerState extends State<_InitialRouteHandler>
    with WidgetsBindingObserver {
  bool _minimumSplashElapsed = false;
  bool _hasShownInitialContent = false;
  bool _isOnboardingComplete = true; // Assume true until checked
  bool _hasCheckedOnboarding = false;
  AppLifecycleState? _lastState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TransactionViewModel>().forceMaskBalance();
    });

    _checkOnboardingStatus();

    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) {
        setState(() => _minimumSplashElapsed = true);
      }
    });
  }

  Future<void> _checkOnboardingStatus() async {
    final hasCompleted = await StorageService().hasCompletedOnboarding();
    if (mounted) {
      setState(() {
        _isOnboardingComplete = hasCompleted;
        _hasCheckedOnboarding = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only lock when transitioning from resumed to detached (truly backgrounded)
    // Ignore paused/inactive states as they're triggered by system dialogs,
    // notification drawer, recents view, etc.
    if (_lastState == AppLifecycleState.resumed &&
        state == AppLifecycleState.detached) {
      if (!mounted) return;
      context.read<TransactionViewModel>().forceMaskBalance();
      context.read<AppLockViewModel>().lockApp();
    }
    _lastState = state;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionViewModel>();
    final lockVm = context.watch<AppLockViewModel>();

    final shouldShowStartupSplash =
        !_hasShownInitialContent &&
        (vm.isLoading || lockVm.isInitializing || !_minimumSplashElapsed || !_hasCheckedOnboarding);

    if (shouldShowStartupSplash) {
      return const LoadingScreen();
    }

    if (!_hasShownInitialContent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasShownInitialContent) {
          setState(() => _hasShownInitialContent = true);
        }
      });
    }

    if (!_isOnboardingComplete) {
      return const OnboardingScreen();
    }

    if (lockVm.shouldRequireLock && lockVm.isLocked) {
      return const LockScreen();
    }

    if (vm.needsDecryptionKey) {
      return const DecryptionScreen();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: const HomeScreen(),
    );
  }
}

class _FluidScrollBehavior extends MaterialScrollBehavior {
  const _FluidScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
