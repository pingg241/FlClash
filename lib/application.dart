import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/hotkey_manager.dart';
import 'package:fl_clash/manager/manager.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller.dart';
import 'pages/pages.dart';

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateProfilesTaskTimer;
  bool _preHasVpn = false;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: commonSharedXPageTransitions,
      TargetPlatform.windows: commonSharedXPageTransitions,
      TargetPlatform.linux: commonSharedXPageTransitions,
      TargetPlatform.macOS: commonSharedXPageTransitions,
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) {
    final baseColorScheme = ref.read(
      genColorSchemeProvider(
        brightness,
        color: primaryColor != null ? Color(primaryColor) : null,
      ),
    );
    if (brightness == Brightness.light) {
      return baseColorScheme.copyWith(
        surface: Colors.white,
        surfaceContainerLowest: const Color(0xFFF7F5EF),
        surfaceContainerLow: Colors.white,
        surfaceContainer: const Color(0xFFF6F3EC),
        surfaceContainerHigh: const Color(0xFFF1EDE4),
        surfaceContainerHighest: const Color(0xFFE9E4D9),
        onSurface: const Color(0xFF171614),
        onSurfaceVariant: const Color(0xFF5F5A52),
        outline: const Color(0xFFD6CFBF),
        outlineVariant: const Color(0xFFE6E0D2),
        secondaryContainer: Color.alphaBlend(
          baseColorScheme.primary.withValues(alpha: 0.10),
          Colors.white,
        ),
        onSecondaryContainer: const Color(0xFF2E241E),
        surfaceTint: Colors.transparent,
      );
    }
    return baseColorScheme.copyWith(
      surface: const Color(0xFF202327),
      surfaceContainerLowest: const Color(0xFF16181B),
      surfaceContainerLow: const Color(0xFF1B1E22),
      surfaceContainer: const Color(0xFF23272C),
      surfaceContainerHigh: const Color(0xFF2A2E34),
      surfaceContainerHighest: const Color(0xFF333840),
      onSurface: const Color(0xFFF5F1E9),
      onSurfaceVariant: const Color(0xFFC3BCAF),
      outline: const Color(0xFF515760),
      outlineVariant: const Color(0xFF3B4047),
      secondaryContainer: Color.alphaBlend(
        baseColorScheme.primary.withValues(alpha: 0.18),
        const Color(0xFF22201E),
      ),
      onSecondaryContainer: const Color(0xFFF8F3EB),
      surfaceTint: Colors.transparent,
    );
  }

  Color _getBackgroundColor(ColorScheme colorScheme) {
    return colorScheme.surfaceContainerLowest;
  }

  Color _getChromeColor(ColorScheme colorScheme, Color backgroundColor) {
    return backgroundColor;
  }

  ThemeData _buildThemeData(ColorScheme colorScheme) {
    final backgroundColor = _getBackgroundColor(colorScheme);
    final chromeColor = _getChromeColor(colorScheme, backgroundColor);
    final nextColorScheme = colorScheme.copyWith(
      surfaceTint: Colors.transparent,
    );
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: nextColorScheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      dividerColor: colorScheme.outlineVariant.opacity12,
      cardTheme: CardThemeData(
        color: nextColorScheme.surface,
        shadowColor: Colors.black.withValues(
          alpha: colorScheme.brightness == Brightness.light ? 0.04 : 0.18,
        ),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: nextColorScheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: chromeColor,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: chromeColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.secondaryContainer,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final currentContext = globalState.navigatorKey.currentContext;
      if (currentContext != null) {
        await appController.attach(currentContext, ref);
      } else {
        exit(0);
      }
      _autoUpdateProfilesTask();
      appController.initLink();
      app?.initShortcuts();
    });
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await appController.autoUpdateProfiles();
      _autoUpdateProfilesTask();
    });
  }

  Widget _buildPlatformState({required Widget child}) {
    if (system.isDesktop) {
      return WindowManager(
        child: TrayManager(
          child: HotKeyManager(child: ProxyManager(child: child)),
        ),
      );
    }
    return AndroidManager(child: TileManager(child: child));
  }

  Widget _buildState({required Widget child}) {
    return AppStateManager(
      child: CoreManager(
        child: ConnectivityManager(
          onConnectivityChanged: (results) async {
            commonPrint.log('connectivityChanged ${results.toString()}');
            appController.updateLocalIp();
            final hasVpn = results.contains(ConnectivityResult.vpn);
            if (_preHasVpn == hasVpn) {
              appController.addCheckIp();
            }
            _preHasVpn = hasVpn;
          },
          child: child,
        ),
      ),
    );
  }

  Widget _buildPlatformApp({required Widget child}) {
    if (system.isWindows) {
      return WindowHeaderContainer(child: child);
    }
    if (system.isLinux || system.isMacOS) {
      return child;
    }
    return VpnManager(child: child);
  }

  Widget _buildApp({required Widget child}) {
    return StatusManager(child: ThemeManager(child: child));
  }

  @override
  Widget build(context) {
    return Consumer(
      builder: (_, ref, child) {
        final locale = ref.watch(
          appSettingProvider.select((state) => state.locale),
        );
        final themeProps = ref.watch(themeSettingProvider);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: globalState.navigatorKey,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (_, child) {
            return AppEnvManager(
              child: _buildApp(
                child: _buildPlatformState(
                  child: _buildState(child: _buildPlatformApp(child: child!)),
                ),
              ),
            );
          },
          scrollBehavior: BaseScrollBehavior(),
          title: appName,
          locale: utils.getLocaleForString(locale),
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          themeMode: themeProps.themeMode,
          theme: _buildThemeData(
            _getAppColorScheme(
              brightness: Brightness.light,
              primaryColor: themeProps.primaryColor,
            ),
          ),
          darkTheme: _buildThemeData(
            _getAppColorScheme(
              brightness: Brightness.dark,
              primaryColor: themeProps.primaryColor,
            ),
          ),
          home: child!,
        );
      },
      child: const HomePage(),
    );
  }

  @override
  Future<void> dispose() async {
    linkManager.destroy();
    _autoUpdateProfilesTaskTimer?.cancel();
    await coreController.destroy();
    await appController.handleExit();
    super.dispose();
  }
}
