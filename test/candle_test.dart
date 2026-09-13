import 'package:flutter_test/flutter_test.dart';
import 'package:odin_trader/models/candle.dart';

void main() {
  test('parses Upstox candles oldest first', () {
    final candles = parseUpstoxCandles({
      'candles': [
        ['2026-09-12T10:00:00+05:30', 100, 104, 99, 103, 1200],
        ['2026-09-12T09:15:00+05:30', 98, 101, 97, 100, 800],
      ],
    });
    expect(candles, hasLength(2));
    expect(candles.first.close, 100);
    expect(candles.last.close, 103);
    expect(candles.last.volume, 1200);
  });

  test('fallback series ends at live LTP', () {
    final now = DateTime(2026, 9, 12, 15, 20);
    final candles = fallbackCandles(
      symbol: 'RELIANCE',
      ltp: 2912.4,
      change: 34.15,
      open: 2880,
      high: 2920,
      low: 2875,
      close: 2878.25,
      range: ChartRange.day,
      now: now,
    );
    expect(candles, hasLength(78));
    expect(candles.last.close, 2912.4);
    expect(candles.last.time, now);
  });

  test('live close updates the last candle', () {
    final updated = applyLiveClose([
      Candle(
        time: DateTime.utc(2026, 9, 12, 9, 15),
        open: 100,
        high: 101,
        low: 99,
        close: 100.5,
      ),
    ], 102.2);
    expect(updated.single.close, 102.2);
    expect(updated.single.high, 102.2);
  });

  test('builds Upstox history paths', () {
    final now = DateTime(2026, 9, 12);
    expect(
      chartHistoryPath(
        instrumentKey: 'NSE_EQ|INE002A01018',
        range: ChartRange.m1,
      ),
      '/historical-candle/intraday/NSE_EQ%7CINE002A01018/minutes/1',
    );
    expect(
      chartHistoryPath(
        instrumentKey: 'NSE_INDEX|Nifty 50',
        range: ChartRange.day,
        now: now,
      ),
      '/historical-candle/NSE_INDEX%7CNifty%2050/days/1/2026-09-12/2026-03-16',
    );
    expect(
      chartHistoryPath(
        instrumentKey: 'NSE_EQ|INE002A01018',
        range: ChartRange.month,
        now: now,
      ),
      '/historical-candle/NSE_EQ%7CINE002A01018/months/1/2026-09-12/2021-09-13',
    );
  });
}
