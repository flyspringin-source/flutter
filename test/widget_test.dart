import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_trader/data/scrip_catalog.dart';
import 'package:odin_trader/main.dart';
import 'package:odin_trader/models/market_quote.dart';
import 'package:odin_trader/models/watchlist_stock.dart';
import 'package:odin_trader/state/index_controller.dart';
import 'package:odin_trader/state/market_sheet_controller.dart';
import 'package:odin_trader/state/theme_controller.dart';
import 'package:odin_trader/state/watchlist_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _enterMpin(WidgetTester tester) async {
  await tester.tap(find.text('1'));
  await tester.pump();
  await tester.tap(find.text('1'));
  await tester.pump();
  await tester.tap(find.text('1'));
  await tester.pump();
  await tester.tap(find.text('1'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('splash animates Flyspring then opens login', (tester) async {
    await tester.pumpWidget(const FlyspringApp(showSplash: true));

    expect(find.byKey(const ValueKey('splash-flyspring')), findsOneWidget);
    expect(find.text('TRADE'), findsOneWidget);
    expect(find.text('Unlock trading'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('Unlock trading'), findsOneWidget);
  });

  testWidgets('Login screen shows Flyspring unlock', (tester) async {
    await tester.pumpWidget(const FlyspringApp());

    expect(find.text('FLYSPRING'), findsOneWidget);
    expect(find.text('Unlock trading'), findsOneWidget);
    expect(find.text('Enter MPIN or use fingerprint'), findsOneWidget);
    expect(find.text('Default MPIN  ·  1111'), findsOneWidget);
  });

  testWidgets('MPIN 1111 opens the trading home', (tester) async {
    await tester.pumpWidget(const FlyspringApp());
    await _enterMpin(tester);

    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.byKey(const ValueKey('upstox-status')), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Positions'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Index analysis'), findsNothing);
    expect(find.text('NIFTY'), findsWidgets);
    expect(find.text('AVAILABLE + USED MARGIN'), findsNothing);
    expect(find.text('Prev. close'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Call OI'), findsOneWidget);
    expect(find.text('Put OI'), findsOneWidget);
    expect(find.text('Call volume'), findsOneWidget);
    expect(find.text('Put volume'), findsOneWidget);
    expect(find.textContaining('Neutral'), findsNothing);
    expect(find.textContaining('do not buy'), findsNothing);
    expect(find.text('Entry'), findsOneWidget);
    expect(find.text('Stop loss'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Buy'), findsOneWidget);
    expect(find.byKey(const ValueKey('analysis-buy')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-price')), findsOneWidget);
    expect(find.text('Lots'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qty-mode')));
    await tester.pump();
    expect(find.text('Qty'), findsOneWidget);
    expect(find.textContaining('15 Sep 2026'), findsOneWidget);
    expect(find.textContaining('expir'), findsOneWidget);
    expect(find.text('RELIANCE'), findsNothing);
  });

  testWidgets('Settings can switch Light, Dark and Phone themes', (tester) async {
    await tester.pumpWidget(const FlyspringApp());
    await _enterMpin(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await tester.scrollUntilVisible(
      find.text('Upstox configuration'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Redirect URL'), findsOneWidget);
    expect(find.text('API keys & secrets'), findsOneWidget);
    expect(find.text('API Key'), findsWidgets);
    expect(find.text('API Secret'), findsWidgets);
    expect(find.text('Token 1'), findsOneWidget);
    expect(find.text('Save keys & secrets'), findsOneWidget);
    expect(find.text('Generate'), findsWidgets);
  });

  test('persists theme mode across restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ThemeController(persistEnabled: true);
    expect(first.mode, ThemeMode.system);
    await first.setMode(ThemeMode.dark);
    expect(first.mode, ThemeMode.dark);

    final second = ThemeController(persistEnabled: true);
    await second.load();
    expect(second.mode, ThemeMode.dark);
  });

  test('opening option chain closes scrip details', () {
    final sheets = MarketSheetController();
    sheets.openDetail(token: '2_2885');
    sheets.openChain(underlying: 'RELIANCE', spot: 1400);
    expect(sheets.detailOpen, isFalse);
    expect(sheets.chainOpen, isTrue);
    expect(sheets.top, MarketSheetKind.chain);
  });

  test('selecting a third index unselects the lastly selected', () {
    final controller = IndexController();
    expect(
      controller.selectedIndices.map((index) => index.id).toList(),
      ['sensex', 'nifty'],
    );

    controller.toggleIndex('banknifty');

    expect(
      controller.selectedIndices.map((index) => index.id).toList(),
      ['sensex', 'banknifty'],
    );
    expect(controller.isSelected('nifty'), isFalse);
  });

  test('ODIN touchline tags parse LTP and change', () {
    final quote = quoteFromOdinTags(
      parseOdinTags(
        '63=FT3.0|64=209|1=1|7=26000|8=2478030|399=100|418=9820|19=2468210',
      ),
    );
    expect(quote?.key, '1_26000');
    expect(quote?.ltp, 24780.30);
    expect(quote?.change, 98.20);
  });

  test('ODIN touchline tag 88 is open interest', () {
    final first = quoteFromOdinTags(
      parseOdinTags('63=FT3.0|1=2|7=90005|8=14825|399=100|88=125000|418=140'),
    );
    expect(first?.openInterest, 125000);
    expect(first?.ltp, 148.25);

    final ltpOnly = quoteFromOdinTags(
      parseOdinTags('63=FT3.0|1=2|7=90005|8=15000|399=100|418=200'),
    );
    final merged = first!.merge(ltpOnly!);
    expect(merged.ltp, 150);
    expect(merged.openInterest, 125000);
  });

  test('watchlist applies live LTP by token', () {
    final watchlist = WatchlistController();
    watchlist.applyQuote(
      const MarketQuote(key: '1_2885', ltp: 3001.5, change: 12.25),
    );
    expect(watchlist.stocks.first.symbol, 'RELIANCE');
    expect(watchlist.stocks.first.ltp, 3001.5);
    expect(watchlist.stocks.first.change, 12.25);
  });

  test('watchlist can add a catalog scrip', () {
    final watchlist = WatchlistController();
    final scrip = scripCatalog.firstWhere((item) => item.symbol == 'ICICIBANK');
    expect(watchlist.addScrip(scrip), isTrue);
    expect(watchlist.stocks.first.symbol, 'ICICIBANK');
  });

  test('watchlist can add a stock from scrip details', () {
    final watchlist = WatchlistController();
    final stock = WatchlistStock(
      symbol: 'WIPRO',
      name: 'Wipro',
      token: '1_3787',
      ltp: 250,
      change: 1.2,
    );
    expect(watchlist.addStock(stock), isTrue);
    expect(watchlist.containsToken('1_3787'), isTrue);
    expect(watchlist.addStock(stock), isFalse);
  });

  testWidgets('watchlist scrip opens details with depth and trade buttons', (
    tester,
  ) async {
    await tester.pumpWidget(const FlyspringApp());
    await _enterMpin(tester);

    await tester.tap(find.text('Watchlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Chart'), findsWidgets);
    await tester.tap(find.widgetWithText(Tab, 'Chart'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chart-expand')), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Overview'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('In watchlist'), findsOneWidget);
    expect(find.text('Add to watchlist'), findsNothing);
    expect(find.text('Price stats'), findsNothing);
    expect(find.text('Candle'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('High'), findsWidgets);
    expect(find.text('Low'), findsWidgets);
    expect(find.text('Prev. close'), findsOneWidget);
    expect(find.text('Market depth'), findsOneWidget);
    expect(find.text('Option chain'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('option-chain-link')));
    await tester.pumpAndSettle();
    expect(find.text('RELIANCE option chain'), findsOneWidget);
    expect(find.text('CALL'), findsOneWidget);
    expect(find.text('VOL'), findsWidgets);
    expect(find.text('IV'), findsWidgets);
    expect(find.text('BID'), findsWidgets);
    expect(find.text('CHG'), findsWidgets);
    expect(find.text('PCR'), findsOneWidget);
    expect(find.text('Strategy'), findsOneWidget);
    expect(find.text('PUT'), findsOneWidget);
    expect(find.text('SPOT'), findsOneWidget);
    expect(find.text('2900'), findsWidgets);
    expect(find.byKey(const ValueKey('scrip-detail-panel')), findsNothing);
    expect(find.byKey(const ValueKey('option-chain-panel')), findsOneWidget);
    expect(find.text('Buy'), findsNothing);
    expect(find.text('Sell'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chain-call-2_90005')));
    await tester.pumpAndSettle();
    expect(find.text('RELIANCE 29-09-2026 2900 CE'), findsOneWidget);
    expect(find.byKey(const ValueKey('scrip-detail-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('option-chain-panel')), findsOneWidget);
    expect(find.text('Buy'), findsWidgets);
    expect(find.text('Sell'), findsWidgets);
  });

  testWidgets('option chain strategy shows required margin', (tester) async {
    await tester.pumpWidget(const FlyspringApp());
    await _enterMpin(tester);

    await tester.tap(find.text('Watchlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('option-chain-link')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chain-strategy-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chain-strategy-straddle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chain-call-2_90005')));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 legs'), findsOneWidget);
    expect(find.textContaining('Req.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byKey(const ValueKey('scrip-detail-panel')), findsNothing);
  });

  testWidgets('can add a scrip to the watchlist', (tester) async {
    await tester.pumpWidget(const FlyspringApp());
    await _enterMpin(tester);

    await tester.tap(find.text('Watchlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add scrip'));
    await tester.pumpAndSettle();

    expect(find.text('Add to watchlist'), findsOneWidget);
    expect(find.text('Index'), findsOneWidget);
    expect(find.text('Futures'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    await tester.tap(find.text('Index'));
    await tester.pump();
    expect(find.text('NIFTY'), findsWidgets);
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ICICI');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('add-ICICIBANK')));
    await tester.pumpAndSettle();

    expect(find.text('ICICIBANK'), findsOneWidget);
    expect(find.textContaining('ICICI Bank'), findsOneWidget);
  });

  testWidgets('Orders groups pending executed cancelled rejected', (tester) async {
    await tester.pumpWidget(const FlyspringApp());
    await _enterMpin(tester);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Executed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('No pending orders'), findsOneWidget);

    await tester.tap(find.text('Executed'));
    await tester.pumpAndSettle();
    expect(find.text('No executed orders'), findsOneWidget);
  });

  testWidgets('Profile shows Upstox funds', (tester) async {
    await tester.pumpWidget(const FlyspringApp());
    await _enterMpin(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('AVAILABLE + USED MARGIN'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Used margin'), findsOneWidget);
    expect(find.text('Collateral'), findsOneWidget);
    expect(find.text('Not linked'), findsOneWidget);
  });

  testWidgets('Buy opens an Upstox order ticket', (tester) async {
    await tester.pumpWidget(const FlyspringApp());
    await _enterMpin(tester);

    await tester.tap(find.text('Watchlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();

    expect(find.text('Place buy order'), findsOneWidget);
    expect(find.text('Intraday'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Limit'), findsOneWidget);
  });
}
