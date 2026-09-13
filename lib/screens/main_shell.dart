import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/market_feed_controller.dart';
import '../state/scrip_master_controller.dart';
import '../state/upstox_account_controller.dart';
import '../state/upstox_controller.dart';
import '../state/watchlist_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/index_selector_drawer.dart';
import '../widgets/market_header.dart';
import '../widgets/market_sheets_host.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'positions_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _indexDrawerOpen = false;
  MarketFeedController? _feed;

  static const _staticPages = [
    OrdersScreen(),
    PositionsScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      _feed = context.read<MarketFeedController>();
      final watchlist = context.read<WatchlistController>();
      final auth = context.read<UpstoxController>();
      final master = context.read<ScripMasterController>();
      final account = context.read<UpstoxAccountController>();
      await watchlist.load();
      await auth.load();
      if (!mounted) {
        return;
      }
      _feed?.start();
      master.load();
      await account.refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ScripMasterController>().refreshIfDateChanged();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feed?.stop();
    super.dispose();
  }

  void _closeDrawer() {
    if (_indexDrawerOpen) {
      setState(() => _indexDrawerOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            MarketHeader(
              expanded: _indexDrawerOpen,
              onToggle: () {
                setState(() => _indexDrawerOpen = !_indexDrawerOpen);
              },
              onUpstoxStatusTap: () {
                _closeDrawer();
                setState(() => _tab = 4);
              },
            ),
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(
                    index: _tab,
                    children: [
                      HomeScreen(active: _tab == 0),
                      WatchlistScreen(active: _tab == 1),
                      ..._staticPages,
                    ],
                  ),
                  if (_indexDrawerOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _closeDrawer,
                        child: Container(
                          color: Colors.black.withValues(alpha: dark ? 0.45 : 0.28),
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: IgnorePointer(
                      ignoring: !_indexDrawerOpen,
                      child: ClipRect(
                        child: AnimatedSlide(
                          offset: _indexDrawerOpen
                              ? Offset.zero
                              : const Offset(0, -1),
                          duration: const Duration(milliseconds: 180),
                          curve: _indexDrawerOpen
                              ? Curves.easeOutCubic
                              : Curves.easeInCubic,
                          child: const IndexSelectorDrawer(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (index) {
            _closeDrawer();
            setState(() => _tab = index);
            if (index == 0 || index == 2 || index == 3 || index == 5) {
              context.read<UpstoxAccountController>().refresh();
            }
          },
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border),
              activeIcon: Icon(Icons.bookmark),
              label: 'Watchlist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline),
              activeIcon: Icon(Icons.pie_chart),
              label: 'Positions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
        ),
        const Positioned.fill(child: MarketSheetsHost()),
      ],
    );
  }
}
