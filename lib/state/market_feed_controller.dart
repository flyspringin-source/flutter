import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../data/scrip_catalog.dart';
import '../data/scrip_master_parser.dart';
import '../data/scrip_master_service.dart';
import '../data/upstox_instruments.dart';
import '../models/market_quote.dart';
import '../models/option_strike.dart';
import '../services/upstox_market_client.dart';
import '../services/upstox_ws_client.dart';
import 'index_controller.dart';
import 'scrip_master_controller.dart';
import 'upstox_controller.dart';
import 'watchlist_controller.dart';

class MarketFeedController extends ChangeNotifier {
  MarketFeedController({
    required this.indices,
    required this.watchlist,
    required this.auth,
    required this.master,
    UpstoxMarketClient? client,
  }) : _client = client ?? UpstoxMarketClient() {
    auth.addListener(_onDependenciesChanged);
    watchlist.addListener(_onDependenciesChanged);
    indices.addListener(_onDependenciesChanged);
    master.addListener(_onDependenciesChanged);
    _ws = UpstoxWsClient(
      onQuotes: _onWsQuotes,
      onStatus: (live) {
        _wsLive = live;
        if (live != _connected) {
          _connected = live;
          _notify();
        }
        _restartTicker();
      },
    );
  }

  final IndexController indices;
  final WatchlistController watchlist;
  final UpstoxController auth;
  final ScripMasterController master;
  final UpstoxMarketClient _client;
  late final UpstoxWsClient _ws;
  var _started = false;
  var _connected = false;
  var _wsLive = false;
  var _disposed = false;
  var _refreshing = false;
  String? _depthToken;
  Timer? _ticker;
  var _greeksTick = 0;
  var _notifyScheduled = false;
  final _quotes = <String, MarketQuote>{};
  final _chainTokens = <String>{};
  final _keyToToken = <String, String>{};
  var _chainLocked = false;

  bool get isLive => _connected || _wsLive;
  bool get optionChainOpen => _chainLocked;

  Future<void> start() async {
    if (_started || _isWidgetTest) {
      return;
    }
    _started = true;
    await _ws.start();
    _connectStream();
    await _refresh();
    _restartTicker();
  }

  Future<void> stop() async {
    _started = false;
    _ticker?.cancel();
    _ticker = null;
    _ws.stop();
    _connected = false;
    _wsLive = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ws.stop();
    auth.removeListener(_onDependenciesChanged);
    watchlist.removeListener(_onDependenciesChanged);
    indices.removeListener(_onDependenciesChanged);
    master.removeListener(_onDependenciesChanged);
    super.dispose();
  }

  Future<void> subscribeTokens(List<String> tokens) async {
    if (tokens.isEmpty) {
      return;
    }
    _subscribeStream(tokens, mode: 'full');
    if (!_wsLive) {
      await _refresh(extraTokens: tokens);
    }
  }

  Future<void> watchChain(List<String> tokens, {bool exclusive = false}) async {
    if (_chainLocked && !exclusive) {
      return;
    }
    final next = tokens.where((token) => token.isNotEmpty).toSet();
    final same =
        next.length == _chainTokens.length && next.every(_chainTokens.contains);
    if (same && exclusive == _chainLocked) {
      return;
    }
    _chainLocked = exclusive;
    _chainTokens
      ..clear()
      ..addAll(next);
    _subscribeStream(next, mode: 'full');
    if (!_wsLive) {
      _restartTicker();
      await _refresh();
    }
  }

  Future<({List<OptionStrike> rows, double spot})> loadLiveOptionChain({
    required String underlying,
    required String expiry,
  }) async {
    final fallback = master.chainFor(underlying, expiry);
    if (_isWidgetTest) {
      await watchChain([
        for (final row in fallback) ...row.tokens,
      ], exclusive: true);
      return (rows: fallback, spot: 0.0);
    }
    final accessToken = auth.primaryAccessToken();
    final instrumentKey = _underlyingInstrumentKey(underlying);
    final isoExpiry = isoExpiryDate(expiry);
    if (accessToken == null || instrumentKey == null || isoExpiry == null) {
      await _restartExclusiveChain([
        for (final row in fallback) ...row.tokens,
      ]);
      return (rows: fallback, spot: 0.0);
    }
    try {
      final snapshot = await _client.fetchOptionChain(
        accessToken: accessToken,
        instrumentKey: instrumentKey,
        expiryDate: isoExpiry,
      );
      for (final row in snapshot.quotes) {
        _keyToToken[row.instrumentKey] = row.instrumentKey;
        _onQuote(row.quote, row.instrumentKey);
      }
      final tokens = snapshot.tokens.isEmpty
          ? [for (final row in fallback) ...row.tokens]
          : snapshot.tokens;
      await _restartExclusiveChain(tokens);
      _notify();
      return (
        rows: snapshot.rows.isEmpty ? fallback : snapshot.rows,
        spot: snapshot.spot,
      );
    } catch (error) {
      debugPrint('Upstox option chain failed: $error');
      await _restartExclusiveChain([
        for (final row in fallback) ...row.tokens,
      ]);
      return (rows: fallback, spot: 0.0);
    }
  }

