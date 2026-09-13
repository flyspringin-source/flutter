import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:odin_trader/data/scrip_catalog.dart';
import 'package:odin_trader/services/upstox_feed_codec.dart';
import 'package:odin_trader/state/watchlist_controller.dart';

void main() {
  test('watchlist can add another tab and keep scrips per tab', () {
    final watchlist = WatchlistController();
    expect(watchlist.tabs, hasLength(5));
    expect(watchlist.stocks.first.symbol, 'RELIANCE');
    watchlist.addTab();
    expect(watchlist.tabs, hasLength(6));
    expect(watchlist.tabs.last.name, 'Watchlist 6');
    expect(watchlist.stocks, isEmpty);
    watchlist.removeTab(5);
    expect(watchlist.tabs, hasLength(5));
    watchlist.addTab('Swing');
    expect(watchlist.tabs.last.name, 'Swing');
    final scrip = scripCatalog.firstWhere((item) => item.symbol == 'ICICIBANK');
    expect(watchlist.addScrip(scrip), isTrue);
    expect(watchlist.stocks.first.symbol, 'ICICIBANK');
    watchlist.selectTab(0);
    expect(watchlist.stocks.first.symbol, 'RELIANCE');
    expect(watchlist.tokens, containsAll(['1_2885', '1_4963']));
  });

  test('decodes an Upstox LTPC protobuf feed map entry', () {
    final ltp = _double(24780.3);
    final close = _double(24682.1);
    final ltpc = Uint8List.fromList([
      9,
      ...ltp,
      33,
      ...close,
    ]);
    final feed = _len(1, ltpc);
    final entry = [
      ..._len(1, 'NSE_INDEX|Nifty 50'.codeUnits),
      ..._len(2, feed),
    ];
    final message = _len(2, entry);
    final quotes = decodeUpstoxFeed(message);
    expect(quotes, hasLength(1));
    expect(quotes.first.instrumentKey, 'NSE_INDEX|Nifty 50');
    expect(quotes.first.quote.ltp, closeTo(24780.3, 0.01));
    expect(quotes.first.quote.change, closeTo(98.2, 0.01));
  });
}

List<int> _double(double value) {
  final data = ByteData(8)..setFloat64(0, value, Endian.little);
  return data.buffer.asUint8List();
}

List<int> _varint(int value) {
  final bytes = <int>[];
  var next = value;
  while (next > 0x7f) {
    bytes.add((next & 0x7f) | 0x80);
    next >>= 7;
  }
  bytes.add(next);
  return bytes;
}

List<int> _len(int field, List<int> payload) {
  return [((field << 3) | 2), ..._varint(payload.length), ...payload];
}
