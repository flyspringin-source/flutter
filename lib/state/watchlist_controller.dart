import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/scrip_catalog.dart';
import '../models/market_quote.dart';
import '../models/watchlist_stock.dart';
import '../models/watchlist_tab.dart';

class WatchlistController extends ChangeNotifier {
  WatchlistController() : _tabs = _defaultTabs();

  static const _prefsKey = 'watchlists_v1';
  static const maxTabs = 10;

  static String defaultTabName(int index) => 'Watchlist $index';

  List<WatchlistTab> _tabs;
  var _selected = 0;

  List<WatchlistTab> get tabs => List.unmodifiable(_tabs);

  int get selectedIndex => _selected.clamp(0, _tabs.isEmpty ? 0 : _tabs.length - 1);

  WatchlistTab get current => _tabs[selectedIndex];

  List<WatchlistStock> get stocks => List.unmodifiable(current.stocks);

  List<String> get tokens {
    return [
      for (final tab in _tabs)
        for (final stock in tab.stocks) stock.token,
    ];
  }

  bool containsToken(String token) {
    return current.stocks.any((stock) => stock.token == token);
  }

  WatchlistStock? byToken(String token) {
    for (final tab in _tabs) {
      for (final stock in tab.stocks) {
        if (stock.token == token) {
          return stock;
        }
      }
    }
    return null;
  }

  Future<void> load() async {
    if (_isWidgetTest) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        await _persist();
        return;
      }
      final data = jsonDecode(raw);
      if (data is! Map) {
        return;
      }
      final saved = data['tabs'];
      if (saved is! List || saved.isEmpty) {
        return;
      }
      _tabs = [
        for (final item in saved)
          if (item is Map) WatchlistTab.fromJson(item),
      ];
      if (_tabs.isEmpty) {
        _tabs = _defaultTabs();
      }
      _selected = (data['selected'] as num?)?.toInt() ?? 0;
      if (_selected < 0 || _selected >= _tabs.length) {
        _selected = 0;
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Watchlist load failed: $error');
    }
  }

  void selectTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _selected) {
      return;
    }
    _selected = index;
    notifyListeners();
    unawaitedPersist();
  }

  void addTab([String? name]) {
    if (_tabs.length >= maxTabs) {
      return;
    }
    final trimmed = name?.trim() ?? '';
    _tabs.add(
      WatchlistTab(
        id: UniqueKeyName.next(),
        name: trimmed.isEmpty
            ? defaultTabName(_tabs.length + 1)
            : trimmed,
      ),
    );
    _selected = _tabs.length - 1;
    notifyListeners();
    unawaitedPersist();
  }

  void renameTab(int index, String name) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    final next = name.trim();
    if (next.isEmpty || next == _tabs[index].name) {
      return;
    }
    _tabs[index].name = next;
    notifyListeners();
    unawaitedPersist();
  }

  void removeTab(int index) {
    if (_tabs.length <= 1 || index < 0 || index >= _tabs.length) {
      return;
    }
    _tabs.removeAt(index);
    if (_selected >= _tabs.length) {
      _selected = _tabs.length - 1;
    }
    notifyListeners();
    unawaitedPersist();
  }

  bool addScrip(ScripInfo scrip) {
    return addStock(WatchlistStock.fromScrip(scrip));
  }

  bool addStock(WatchlistStock stock) {
    if (containsToken(stock.token)) {
      return false;
    }
    current.stocks.insert(0, stock);
    notifyListeners();
    unawaitedPersist();
    return true;
  }

  void removeScrip(String token) {
    final before = current.stocks.length;
    current.stocks.removeWhere((item) => item.token == token);
    if (current.stocks.length == before) {
      return;
    }
    notifyListeners();
    unawaitedPersist();
  }

  void applyQuote(MarketQuote quote) {
    applyQuotes([quote]);
  }

  void applyQuotes(Iterable<MarketQuote> quotes) {
    var changed = false;
    for (final quote in quotes) {
      if (_applyQuote(quote)) {
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  bool _applyQuote(MarketQuote quote) {
    var changed = false;
    for (final tab in _tabs) {
      final index = tab.stocks.indexWhere((item) => item.token == quote.key);
      if (index < 0) {
        continue;
      }
      final current = tab.stocks[index];
      final next = current.copyWith(
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
        buyDepth: quote.buyDepth.isEmpty ? null : quote.buyDepth,
        sellDepth: quote.sellDepth.isEmpty ? null : quote.sellDepth,
      );
      if (next.ltp == current.ltp &&
          next.change == current.change &&
          next.open == current.open &&
          next.high == current.high &&
          next.low == current.low &&
          next.close == current.close) {
        continue;
      }
      tab.stocks[index] = next;
      changed = true;
    }
    return changed;
  }

  void unawaitedPersist() {
    if (_isWidgetTest) {
      return;
    }
    _persist();
  }

  Future<void> _persist() async {
    if (_isWidgetTest) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'selected': _selected,
          'tabs': _tabs.map((tab) => tab.toJson()).toList(),
        }),
      );
    } catch (error) {
      debugPrint('Watchlist persist failed: $error');
    }
  }

  bool get _isWidgetTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString() ==
          'AutomatedTestWidgetsFlutterBinding';
    } catch (_) {
      return true;
    }
  }

  static List<WatchlistTab> _defaultTabs() {
    return [
      WatchlistTab(id: '1', name: defaultTabName(1), stocks: _seedStocks()),
      WatchlistTab(id: '2', name: defaultTabName(2)),
      WatchlistTab(id: '3', name: defaultTabName(3)),
      WatchlistTab(id: '4', name: defaultTabName(4)),
      WatchlistTab(id: '5', name: defaultTabName(5)),
    ];
  }

  static List<WatchlistStock> _seedStocks() {
    return [
      const WatchlistStock(
        symbol: 'RELIANCE',
        name: 'Reliance Industries',
        token: '1_2885',
        ltp: 2912.40,
        change: 34.15,
        isin: 'INE002A01018',
      ),
      const WatchlistStock(
        symbol: 'TCS',
        name: 'Tata Consultancy',
        token: '1_11536',
        ltp: 4186.20,
        change: -22.80,
        isin: 'INE467B01029',
      ),
      const WatchlistStock(
        symbol: 'HDFCBANK',
        name: 'HDFC Bank',
        token: '1_1333',
        ltp: 1678.55,
        change: 12.40,
        isin: 'INE040A01034',
      ),
      const WatchlistStock(
        symbol: 'INFY',
        name: 'Infosys',
        token: '1_1594',
        ltp: 1874.90,
        change: -8.35,
        isin: 'INE009A01021',
      ),
      const WatchlistStock(
        symbol: 'SBIN',
        name: 'State Bank of India',
        token: '1_3045',
        ltp: 812.15,
        change: 6.70,
        isin: 'INE062A01020',
      ),
      const WatchlistStock(
        symbol: 'ITC',
        name: 'ITC Limited',
        token: '1_1660',
        ltp: 492.30,
        change: -1.25,
        isin: 'INE154A01025',
      ),
    ];
  }
}
