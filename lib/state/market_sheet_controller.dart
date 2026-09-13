import 'package:flutter/foundation.dart';

import '../models/watchlist_stock.dart';

enum MarketSheetKind { detail, chain }

class MarketSheetController extends ChangeNotifier {
  String? _detailToken;
  WatchlistStock? _detailFallback;
  String? _chainUnderlying;
  var _chainSpot = 0.0;
  MarketSheetKind? _top;

  String? get detailToken => _detailToken;
  WatchlistStock? get detailFallback => _detailFallback;
  String? get chainUnderlying => _chainUnderlying;
  double get chainSpot => _chainSpot;
  MarketSheetKind? get top => _top;

  bool get detailOpen => _detailToken != null && _detailToken!.isNotEmpty;
  bool get chainOpen =>
      _chainUnderlying != null && _chainUnderlying!.isNotEmpty;
  bool get anyOpen => detailOpen || chainOpen;

  void openDetail({required String token, WatchlistStock? fallback}) {
    _detailToken = token;
    _detailFallback = fallback;
    _top = MarketSheetKind.detail;
    notifyListeners();
  }

  void openChain({required String underlying, required double spot}) {
    _chainUnderlying = underlying;
    _chainSpot = spot;
    _detailToken = null;
    _detailFallback = null;
    _top = MarketSheetKind.chain;
    notifyListeners();
  }

  void closeTop() {
    if (_top == MarketSheetKind.detail) {
      closeDetail();
      return;
    }
    if (_top == MarketSheetKind.chain) {
      closeChain();
    }
  }

  void closeDetail() {
    _detailToken = null;
    _detailFallback = null;
    _top = chainOpen ? MarketSheetKind.chain : null;
    notifyListeners();
  }

  void closeChain() {
    _chainUnderlying = null;
    _top = detailOpen ? MarketSheetKind.detail : null;
    notifyListeners();
  }
}
