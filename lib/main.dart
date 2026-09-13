import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'state/index_controller.dart';
import 'state/market_feed_controller.dart';
import 'state/market_sheet_controller.dart';
import 'state/scrip_master_controller.dart';
import 'state/theme_controller.dart';
import 'state/upstox_account_controller.dart';
import 'state/upstox_controller.dart';
import 'state/watchlist_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlyspringApp());
}

class FlyspringApp extends StatelessWidget {
  const FlyspringApp({super.key, this.showSplash});

  final bool? showSplash;

  bool get _showSplash {
    if (showSplash != null) {
      return showSplash!;
    }
    return WidgetsBinding.instance.runtimeType.toString() !=
        'AutomatedTestWidgetsFlutterBinding';
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IndexController()),
        ChangeNotifierProvider(create: (_) => WatchlistController()),
        ChangeNotifierProvider(create: (_) => ScripMasterController()),
        ChangeNotifierProvider(
          create: (_) {
            final theme = ThemeController();
            theme.load();
            return theme;
          },
        ),
        ChangeNotifierProvider(create: (_) => MarketSheetController()),
        ChangeNotifierProvider(
          create: (_) {
            final auth = UpstoxController();
            auth.load();
            return auth;
          },
        ),
        ChangeNotifierProvider(
          create: (context) => UpstoxAccountController(
            auth: context.read<UpstoxController>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => MarketFeedController(
            indices: context.read<IndexController>(),
            watchlist: context.read<WatchlistController>(),
            auth: context.read<UpstoxController>(),
            master: context.read<ScripMasterController>(),
          ),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'Flyspring',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: theme.mode,
            home: _showSplash ? const SplashScreen() : const LoginScreen(),
            builder: (context, child) {
              final colors = AppColors.of(context);
              final dark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      dark ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      dark ? Brightness.dark : Brightness.light,
                  systemNavigationBarColor: colors.surface,
                  systemNavigationBarIconBrightness:
                      dark ? Brightness.light : Brightness.dark,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
