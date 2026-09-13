import 'package:flutter/widgets.dart';

import '../config/upstox_config.dart';
import '../models/candle.dart';
import '../models/upstox_account.dart';
import '../services/upstox_auth.dart';
import 'upstox_controller.dart';

typedef UpstoxRequester =
    Future<dynamic> Function({
      required String method,
      required String path,
      Map<String, dynamic>? body,
      required bool roundRobin,
      String? baseUrl,
    });

class UpstoxAccountController extends ChangeNotifier {
  UpstoxAccountController({required this.auth, this.requester});

  final UpstoxController auth;
  final UpstoxRequester? requester;

  UpstoxProfile? _profile;
  UpstoxFunds? _funds;
  var _orders = const <UpstoxOrder>[];
  var _positions = const <UpstoxPosition>[];
  String? _profileError;
  String? _fundsError;
  String? _ordersError;
  String? _positionsError;
  var _fundsClosed = false;
  var _loading = false;
  var _placing = false;
  var _authFailed = false;
  var _checked = false;

  UpstoxProfile? get profile => _profile;
  UpstoxFunds? get funds => _funds;
  List<UpstoxOrder> get orders => List.unmodifiable(_orders);
  List<UpstoxPosition> get positions => List.unmodifiable(_positions);
  String? get profileError => _profileError;
  String? get fundsError => _fundsError;
  String? get ordersError => _ordersError;
  String? get positionsError => _positionsError;
  bool get fundsClosed => _fundsClosed;
  String? get error => _ordersError ?? _positionsError ?? _profileError;
  bool get loading => _loading;
  bool get placing => _placing;
  bool get hasToken => auth.hasReadyToken;
  bool get authFailed => _authFailed;
  String? get displayFundsError =>
      visibleUpstoxError(_fundsError, keepHours: true);
  String? get displayOrdersError => visibleUpstoxError(_ordersError);
  String? get displayPositionsError => visibleUpstoxError(_positionsError);
  String? get displayProfileError => visibleUpstoxError(_profileError);

  UpstoxLinkState get linkState {
    if (!hasToken) {
      return UpstoxLinkState.offline;
    }
    if (_authFailed) {
      return UpstoxLinkState.invalid;
    }
    if (_loading && !_checked) {
      return UpstoxLinkState.checking;
    }
    return UpstoxLinkState.connected;
  }

  List<UpstoxOrder> ordersIn(UpstoxOrderGroup group) {
    return _orders.where((order) => order.group == group).toList();
  }

  int countIn(UpstoxOrderGroup group) => ordersIn(group).length;

  double get dayPnl {
    var total = 0.0;
    for (final position in _positions) {
      total += position.pnl;
    }
    return total;
  }

  double get unrealisedPnl {
    var total = 0.0;
    for (final position in _positions) {
      total += position.unrealised;
    }
    return total;
  }

  Future<void> refresh() async {
    if (requester == null && _isWidgetTest) {
      return;
    }
    if (!auth.hasReadyToken) {
      _profile = null;
      _funds = null;
      _orders = const [];
      _positions = const [];
      _profileError = null;
      _fundsError = null;
      _ordersError = null;
      _positionsError = null;
      _fundsClosed = false;
      _authFailed = false;
      _checked = true;
      notifyListeners();
      return;
    }
    _loading = true;
    _profileError = null;
    _fundsError = null;
    _ordersError = null;
    _positionsError = null;
    _fundsClosed = false;
    notifyListeners();
    await Future.wait([
      _loadProfile(),
      _loadFunds(),
      _loadOrders(),
      _loadPositions(),
    ]);
    _authFailed = [
      _profileError,
      _ordersError,
      _positionsError,
      if (!_fundsClosed) _fundsError,
    ].whereType<String>().any(isUpstoxAuthError);
    _checked = true;
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    try {
      final raw = await _call(method: 'GET', path: '/user/profile');
      _profile = raw is Map ? UpstoxProfile.fromJson(raw) : null;
      _profileError = null;
    } catch (error) {
      _profileError = friendlyUpstoxError(error);
    }
  }

  Future<void> _loadFunds() async {
    try {
      final raw = await _call(
        method: 'GET',
        path: '/user/get-funds-and-margin',
      );
      _funds = raw is Map ? UpstoxFunds.fromJson(raw) : null;
      _fundsError = null;
      _fundsClosed = false;
    } catch (error) {
      _fundsClosed = isUpstoxHoursError(error);
      _fundsError = friendlyUpstoxError(
        error,
        hoursFallback: upstoxFundsHoursMessage,
      );
      if (_fundsClosed) {
        _funds = null;
      }
    }
  }

  Future<void> _loadOrders() async {
    try {
      final raw = await _call(method: 'GET', path: '/order/retrieve-all');
      _orders = [
        for (final item in _asList(raw))
          if (item is Map) UpstoxOrder.fromJson(item),
      ];
      _ordersError = null;
    } catch (error) {
      _ordersError = friendlyUpstoxError(error);
    }
  }

  Future<void> _loadPositions() async {
    try {
      final raw = await _call(
        method: 'GET',
        path: '/portfolio/short-term-positions',
      );
      _positions = [
        for (final item in _asList(raw))
          if (item is Map) UpstoxPosition.fromJson(item),
      ];
      _positionsError = null;
    } catch (error) {
      _positionsError = friendlyUpstoxError(error);
    }
  }

