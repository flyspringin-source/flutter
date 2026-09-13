import 'watchlist_stock.dart';

class WatchlistTab {
  WatchlistTab({
    required this.id,
    required this.name,
    List<WatchlistStock>? stocks,
  }) : stocks = List<WatchlistStock>.from(stocks ?? const []);

  final String id;
  String name;
  final List<WatchlistStock> stocks;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'stocks': stocks.map((item) => item.toJson()).toList(),
    };
  }

  factory WatchlistTab.fromJson(Map<dynamic, dynamic> json) {
    final raw = json['stocks'];
    return WatchlistTab(
      id: json['id'] as String? ?? UniqueKeyName.next(),
      name: json['name'] as String? ?? '1',
      stocks: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) WatchlistStock.fromJson(item),
      ],
    );
  }
}

class UniqueKeyName {
  static var _n = 0;

  static String next() {
    _n += 1;
    return 'wl-${DateTime.now().millisecondsSinceEpoch}-$_n';
  }
}
