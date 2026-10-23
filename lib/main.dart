import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/clipboard_security_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/floating_nav_dock.dart';
import 'features/auth/presentation/login_sign_up_screen.dart';
import 'features/auth/presentation/providers/auth_session_provider.dart';
import 'features/vault/presentation/passwords_vault_screen.dart';
import 'features/vault/presentation/password_generator_screen.dart';
import 'features/wallet/presentation/digital_wallet_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/settings/presentation/providers/auto_lock_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: VaultXApp()));
}

class VaultXApp extends ConsumerWidget {
  const VaultXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
    );

    return MaterialApp(
      title: 'VaultX 2.0',
      scaffoldMessengerKey: AppGlobals.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      home: const AppLifecycleLockHandler(child: AuthGate()),
    );
  }
}

/// Listens for app background/close lifecycle events and triggers auto-lock
/// when elapsed time exceeds the configured AutoLockDuration.
class AppLifecycleLockHandler extends ConsumerStatefulWidget {
  final Widget child;
  const AppLifecycleLockHandler({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleLockHandler> createState() => _AppLifecycleLockHandlerState();
}

class _AppLifecycleLockHandlerState extends ConsumerState<AppLifecycleLockHandler>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        final lockDuration = ref.read(autoLockProvider).duration;
        if (elapsed >= lockDuration) {
          ref.read(authSessionProvider.notifier).lockVault();
        }
        _pausedAt = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);

    // Show a branded splash while the auth state is being resolved from
    // secure storage on first launch. This prevents a blank/white flash.
    if (!authState.isInitialized) {
      return const _SplashScreen();
    }

    if (!authState.isAuthenticated) {
      return const LoginSignUpScreen();
    }

    return const MainAppShell();
  }
}

/// Minimal branded splash shown for the fraction of a second while
/// [AuthSessionNotifier.checkStatus()] resolves from secure storage.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.lock_rounded, size: 38, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainAppShell extends StatefulWidget {
  final NavTab initialTab;

  const MainAppShell({super.key, this.initialTab = NavTab.passwords});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  late NavTab _currentTab;
  // Tracks which tabs have been visited so we only build them on first visit.
  final Set<NavTab> _visitedTabs = {};

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _visitedTabs.add(_currentTab);
  }

  Widget _buildScreen(NavTab tab, Widget screen) {
    // Defer building until first visit to keep startup fast.
    if (!_visitedTabs.contains(tab)) {
      return const SizedBox.shrink();
    }
    return Visibility(
      visible: _currentTab == tab,
      maintainState: true,
      child: screen,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Prevent the keyboard from resizing the body Stack. Without this,
      // when a search field is focused the Stack shrinks and FloatingNavDock
      // (aligned to Alignment.bottomCenter) rides up above the keyboard.
      // Individual screens handle their own bottom insets via SafeArea /
      // scroll padding, so nothing is obscured by the keyboard.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildScreen(NavTab.passwords, const PasswordsVaultScreen()),
          _buildScreen(NavTab.wallet, const DigitalWalletScreen()),
          _buildScreen(NavTab.generator, const PasswordGeneratorScreen()),
          _buildScreen(NavTab.settings, const SettingsScreen()),
          FloatingNavDock(
            currentTab: _currentTab,
            onTabSelected: (tab) {
              setState(() {
                _currentTab = tab;
                _visitedTabs.add(tab); // mark visited → build on next frame
              });
            },
          ),
        ],
      ),
    );
  }
}
