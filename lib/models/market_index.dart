class MarketIndex {
  const MarketIndex({
    required this.id,
    required this.name,
    required this.token,
    required this.ltp,
    required this.change,
    this.open,
    this.high,
    this.low,
    this.close,
  });

  final String id;
  final String name;
  final String token;
  final double ltp;
  final double change;
  final double? open;
  final double? high;
  final double? low;
  final double? close;

  double get changePercent => ltp == 0 ? 0 : (change / (ltp - change)) * 100;

  bool get isUp => change >= 0;

  double get prevClose {
    if (close != null && close! > 0) {
      return close!;
    }
    return ltp - change;
  }

  String get scripSymbol {
    switch (id) {
      case 'sensex':
        return 'SENSEX';
      case 'nifty':
        return 'NIFTY';
      case 'banknifty':
        return 'BANKNIFTY';
      case 'finnifty':
        return 'FINNIFTY';
      case 'midnifty':
        return 'MIDCPNIFTY';
      case 'bankex':
        return 'BANKEX';
      default:
        return name.replaceAll(' ', '').toUpperCase();
    }
  }

  MarketIndex copyWith({
    double? ltp,
    double? change,
    double? open,
    double? high,
    double? low,
    double? close,
  }) {
    return MarketIndex(
      id: id,
      name: name,
      token: token,
      ltp: ltp ?? this.ltp,
      change: change ?? this.change,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
    );
  }
}
