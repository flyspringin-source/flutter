import 'package:flutter_test/flutter_test.dart';
import 'package:odin_trader/data/option_analysis.dart';
import 'package:odin_trader/models/market_quote.dart';
import 'package:odin_trader/models/option_strike.dart';

void main() {
  test('atmWindow keeps the straddle and three strikes each side', () {
    final rows = [
      for (var strike = 24500.0; strike <= 25100; strike += 100)
        OptionStrike(strike: strike),
    ];

    final window = atmWindow(rows, 24780);
    expect(window.map((row) => row.strike), [
      24500,
      24600,
      24700,
      24800,
      24900,
      25000,
      25100,
    ]);
  });

  test('nearestIndexExpiry picks the upcoming weekly over a later monthly', () {
    final pick = nearestIndexExpiry(
      symbols: const ['SENSEX', 'NIFTY'],
      expiriesFor: (symbol) {
        if (symbol == 'NIFTY') {
          return const ['29-09-2026', '15-09-2026'];
        }
        return const ['18-09-2026'];
      },
      now: DateTime(2026, 9, 12),
    );
    expect(pick?.symbol, 'NIFTY');
    expect(pick?.expiry, '15-09-2026');
  });

  test('days to expiry uses the nearest live date', () {
    expect(daysToExpiry('29-09-2026', DateTime(2026, 9, 12)), 17);
    expect(daysToExpiryLabel('29-09-2026', DateTime(2026, 9, 12)), '17 days to expiry');
    expect(formatExpiryLong('29-09-2026'), '29 Sep 2026');
  });

  test('higher put OI and put writing points upside', () {
    expect(
      marketBias(
        callOi: 100,
        putOi: 180,
        callOiChange: 10,
        putOiChange: 40,
      ),
      MarketBias.upside,
    );
    expect(
      marketBias(
        callOi: 200,
        putOi: 80,
        callOiChange: 50,
        putOiChange: -10,
      ),
      MarketBias.downside,
    );
  });

  test('windowStats totals OI and day change from quotes', () {
    final stats = windowStats(
      rows: const [
        OptionStrike(strike: 24800, callToken: 'CE', putToken: 'PE'),
      ],
      quoteFor: (token) {
        if (token == 'CE') {
          return const MarketQuote(
            key: 'CE',
            openInterest: 1200,
            openInterestChange: 80,
            volume: 900,
          );
        }
        return const MarketQuote(
          key: 'PE',
          openInterest: 1800,
          openInterestChange: 140,
          volume: 400,
        );
      },
    );

    expect(stats.callOi, 1200);
    expect(stats.putOi, 1800);
    expect(stats.callOiChange, 80);
    expect(stats.putOiChange, 140);
    expect(stats.callVolume, 900);
    expect(stats.putVolume, 400);
    expect(stats.bias, MarketBias.upside);
  });

  test('adviseTrade still picks Buy when OI and volume are missing', () {
    final rows = [
      for (var strike = 24700.0; strike <= 24900; strike += 100)
        OptionStrike(
          strike: strike,
          callToken: 'CE$strike',
          putToken: 'PE$strike',
        ),
    ];
    final trade = adviseTrade(
      rows: rows,
      quoteFor: (_) => null,
      spot: 24780,
      expiry: '15-09-2026',
      now: DateTime(2026, 9, 12, 11, 30),
    );
    expect(trade?.action, TradeAction.call);
    expect(trade?.sideLabel, 'Buy');
    expect(trade?.strike, 24800);
    expect(trade?.buttonLabel, 'Buy 24800 CE');
    expect(trade?.canBuy, isTrue);
  });

  test('adviseTrade buys the ATM call when flow and greeks agree', () {
    final rows = [
      for (var strike = 24700.0; strike <= 24900; strike += 100)
        OptionStrike(
          strike: strike,
          callToken: 'CE$strike',
          putToken: 'PE$strike',
        ),
    ];
    final trade = adviseTrade(
      rows: rows,
      quoteFor: (token) {
        final call = token.startsWith('CE');
        final atm = token.contains('24800');
        return MarketQuote(
          key: token,
          ltp: atm ? 120 : 80,
          openInterest: call ? 800 : 1600,
          openInterestChange: call ? 20 : 80,
          volume: call ? 1800 : 400,
          delta: call ? (atm ? 0.46 : 0.28) : (atm ? -0.48 : -0.22),
          gamma: 0.012,
          theta: -4.2,
          vega: 8.5,
          iv: 12.4,
        );
      },
      spot: 24780,
      expiry: '15-09-2026',
      now: DateTime(2026, 9, 12, 11, 30),
    );
    expect(trade?.action, TradeAction.call);
    expect(trade?.strike, 24800);
    expect(trade?.entry, 120);
    expect(trade?.stopLoss, isNotNull);
    expect(trade?.target, isNotNull);
    expect(trade?.target! ?? 0, greaterThan(trade!.entry!));
    expect(trade.sideLabel, 'Buy');
  });

  test('adviseTrade alerts Sell when put flow dominates', () {
    final rows = [
      for (var strike = 24700.0; strike <= 24900; strike += 100)
        OptionStrike(
          strike: strike,
          callToken: 'CE$strike',
          putToken: 'PE$strike',
        ),
    ];
    final trade = adviseTrade(
      rows: rows,
      quoteFor: (token) {
        final call = token.startsWith('CE');
        return MarketQuote(
          key: token,
          ltp: 90,
          openInterest: call ? 2000 : 800,
          openInterestChange: call ? 120 : 10,
          volume: call ? 300 : 2200,
        );
      },
      spot: 24780,
      expiry: '15-09-2026',
      now: DateTime(2026, 9, 12, 11, 30),
    );
    expect(trade?.action, TradeAction.put);
    expect(trade?.sideLabel, 'Sell');
    expect(trade?.buttonLabel, contains('Sell'));
  });

  test('lotsFromMargin uses half of available margin', () {
    expect(
      lotsFromMargin(availableMargin: 13000, premium: 100, lotSize: 65),
      1,
    );
    expect(
      lotsFromMargin(availableMargin: 26000, premium: 100, lotSize: 65),
      2,
    );
    expect(
      lotsFromMargin(availableMargin: 0, premium: 100, lotSize: 65),
      1,
    );
  });

  test('optionLevels uses a 30 percent stop on weekly premium', () {
    final levels = optionLevels(ltp: 100, days: 3);
    expect(levels.entry, 100);
    expect(levels.stopLoss, 70);
    expect(levels.target, 155);
  });

  test('call volume over put volume points upside', () {
    expect(
      marketBias(
        callOi: 100,
        putOi: 100,
        callOiChange: 0,
        putOiChange: 0,
        callVolume: 800,
        putVolume: 200,
      ),
      MarketBias.upside,
    );
    expect(
      marketBias(
        callOi: 100,
        putOi: 100,
        callOiChange: 0,
        putOiChange: 0,
        callVolume: 200,
        putVolume: 800,
      ),
      MarketBias.downside,
    );
  });

  test('putCallRatio and maxPainStrike use open interest', () {
    expect(putCallRatio(1800, 1200), 1.5);
    expect(putCallRatio(100, 0), 0);
    final pain = maxPainStrike(
      rows: const [
        OptionStrike(strike: 100, callToken: 'c1', putToken: 'p1'),
        OptionStrike(strike: 110, callToken: 'c2', putToken: 'p2'),
        OptionStrike(strike: 120, callToken: 'c3', putToken: 'p3'),
      ],
      oiOf: (token) {
        return switch (token) {
          'c1' => 10,
          'c2' => 40,
          'c3' => 10,
          'p1' => 10,
          'p2' => 40,
          'p3' => 10,
          _ => 0,
        };
      },
    );
    expect(pain, 110);
  });
}
