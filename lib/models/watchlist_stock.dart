import '../data/scrip_catalog.dart';
import 'market_quote.dart';

class WatchlistStock {
  const WatchlistStock({
    required this.symbol,
    required this.name,
    required this.token,
    required this.ltp,
    required this.change,
    this.open,
    this.high,
    this.low,
    this.close,
    this.week52High,
    this.week52Low,
    this.lowerCircuit,
    this.upperCircuit,
    this.buyDepth = const [],
    this.sellDepth = const [],
    this.underlying = '',
    this.isin = '',
    this.kind = ScripKind.equity,
    this.exchange = 'NSE',
  });

  final String symbol;
  final String name;
  final String token;
  final double ltp;
  final double change;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? week52High;
  final double? week52Low;
  final double? lowerCircuit;
  final double? upperCircuit;
  final List<DepthLevel> buyDepth;
  final List<DepthLevel> sellDepth;
  final String underlying;
  final String isin;
  final ScripKind kind;
  final String exchange;

  String get chainSymbol {
    if (underlying.trim().isNotEmpty) {
      return underlying.trim();
    }
    return symbol;
  }

  bool get isUp => change >= 0;

  double get changePercent {
    final prev = ltp - change;
    if (prev == 0) {
      return 0;
    }
    return (change / prev) * 100;
  }

  double get previousClose {
    if (close != null && close! > 0) {
      return close!;
    }
    final inferred = ltp - change;
    return inferred > 0 ? inferred : ltp;
  }

  double get displayLowerCircuit {
    if (lowerCircuit != null && lowerCircuit! > 0) {
      return lowerCircuit!;
    }
    return previousClose * 0.90;
  }

  double get displayUpperCircuit {
    if (upperCircuit != null && upperCircuit! > 0) {
      return upperCircuit!;
    }
    return previousClose * 1.10;
  }

  WatchlistStock copyWith({
    double? ltp,
    double? change,
    double? open,
    double? high,
    double? low,
    double? close,
    double? week52High,
    double? week52Low,
    double? lowerCircuit,
    double? upperCircuit,
    List<DepthLevel>? buyDepth,
    List<DepthLevel>? sellDepth,
    String? underlying,
  }) {
    return WatchlistStock(
      symbol: symbol,
      name: name,
      token: token,
      ltp: ltp ?? this.ltp,
      change: change ?? this.change,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      week52High: week52High ?? this.week52High,
      week52Low: week52Low ?? this.week52Low,
      lowerCircuit: lowerCircuit ?? this.lowerCircuit,
      upperCircuit: upperCircuit ?? this.upperCircuit,
      buyDepth: buyDepth ?? this.buyDepth,
      sellDepth: sellDepth ?? this.sellDepth,
      underlying: underlying ?? this.underlying,
      isin: isin,
      kind: kind,
      exchange: exchange,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'token': token,
      'ltp': ltp,
      'change': change,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'underlying': underlying,
      'isin': isin,
      'kind': kind.name,
      'exchange': exchange,
    };
  }

  factory WatchlistStock.fromJson(Map<dynamic, dynamic> json) {
    return WatchlistStock(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      token: json['token'] as String? ?? '',
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      open: (json['open'] as num?)?.toDouble(),
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
      close: (json['close'] as num?)?.toDouble(),
      underlying: json['underlying'] as String? ?? '',
      isin: json['isin'] as String? ?? '',
      kind: ScripKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => ScripKind.equity,
      ),
      exchange: json['exchange'] as String? ?? 'NSE',
    );
  }

  factory WatchlistStock.fromScrip(ScripInfo scrip, {MarketQuote? quote}) {
    return WatchlistStock(
      symbol: scrip.displaySymbol,
      name: scrip.subtitle,
      token: scrip.token,
      ltp: quote?.ltp ?? 0,
      change: quote?.change ?? 0,
      open: quote?.open,
      high: quote?.high,
      low: quote?.low,
      close: quote?.close,
      week52High: quote?.week52High,
      week52Low: quote?.week52Low,
      lowerCircuit: quote?.lowerCircuit,
      upperCircuit: quote?.upperCircuit,
      buyDepth: quote?.buyDepth ?? const [],
      sellDepth: quote?.sellDepth ?? const [],
      underlying: scrip.symbol,
      isin: scrip.isin,
      kind: scrip.kind,
      exchange: scrip.exchange,
    );
  }
}