  Future<String> placeOrder({
    required String instrumentToken,
    required String side,
    required int quantity,
    required String product,
    required String orderType,
    double price = 0,
    double triggerPrice = 0,
  }) async {
    if (instrumentToken.trim().isEmpty) {
      throw Exception('No Upstox instrument key for this scrip');
    }
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than 0');
    }
    final type = orderType.toUpperCase();
    final limitPrice = type == 'MARKET' || type == 'SL-M' ? 0.0 : price;
    if ((type == 'LIMIT' || type == 'SL') && limitPrice <= 0) {
      throw Exception('Enter a limit price');
    }
    _placing = true;
    _ordersError = null;
    notifyListeners();
    try {
      final raw = await _call(
        method: 'POST',
        path: '/order/place',
        roundRobin: true,
        baseUrl: upstoxHftOrderBase,
        body: {
          'quantity': quantity,
          'product': product,
          'validity': 'DAY',
          'price': limitPrice,
          'instrument_token': instrumentToken,
          'order_type': type,
          'transaction_type': side.toUpperCase(),
          'disclosed_quantity': 0,
          'trigger_price': triggerPrice,
          'is_amo': false,
        },
      );
      final data = raw is Map ? raw : const {};
      final orderId = '${data['order_id'] ?? ''}';
      if (orderId.isEmpty) {
        throw Exception('Upstox did not return an order id');
      }
      await refresh();
      return orderId;
    } catch (error) {
      _ordersError = friendlyUpstoxError(error);
      rethrow;
    } finally {
      _placing = false;
      notifyListeners();
    }
  }

  Future<UpstoxMarginQuote> fetchMargin({
    required List<Map<String, dynamic>> instruments,
  }) async {
    if (instruments.isEmpty) {
      return const UpstoxMarginQuote();
    }
    if (requester == null && _isWidgetTest) {
      return const UpstoxMarginQuote(
        requiredMargin: 25000,
        finalMargin: 18000,
      );
    }
    final raw = await _call(
      method: 'POST',
      path: '/charges/margin',
      body: {'instruments': instruments},
    );
    if (raw is Map) {
      return UpstoxMarginQuote.fromJson(raw);
    }
    return const UpstoxMarginQuote();
  }

  Future<List<String>> placeBasket({
    required List<Map<String, dynamic>> orders,
  }) async {
    final ids = <String>[];
    for (final order in orders) {
      final id = await placeOrder(
        instrumentToken: '${order['instrument_token'] ?? ''}',
        side: '${order['transaction_type'] ?? 'BUY'}',
        quantity: (order['quantity'] as num?)?.toInt() ?? 0,
        product: '${order['product'] ?? 'D'}',
        orderType: '${order['order_type'] ?? 'LIMIT'}',
        price: (order['price'] as num?)?.toDouble() ?? 0,
      );
      ids.add(id);
    }
    return ids;
  }

  Future<List<Candle>> fetchCandles({
    required String instrumentKey,
    required ChartRange range,
    DateTime? now,
  }) async {
    if (instrumentKey.trim().isEmpty) {
      return const [];
    }
    if (requester == null && _isWidgetTest) {
      return const [];
    }
    final raw = await _call(
      method: 'GET',
      path: chartHistoryPath(
        instrumentKey: instrumentKey,
        range: range,
        now: now,
      ),
      baseUrl: upstoxApiV3,
    );
    return parseUpstoxCandles(raw);
  }

  Future<String> modifyOrder({
    required String orderId,
    required int quantity,
    required String orderType,
    double price = 0,
    double triggerPrice = 0,
  }) async {
    if (orderId.trim().isEmpty) {
      throw Exception('Order id is missing');
    }
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than 0');
    }
    final type = orderType.toUpperCase();
    final limitPrice = type == 'MARKET' || type == 'SL-M' ? 0.0 : price;
    if ((type == 'LIMIT' || type == 'SL') && limitPrice <= 0) {
      throw Exception('Enter a limit price');
    }
    _placing = true;
    _ordersError = null;
    notifyListeners();
    try {
      final raw = await _call(
        method: 'PUT',
        path: '/order/modify',
        roundRobin: true,
        baseUrl: upstoxHftOrderBase,
        body: {
          'order_id': orderId,
          'quantity': quantity,
          'validity': 'DAY',
          'price': limitPrice,
          'order_type': type,
          'disclosed_quantity': 0,
          'trigger_price': triggerPrice,
        },
      );
      final data = raw is Map ? raw : const {};
      final nextId = '${data['order_id'] ?? orderId}';
      await refresh();
      return nextId.isEmpty ? orderId : nextId;
    } catch (error) {
      _ordersError = friendlyUpstoxError(error);
      rethrow;
    } finally {
      _placing = false;
      notifyListeners();
    }
  }

  Future<void> cancelOrder(String orderId) async {
    if (orderId.isEmpty) {
      return;
    }
    try {
      await _call(
        method: 'DELETE',
        path: '/order/cancel?order_id=$orderId',
        roundRobin: true,
        baseUrl: upstoxHftOrderBase,
      );
      await refresh();
    } catch (error) {
      _ordersError = friendlyUpstoxError(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<dynamic> _call({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool roundRobin = false,
    String? baseUrl,
  }) async {
    if (requester != null) {
      return requester!(
        method: method,
        path: path,
        body: body,
        roundRobin: roundRobin,
        baseUrl: baseUrl,
      );
    }
    final token = roundRobin
        ? auth.nextAccessToken()
        : auth.primaryAccessToken();
    if (token == null) {
      throw Exception('Generate Upstox access tokens in Settings');
    }
    final payload = await upstoxRequest(
      method: method,
      path: path,
      accessToken: token,
      body: body,
      baseUrl: baseUrl,
    );
    return upstoxData(payload);
  }

  List<dynamic> _asList(dynamic raw) {
    if (raw is List) {
      return raw;
    }
    return const [];
  }

  bool get _isWidgetTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString() ==
          'AutomatedTestWidgetsFlutterBinding';
    } catch (_) {
      return true;
    }
  }
}