  Future<void> _restartExclusiveChain(Iterable<String> tokens) async {
    final next = tokens.where((token) => token.isNotEmpty).toSet();
    final previous = [
      for (final token in _chainTokens)
        if (_instrumentKeyFor(token) != null) _instrumentKeyFor(token)!,
    ];
    _chainLocked = true;
    _chainTokens
      ..clear()
      ..addAll(next);
    if (previous.isNotEmpty) {
      _ws.unsubscribe(previous, mode: 'full');
      _ws.unsubscribe(previous, mode: 'ltpc');
    }
    final accessToken = auth.primaryAccessToken();
    if (accessToken != null) {
      _ws.connect(accessToken);
    }
    _subscribeStream([
      ...watchlist.tokens,
      ...indices.tokens,
      ..._chainTokens,
    ], mode: 'full');
    if (!_wsLive) {
      _restartTicker();
      await _refresh();
    }
  }

  void stopChain() {
    if (_chainTokens.isNotEmpty) {
      _ws.unsubscribe([
        for (final token in _chainTokens)
          if (_instrumentKeyFor(token) != null) _instrumentKeyFor(token)!,
      ]);
    }
    _chainTokens.clear();
    _chainLocked = false;
    _restartTicker();
    _notify();
  }

  MarketQuote? quoteFor(String token) => _quotes[token];

  Future<void> watchDepth(String token) async {
    if (_depthToken == token) {
      return;
    }
    _depthToken = token;
    _restartTicker();
    await _refresh();
  }

  Future<void> stopDepth() async {
    _depthToken = null;
    _restartTicker();
  }

  void _onDependenciesChanged() {
    if (!_started || _disposed) {
      return;
    }
    _connectStream();
    if (!_wsLive) {
      _restartTicker();
      unawaited(_refresh());
    }
  }

  void _connectStream() {
    final accessToken = auth.primaryAccessToken();
    if (accessToken == null) {
      return;
    }
    _ws.connect(accessToken);
    final extra = master.websocketTokens(
      extraTokens: [...watchlist.tokens, ...indices.tokens, ..._chainTokens],
      indexSymbols: [
        for (final index in [...indices.selectedIndices, ...indices.indices])
          index.scripSymbol,
      ],
    );
    _subscribeStream([
      ...watchlist.tokens,
      ...indices.tokens,
      ..._chainTokens,
    ], mode: 'full');
    if (!_chainLocked) {
      _subscribeStream(
        extra.where((token) => !_chainTokens.contains(token)),
        mode: 'ltpc',
      );
    }
    _saveSubscriptionKeys(extra);
  }

