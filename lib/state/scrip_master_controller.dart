import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../data/scrip_catalog.dart';
import '../data/scrip_master_parser.dart';
import '../data/scrip_master_service.dart';
import '../models/option_strike.dart';

class ScripMasterController extends ChangeNotifier {
  ScripMasterController({this.loader, List<ScripInfo>? initialItems})
      : _items = List<ScripInfo>.from(initialItems ?? seedScripCatalog);

  final Future<ScripMasterFetchResult> Function()? loader;

  List<ScripInfo> _items;
  var _loading = false;
  var _loaded = false;
  var _started = false;
  String? _error;
  String? _loadedDate;
  final _prefix = <String, List<int>>{};
  final _hays = <String>[];
  Timer? _dateWatch;

  List<ScripInfo> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  int get count => _items.length;

  ScripInfo? byToken(String token) {
    for (final item in _items) {
      if (item.token == token) {
        return item;
      }
    }
    return null;
  }

  ScripInfo? lookupSymbol(String symbol) {
    final key = symbol.trim().toUpperCase();
    if (key.isEmpty) {
      return null;
    }
    ScripInfo? equity;
    ScripInfo? index;
    ScripInfo? exact;
    for (final item in _items) {
      if (item.displaySymbol.toUpperCase() == key) {
        return item;
      }
      if (item.symbol.toUpperCase() != key) {
        continue;
      }
      exact ??= item;
      if (item.kind == ScripKind.equity) {
        equity = item;
      } else if (item.kind == ScripKind.idx) {
        index ??= item;
      }
    }
    if (equity != null) {
      return equity;
    }
    if (index != null) {
      return index;
    }
    if (exact != null) {
      return exact;
    }
    final hits = search(query: key, limit: 8);
    return hits.isEmpty ? null : hits.first;
  }

  Future<void> load() async {
    if (_started || _isWidgetTest) {
      return;
    }
    _started = true;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final today = scripMasterDateKey();
      String? cacheDir;
      if (loader == null) {
        cacheDir = (await getApplicationDocumentsDirectory()).path;
      }
      final result = await (loader != null
          ? loader!()
          : fetchScripMasters(cacheDir: cacheDir));
      if (result.items.isNotEmpty) {
        _items = mergeScripInfos([...seedScripCatalog, ...result.items]);
        _loaded = true;
        _loadedDate = today;
        _rebuildSearchIndex();
      }
      _error = result.error;
      _watchDate();
    } catch (error) {
      _error = '$error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void refreshIfDateChanged() {
    final today = scripMasterDateKey();
    if (_loadedDate == today) {
      return;
    }
    _started = false;
    unawaited(load());
  }

  void _watchDate() {
    _dateWatch?.cancel();
    _dateWatch = Timer.periodic(const Duration(minutes: 15), (_) {
      refreshIfDateChanged();
    });
  }

  List<String> websocketTokens({
    required Iterable<String> extraTokens,
    required Iterable<String> indexSymbols,
  }) {
    final tokens = <String>{...extraTokens};
    for (final symbol in indexSymbols) {
      final key = symbol.trim().toUpperCase();
      if (key.isEmpty) {
        continue;
      }
      for (final item in _items) {
        if (item.kind == ScripKind.idx && item.symbol.toUpperCase() == key) {
          tokens.add(item.token);
        }
        if (item.kind == ScripKind.option && item.symbol.toUpperCase() == key) {
          tokens.add(item.token);
        }
      }
    }
    return tokens.toList();
  }

  void _rebuildSearchIndex() {
    _prefix.clear();
    _hays
      ..clear()
      ..addAll([
        for (final item in _items)
          '${item.displaySymbol} ${item.symbol} ${item.name} ${item.exchange} '
                  '${item.kindLabel} ${item.expiry} ${item.optionType} '
                  '${item.strike ?? ''}'
              .toLowerCase(),
      ]);
    for (var i = 0; i < _items.length; i++) {
      final symbol = _items[i].symbol.toLowerCase();
      final display = _items[i].displaySymbol.toLowerCase();
      for (final text in {symbol, display}) {
        for (var n = 1; n <= 3 && n <= text.length; n++) {
          final key = text.substring(0, n);
          final bucket = _prefix[key];
          if (bucket == null) {
            _prefix[key] = [i];
          } else if (bucket.isEmpty || bucket.last != i) {
            bucket.add(i);
          }
        }
      }
    }
  }

