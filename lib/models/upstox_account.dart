enum UpstoxOrderGroup { pending, executed, cancelled, rejected }

enum UpstoxLinkState { offline, checking, connected, invalid }

class UpstoxProfile {
  const UpstoxProfile({
    required this.userName,
    required this.userId,
    this.email = '',
    this.exchanges = const [],
  });

  final String userName;
  final String userId;
  final String email;
  final List<String> exchanges;

  String get initials {
    final parts = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return userId.isEmpty ? '?' : userId[0].toUpperCase();
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory UpstoxProfile.fromJson(Map<dynamic, dynamic> json) {
    return UpstoxProfile(
      userName: json['user_name'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      exchanges: [
        for (final item in (json['exchanges'] as List?) ?? const []) '$item',
      ],
    );
  }
}

class UpstoxFunds {
  const UpstoxFunds({
    required this.availableMargin,
    required this.usedMargin,
    required this.collateral,
  });

  final double availableMargin;
  final double usedMargin;
  final double collateral;

  factory UpstoxFunds.fromJson(Map<dynamic, dynamic> json) {
    final equity = json['equity'] is Map
        ? Map<dynamic, dynamic>.from(json['equity'] as Map)
        : json;
    final adhoc = _num(equity['adhoc_margin']);
    final notional = _num(equity['notional_cash']);
    return UpstoxFunds(
      availableMargin: _num(equity['available_margin']),
      usedMargin: _num(equity['used_margin']),
      collateral: adhoc + notional,
    );
  }
}

class UpstoxMarginQuote {
  const UpstoxMarginQuote({
    this.requiredMargin = 0,
    this.finalMargin = 0,
  });

  final double requiredMargin;
  final double finalMargin;

  double get benefit =>
      requiredMargin > finalMargin ? requiredMargin - finalMargin : 0;

  factory UpstoxMarginQuote.fromJson(Map<dynamic, dynamic> json) {
    final data = json['data'] is Map
        ? Map<dynamic, dynamic>.from(json['data'] as Map)
        : json;
    final requiredMargin = _num(data['required_margin']);
    return UpstoxMarginQuote(
      requiredMargin: requiredMargin,
      finalMargin: _num(
        data['final_margin'] == null || _num(data['final_margin']) == 0
            ? requiredMargin
            : data['final_margin'],
      ),
    );
  }
}

class UpstoxOrder {
  const UpstoxOrder({
    required this.orderId,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.price,
    required this.status,
    required this.group,
    this.product = '',
    this.orderType = '',
    this.averagePrice = 0,
    this.filledQuantity = 0,
    this.pendingQuantity = 0,
    this.statusMessage = '',
    this.timestamp = '',
    this.instrumentToken = '',
    this.triggerPrice = 0,
  });

  final String orderId;
  final String symbol;
  final String side;
  final int quantity;
  final double price;
  final String status;
  final UpstoxOrderGroup group;
  final String product;
  final String orderType;
  final double averagePrice;
  final int filledQuantity;
  final int pendingQuantity;
  final String statusMessage;
  final String timestamp;
  final String instrumentToken;
  final double triggerPrice;

  bool get canCancel => group == UpstoxOrderGroup.pending && orderId.isNotEmpty;

  bool get canModify => canCancel;

  factory UpstoxOrder.fromJson(Map<dynamic, dynamic> json) {
    final status = '${json['status'] ?? ''}';
    return UpstoxOrder(
      orderId: '${json['order_id'] ?? ''}',
      symbol:
          '${json['trading_symbol'] ?? json['tradingsymbol'] ?? json['symbol'] ?? ''}',
      side: '${json['transaction_type'] ?? ''}'.toUpperCase(),
      quantity: _num(json['quantity']).round(),
      price: _num(json['price']),
      status: status,
      group: groupUpstoxOrder(status),
      product: '${json['product'] ?? ''}',
      orderType: '${json['order_type'] ?? ''}',
      averagePrice: _num(json['average_price']),
      filledQuantity: _num(json['filled_quantity']).round(),
      pendingQuantity: _num(json['pending_quantity']).round(),
      statusMessage: '${json['status_message'] ?? ''}',
      timestamp: '${json['order_timestamp'] ?? json['exchange_timestamp'] ?? ''}',
      instrumentToken: '${json['instrument_token'] ?? ''}',
      triggerPrice: _num(json['trigger_price']),
    );
  }
}

class UpstoxPosition {
  const UpstoxPosition({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
    required this.lastPrice,
    required this.pnl,
    required this.unrealised,
    required this.realised,
    this.instrumentToken = '',
    this.product = '',
    this.buyQuantity = 0,
    this.buyPrice = 0,
    this.sellQuantity = 0,
    this.sellPrice = 0,
    this.overnightQuantity = 0,
  });

  final String symbol;
  final int quantity;
  final double averagePrice;
  final double lastPrice;
  final double pnl;
  final double unrealised;
  final double realised;
  final String instrumentToken;
  final String product;
  final int buyQuantity;
  final double buyPrice;
  final int sellQuantity;
  final double sellPrice;
  final int overnightQuantity;

  String get productLabel {
    switch (product.toUpperCase()) {
      case 'I':
        return 'Intraday';
      case 'D':
        return 'Delivery';
      case 'MTF':
        return 'MTF';
      default:
        return product.isEmpty ? 'Position' : product;
    }
  }

  factory UpstoxPosition.fromJson(Map<dynamic, dynamic> json) {
    final unrealised = _num(json['unrealised']);
    final realised = _num(json['realised']);
    final pnl = json['pnl'] == null ? unrealised + realised : _num(json['pnl']);
    final quantity = _num(json['quantity']).round();
    final overnight = _num(json['overnight_quantity']).round();
    final dayBuyQty = _num(json['day_buy_quantity']).round();
    final daySellQty = _num(json['day_sell_quantity']).round();
    final dayBuyPrice = _num(json['day_buy_price']);
    final daySellPrice = _num(json['day_sell_price']);
    final average = _num(json['average_price']);
    final buyQuantity = dayBuyQty > 0
        ? dayBuyQty
        : (quantity > 0 ? (overnight != 0 ? overnight.abs() : quantity.abs()) : 0);
    final sellQuantity = daySellQty > 0
        ? daySellQty
        : (quantity < 0 ? (overnight != 0 ? overnight.abs() : quantity.abs()) : 0);
    return UpstoxPosition(
      symbol: '${json['trading_symbol'] ?? json['tradingsymbol'] ?? ''}',
      quantity: quantity,
      averagePrice: average,
      lastPrice: _num(json['last_price']),
      pnl: pnl,
      unrealised: unrealised,
      realised: realised,
      instrumentToken: '${json['instrument_token'] ?? ''}',
      product: '${json['product'] ?? ''}',
      buyQuantity: buyQuantity,
      buyPrice: dayBuyPrice > 0 ? dayBuyPrice : (buyQuantity > 0 ? average : 0),
      sellQuantity: sellQuantity,
      sellPrice: daySellPrice > 0
          ? daySellPrice
          : (sellQuantity > 0 ? average : 0),
      overnightQuantity: overnight,
    );
  }
}

UpstoxOrderGroup groupUpstoxOrder(String status) {
  final value = status.toLowerCase().trim();
  if (value.contains('reject')) {
    return UpstoxOrderGroup.rejected;
  }
  if (value.contains('cancel')) {
    return UpstoxOrderGroup.cancelled;
  }
  if (value == 'complete' ||
      value == 'completed' ||
      value == 'executed' ||
      value == 'filled') {
    return UpstoxOrderGroup.executed;
  }
  return UpstoxOrderGroup.pending;
}

String upstoxOrderGroupLabel(UpstoxOrderGroup group) {
  switch (group) {
    case UpstoxOrderGroup.pending:
      return 'Pending';
    case UpstoxOrderGroup.executed:
      return 'Executed';
    case UpstoxOrderGroup.cancelled:
      return 'Cancelled';
    case UpstoxOrderGroup.rejected:
      return 'Rejected';
  }
}

double _num(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
}

const upstoxFundsHoursMessage =
    'Funds are available 5:30 AM – 12:00 AM IST.';

bool isUpstoxAuthError(Object error) {
  final text = '$error'.toLowerCase();
  return text.contains('invalid token') ||
      text.contains('token used to access') ||
      text.contains('token expired') ||
      text.contains('unauthorized') ||
      text.contains('unauthorised') ||
      text.contains('unauthenticated') ||
      (text.contains('access token') &&
          (text.contains('invalid') ||
              text.contains('expired') ||
              text.contains('missing')));
}

String? visibleUpstoxError(String? error, {bool keepHours = false}) {
  if (error == null || error.isEmpty) {
    return null;
  }
  if (isUpstoxAuthError(error)) {
    return null;
  }
  if (!keepHours && isUpstoxHoursError(error)) {
    return null;
  }
  return error;
}

String upstoxLinkLabel(UpstoxLinkState state) {
  switch (state) {
    case UpstoxLinkState.connected:
      return 'Upstox connected';
    case UpstoxLinkState.invalid:
      return 'Upstox token invalid';
    case UpstoxLinkState.checking:
      return 'Checking Upstox';
    case UpstoxLinkState.offline:
      return 'Upstox not connected';
  }
}

bool isUpstoxHoursError(Object error) {
  final text = '$error'.toLowerCase();
  return text.contains('service hours') ||
      text.contains('try again during') ||
      text.contains('accessiable') ||
      text.contains('accessible from') ||
      text.contains('5.30 am') ||
      text.contains('5:30 am');
}

String friendlyUpstoxError(Object error, {String? hoursFallback}) {
  final raw = '$error'.replaceFirst(RegExp(r'^Exception:\s*'), '');
  if (!isUpstoxHoursError(raw)) {
    return raw;
  }
  if (raw.toLowerCase().contains('fund')) {
    return upstoxFundsHoursMessage;
  }
  return hoursFallback ??
      'This Upstox service is closed right now. Try again during service hours.';
}
