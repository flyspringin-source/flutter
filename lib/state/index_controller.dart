import 'package:flutter/foundation.dart';

import '../models/market_index.dart';
import '../models/market_quote.dart';

class IndexController extends ChangeNotifier {
  static const int maxSelected = 2;

  IndexController()
      : _indices = [
          const MarketIndex(
            id: 'sensex',
            name: 'SENSEX',
            token: '3_19000',
            ltp: 81124.50,
            change: 312.45,
          ),
          const MarketIndex(
            id: 'nifty',
            name: 'NIFTY 50',
            token: '1_26000',
            ltp: 24780.30,
            change: 98.20,
            open: 24720.15,
            high: 24815.40,
            low: 24640.80,
            close: 24682.10,
          ),
          const MarketIndex(
            id: 'banknifty',
            name: 'BANK NIFTY',
            token: '1_26009',
            ltp: 51240.15,
            change: -85.60,
          ),
          const MarketIndex(
            id: 'finnifty',
            name: 'FIN NIFTY',
            token: '1_26037',
            ltp: 23450.80,
            change: 45.30,
          ),
          const MarketIndex(
            id: 'midnifty',
            name: 'MID NIFTY',
            token: '1_26074',
            ltp: 12890.45,
            change: 120.15,
          ),
          const MarketIndex(
            id: 'bankex',
            name: 'BANKEX',
            token: '3_19012',
            ltp: 58210.70,
            change: -42.10,
          ),
        ],
        _selectedIds = ['sensex', 'nifty'];

  final List<MarketIndex> _indices;
  final List<String> _selectedIds;

  List<MarketIndex> get indices => List.unmodifiable(_indices);

  List<String> get tokens => _indices.map((index) => index.token).toList();

  /// Selected indices in market-list order so the header stays stable.
  List<MarketIndex> get selectedIndices {
    return _indices.where((index) => _selectedIds.contains(index.id)).toList();
  }

  bool isSelected(String id) => _selectedIds.contains(id);

  void toggleIndex(String id) {
    if (_selectedIds.contains(id)) {
      if (_selectedIds.length <= 1) {
        return;
      }
      _selectedIds.remove(id);
      notifyListeners();
      return;
    }

    if (_selectedIds.length >= maxSelected) {
      _selectedIds.removeLast();
    }
    _selectedIds.add(id);
    notifyListeners();
  }

  void applyQuote(MarketQuote quote) {
    applyQuotes([quote]);
  }

  void applyQuotes(Iterable<MarketQuote> quotes, {bool notify = true}) {
    var changed = false;
    for (final quote in quotes) {
      if (_applyQuote(quote)) {
        changed = true;
      }
    }
    if (changed && notify) {
      notifyListeners();
    }
  }

  bool _applyQuote(MarketQuote quote) {
    if (quote.ltp == null) {
      return false;
    }
    final index = _indices.indexWhere((item) => item.token == quote.key);
    if (index < 0) {
      return false;
    }
    final current = _indices[index];
    final nextChange = quote.change ?? current.change;
    final next = current.copyWith(
      ltp: quote.ltp,
      change: nextChange,
      open: quote.open,
      high: quote.high,
      low: quote.low,
      close: quote.close,
    );
    if (current.ltp == next.ltp &&
        current.change == next.change &&
        current.open == next.open &&
        current.high == next.high &&
        current.low == next.low &&
        current.close == next.close) {
      return false;
    }
    _indices[index] = next;
    return true;
  }
}