  List<ScripInfo> search({
    required String query,
    ScripKind? kind,
    int limit = 100,
    Set<String> excludeTokens = const {},
  }) {
    final needle = query.trim().toLowerCase();
    final parts = needle
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (_hays.length != _items.length) {
      _rebuildSearchIndex();
    }
    Iterable<int> indexes;
    if (parts.isNotEmpty) {
      final prefix = parts.first.length >= 2
          ? parts.first.substring(0, 2)
          : parts.first;
      indexes = _prefix[prefix] ?? Iterable<int>.generate(_items.length);
      indexes = indexes.where((index) {
        if (excludeTokens.contains(_items[index].token)) {
          return false;
        }
        if (kind != null && _items[index].kind != kind) {
          return false;
        }
        return parts.every(_hays[index].contains);
      });
    } else {
      indexes = Iterable<int>.generate(_items.length).where((index) {
        if (excludeTokens.contains(_items[index].token)) {
          return false;
        }
        if (kind != null) {
          return _items[index].kind == kind;
        }
        return _items[index].kind == ScripKind.idx ||
            _items[index].kind == ScripKind.equity;
      });
    }
    final ranked = [for (final index in indexes) _items[index]]
      ..sort((left, right) => _compare(left, right, needle));
    if (ranked.length <= limit) {
      return ranked;
    }
    return ranked.sublist(0, limit);
  }

  int lotSizeFor(String token, String symbol) {
    final item = byToken(token);
    if (item != null && item.lotSize > 0) {
      return item.lotSize;
    }
    return defaultLotSize(symbol);
  }

  bool hasOptionChain(String underlying) {
    return _optionsFor(underlying).isNotEmpty;
  }

  List<String> expiriesFor(String underlying) {
    final dates = _optionsFor(underlying)
        .map((item) => item.expiry)
        .where((expiry) => expiry.isNotEmpty)
        .toSet()
        .toList();
    dates.sort((left, right) {
      final leftDate = parseExpiryDate(left);
      final rightDate = parseExpiryDate(right);
      if (leftDate != null && rightDate != null) {
        return leftDate.compareTo(rightDate);
      }
      return left.compareTo(right);
    });
    return dates;
  }

  List<OptionStrike> chainFor(String underlying, String expiry) {
    final options = _optionsFor(underlying).where((item) => item.expiry == expiry);
    final byStrike = <double, OptionStrike>{};
    for (final option in options) {
      final strike = option.strike;
      if (strike == null) {
        continue;
      }
      final current = byStrike[strike] ?? OptionStrike(strike: strike);
      if (option.optionType == 'CE') {
        byStrike[strike] = OptionStrike(
          strike: strike,
          callToken: option.token,
          putToken: current.putToken,
        );
      } else if (option.optionType == 'PE') {
        byStrike[strike] = OptionStrike(
          strike: strike,
          callToken: current.callToken,
          putToken: option.token,
        );
      }
    }
    final rows = byStrike.values.toList()
      ..sort((left, right) => left.strike.compareTo(right.strike));
    return rows;
  }

  List<ScripInfo> _optionsFor(String underlying) {
    final key = underlying.trim().toUpperCase();
    if (key.isEmpty) {
      return const [];
    }
    return _items
        .where(
          (item) =>
              item.kind == ScripKind.option && item.symbol.toUpperCase() == key,
        )
        .toList();
  }

  int _compare(ScripInfo left, ScripInfo right, String query) {
    final kindDelta = left.kind.index - right.kind.index;
    if (kindDelta != 0) {
      return kindDelta;
    }
    if (query.isNotEmpty) {
      final leftRank = _textRank(left, query);
      final rightRank = _textRank(right, query);
      if (leftRank != rightRank) {
        return leftRank - rightRank;
      }
    }
    final symbolDelta = left.symbol.compareTo(right.symbol);
    if (symbolDelta != 0) {
      return symbolDelta;
    }
    return left.displaySymbol.compareTo(right.displaySymbol);
  }

  int _textRank(ScripInfo item, String query) {
    final symbol = item.symbol.toLowerCase();
    if (symbol == query) {
      return 0;
    }
    if (symbol.startsWith(query)) {
      return 1;
    }
    if (item.displaySymbol.toLowerCase().startsWith(query)) {
      return 2;
    }
    return 3;
  }

  @override
  void dispose() {
    _dateWatch?.cancel();
    super.dispose();
  }

  bool get _isWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString() ==
        'AutomatedTestWidgetsFlutterBinding';
  }
}