  void _saveSubscriptionKeys(List<String> tokens) {
    if (_isWidgetTest) {
      return;
    }
    unawaited(() async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final keys = [
          for (final token in tokens)
            if (_instrumentKeyFor(token) != null) _instrumentKeyFor(token)!,
        ];
        await File('${dir.path}/ws_tokens.json').writeAsString(
          jsonEncode({
            'date': scripMasterDateKey(),
            'tokens': tokens,
            'keys': keys,
          }),
        );
      } catch (_) {}
    }());
  }

  void _subscribeStream(Iterable<String> tokens, {required String mode}) {
    final keys = <String>[];
    for (final token in tokens) {
      final key = _instrumentKeyFor(token);
      if (key == null) {
        continue;
      }
      _keyToToken[key] = token;
      keys.add(key);
    }
    _ws.subscribe(keys, mode: mode);
  }

  void _onWsQuotes(UpstoxFeedQuotes rows) {
    var changed = false;
    final applied = <MarketQuote>[];
    for (final row in rows) {
      final token = _keyToToken[row.instrumentKey] ??
          _keyToToken[row.quote.key] ??
          row.instrumentKey;
      if (_onQuote(row.quote, token)) {
        changed = true;
      }
      final stored = _quotes[token];
      if (stored != null) {
        applied.add(stored);
      }
    }
    if (applied.isNotEmpty) {
      indices.applyQuotes(applied, notify: false);
      watchlist.applyQuotes(applied);
    }
    if (changed) {
      _connected = true;
      _notify();
    }
  }

  void _restartTicker() {
    _ticker?.cancel();
    if (!_started || _isWidgetTest || _wsLive) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_disposed && !_wsLive) {
        unawaited(_refresh());
      }
    });
  }

  Future<void> _refresh({List<String> extraTokens = const []}) async {
    if (_refreshing || _disposed || _isWidgetTest) {
      return;
    }
    final accessToken = auth.primaryAccessToken();
    if (accessToken == null) {
      if (_connected) {
        _connected = false;
        _notify();
      }
      return;
    }
    final tokens = <String>{
      ...indices.tokens,
      ...watchlist.tokens,
      ..._chainTokens,
      ...extraTokens,
      ?_depthToken,
    };
    final mapped = <String, String>{};
    for (final token in tokens) {
      final key = _instrumentKeyFor(token);
      if (key != null) {
        mapped[key] = token;
      }
    }
    if (mapped.isEmpty) {
      return;
    }
    _refreshing = true;
    try {
      final rows = await _client.fetchQuotes(
        accessToken: accessToken,
        instrumentKeys: mapped.keys.toList(),
      );
      var live = false;
      var quotesChanged = false;
      final applied = <MarketQuote>[];
      for (final row in rows) {
        final token = mapped[row.instrumentKey];
        if (token == null) {
          continue;
        }
        live = true;
        if (_onQuote(row.quote, token)) {
          quotesChanged = true;
        }
        final stored = _quotes[token];
        if (stored != null) {
          applied.add(stored);
        }
      }
      _greeksTick += 1;
      if (_chainTokens.isNotEmpty && _greeksTick % 3 == 1) {
        final greeks = await _client.fetchGreeks(
          accessToken: accessToken,
          instrumentKeys: [
            for (final token in _chainTokens)
              if (_instrumentKeyFor(token) != null) _instrumentKeyFor(token)!,
          ],
        );
        for (final row in greeks) {
          final token = mapped[row.instrumentKey];
          if (token != null && _onQuote(row.quote, token)) {
            quotesChanged = true;
          }
        }
      }
      indices.applyQuotes(applied, notify: false);
      watchlist.applyQuotes(applied);
      if (_connected != live || quotesChanged) {
        _connected = live;
        _notify();
      }
    } catch (error) {
      _connected = false;
      debugPrint('Upstox market quote failed: $error');
      _notify();
    } finally {
      _refreshing = false;
    }
  }

  String? _underlyingInstrumentKey(String symbol) {
    final mapped = upstoxIndexKeys[symbol.trim().toUpperCase()];
    if (mapped != null) {
      return mapped;
    }
    final scrip = master.lookupSymbol(symbol);
    if (scrip == null) {
      return null;
    }
    return upstoxInstrumentKey(
          token: scrip.token,
          symbol: scrip.symbol,
          isin: scrip.isin,
          exchange: scrip.exchange,
          kind: scrip.kind == ScripKind.option ? ScripKind.equity : scrip.kind,
        ) ??
        (scrip.token.contains('|') ? normalizeUpstoxInstrumentKey(scrip.token) : null);
  }

  String? _instrumentKeyFor(String token) {
    if (token.contains('|')) {
      return normalizeUpstoxInstrumentKey(token);
    }
    final listed = watchlist.byToken(token);
    if (listed != null) {
      return upstoxInstrumentKey(
            token: listed.token,
            symbol: listed.kind == ScripKind.equity
                ? listed.symbol
                : listed.chainSymbol,
            isin: listed.isin,
            exchange: listed.exchange,
            kind: listed.kind,
          ) ??
          upstoxFoKeyFromToken(token);
    }
    for (final index in indices.indices) {
      if (index.token == token) {
        return upstoxInstrumentKey(
          token: index.token,
          symbol: index.scripSymbol,
          kind: ScripKind.idx,
        );
      }
    }
    final scrip = master.byToken(token);
    if (scrip != null) {
      return upstoxInstrumentKey(
            token: scrip.token,
            symbol: scrip.symbol,
            isin: scrip.isin,
            exchange: scrip.exchange,
            kind: scrip.kind,
          ) ??
          upstoxFoKeyFromToken(token);
    }
    return upstoxFoKeyFromToken(token);
  }

  bool _onQuote(MarketQuote quote, String token) {
    if (_disposed) {
      return false;
    }
    final localized = MarketQuote(
      key: token,
      ltp: quote.ltp,
      change: quote.change,
      open: quote.open,
      high: quote.high,
      low: quote.low,
      close: quote.close,
      week52High: quote.week52High,
      week52Low: quote.week52Low,
      lowerCircuit: quote.lowerCircuit,
      upperCircuit: quote.upperCircuit,
      buyDepth: quote.buyDepth,
      sellDepth: quote.sellDepth,
      openInterest: quote.openInterest,
      openInterestChange: quote.openInterestChange,
      volume: quote.volume,
      delta: quote.delta,
      gamma: quote.gamma,
      theta: quote.theta,
      vega: quote.vega,
      iv: quote.iv,
    );
    final previous = _quotes[token];
    final merged = previous == null ? localized : previous.merge(localized);
    _quotes[token] = merged;
    return previous == null || !_samePaint(previous, merged);
  }

  bool _samePaint(MarketQuote left, MarketQuote right) {
    return left.ltp == right.ltp &&
        left.change == right.change &&
        left.open == right.open &&
        left.high == right.high &&
        left.low == right.low &&
        left.close == right.close &&
        left.openInterest == right.openInterest &&
        left.openInterestChange == right.openInterestChange &&
        left.volume == right.volume &&
        left.delta == right.delta;
  }

  void _notify() {
    if (_disposed || _notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  bool get _isWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString() ==
        'AutomatedTestWidgetsFlutterBinding';
  }
}
