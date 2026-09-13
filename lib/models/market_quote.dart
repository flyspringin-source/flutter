class DepthLevel {
  const DepthLevel({required this.price, required this.qty});

  final double price;
  final int qty;
}

class MarketQuote {
  const MarketQuote({
    required this.key,
    this.ltp,
    this.change,
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
    this.openInterest,
    this.openInterestChange,
    this.volume,
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
    this.iv,
  });

  final String key;
  final double? ltp;
  final double? change;
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
  final double? openInterest;
  final double? openInterestChange;
  final double? volume;
  final double? delta;
  final double? gamma;
  final double? theta;
  final double? vega;
  final double? iv;

  MarketQuote merge(MarketQuote next) {
    return MarketQuote(
      key: next.key,
      ltp: next.ltp ?? ltp,
      change: next.change ?? change,
      open: next.open ?? open,
      high: next.high ?? high,
      low: next.low ?? low,
      close: next.close ?? close,
      week52High: next.week52High ?? week52High,
      week52Low: next.week52Low ?? week52Low,
      lowerCircuit: next.lowerCircuit ?? lowerCircuit,
      upperCircuit: next.upperCircuit ?? upperCircuit,
      buyDepth: next.buyDepth.isEmpty ? buyDepth : next.buyDepth,
      sellDepth: next.sellDepth.isEmpty ? sellDepth : next.sellDepth,
      openInterest: next.openInterest ?? openInterest,
      openInterestChange: next.openInterestChange ?? openInterestChange,
      volume: next.volume ?? volume,
      delta: next.delta ?? delta,
      gamma: next.gamma ?? gamma,
      theta: next.theta ?? theta,
      vega: next.vega ?? vega,
      iv: next.iv ?? iv,
    );
  }
}

double? parseTagNumber(Map<String, String> tags, List<String> ids) {
  for (final id in ids) {
    final raw = tags[id];
    if (raw == null || raw.isEmpty) {
      continue;
    }
    final value = double.tryParse(raw);
    if (value != null) {
      return value;
    }
  }
  return null;
}

Map<String, String> parseOdinTags(String message) {
  final tags = <String, String>{};
  for (final part in message.split('|')) {
    if (part.isEmpty) {
      continue;
    }
    final eq = part.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    tags[part.substring(0, eq)] = part.substring(eq + 1);
  }
  return tags;
}

double? _scaled(Map<String, String> tags, List<String> ids, double scale) {
  final raw = parseTagNumber(tags, ids);
  if (raw == null || raw <= 0) {
    return null;
  }
  return raw / scale;
}

List<DepthLevel> _levels(
  Map<String, String> tags,
  List<String> priceTags,
  List<String> qtyTags,
  double scale,
) {
  final levels = <DepthLevel>[];
  for (var i = 0; i < priceTags.length; i++) {
    final price = _scaled(tags, [priceTags[i]], scale);
    final qty = parseTagNumber(tags, [qtyTags[i]])?.toInt() ?? 0;
    if (price == null || price <= 0) {
      continue;
    }
    levels.add(DepthLevel(price: price, qty: qty));
  }
  return levels;
}

MarketQuote? quoteFromOdinTags(Map<String, String> tags) {
  final segment = tags['1'];
  final token = tags['7'];
  if (segment == null || token == null || segment.isEmpty || token.isEmpty) {
    return null;
  }

  final locator = parseTagNumber(tags, const ['399']) ?? 100;
  final scale = locator == 0 ? 100.0 : locator;
  final ltp = _scaled(tags, const ['8'], scale) ??
      _scaled(tags, const ['76', '250'], scale);
  final close = _scaled(tags, const ['19', '76'], scale);
  final open = _scaled(tags, const ['16', '75', '11'], scale);
  final high = _scaled(tags, const ['17', '77'], scale);
  final low = _scaled(tags, const ['18', '78'], scale);
  final week52High = _scaled(tags, const ['248', '241', '332'], scale);
  final week52Low = _scaled(tags, const ['249', '242', '333'], scale);
  final upperCircuit = _scaled(tags, const ['114', '26', '119', '247'], scale);
  final lowerCircuit = _scaled(tags, const ['115', '27', '120', '246'], scale);

  double? change;
  final netRaw = parseTagNumber(tags, const ['418', '6']);
  if (ltp != null && netRaw != null) {
    final net = netRaw / scale;
    if (net.abs() < ltp * 0.5) {
      change = net;
    }
  }
  if (change == null && ltp != null && close != null && close > 0) {
    change = ltp - close;
  }

  var buyDepth = _levels(
    tags,
    const ['132', '133', '134', '135', '136'],
    const ['152', '153', '154', '155', '156'],
    scale,
  );
  var sellDepth = _levels(
    tags,
    const ['142', '143', '144', '145', '146'],
    const ['162', '163', '164', '165', '166'],
    scale,
  );
  if (buyDepth.isEmpty) {
    buyDepth = _levels(tags, const ['3'], const ['2'], scale);
  }
  if (sellDepth.isEmpty) {
    sellDepth = _levels(tags, const ['6'], const ['5'], scale);
  }

  // ODIN OI is tag 88. 407 is theta; 13/51 are volume / total sell qty.
  final openInterest = parseTagNumber(tags, const ['88', '87']);
  final volume = parseTagNumber(tags, const ['387', '14', '4', '15', '81']);

  if (ltp == null &&
      buyDepth.isEmpty &&
      sellDepth.isEmpty &&
      open == null &&
      openInterest == null &&
      volume == null) {
    return null;
  }

  return MarketQuote(
    key: '${segment}_$token',
    ltp: ltp,
    change: change,
    open: open,
    high: high,
    low: low,
    close: close,
    week52High: week52High,
    week52Low: week52Low,
    lowerCircuit: lowerCircuit,
    upperCircuit: upperCircuit,
    buyDepth: buyDepth,
    sellDepth: sellDepth,
    openInterest: openInterest,
    volume: volume,
  );
}

List<DepthLevel> syntheticDepth(double ltp, {required bool buy}) {
  if (ltp <= 0) {
    return const [];
  }
  final tick = ltp >= 1000 ? 0.50 : ltp >= 100 ? 0.10 : 0.05;
  final baseQty = ltp >= 1000 ? 250 : 1200;
  return List.generate(5, (index) {
    final step = index + 1;
    final price = buy ? ltp - tick * step : ltp + tick * step;
    return DepthLevel(
      price: price < 0 ? tick : price,
      qty: baseQty + index * 175,
    );
  });
}

List<String> extractOdinMessages(String text) {
  final clean = text.replaceAll(RegExp(r'\r?\n'), '');
  final parts = clean
      .split(RegExp('(?=63=)'))
      .where((part) => part.startsWith('63='))
      .toList();
  if (parts.isNotEmpty) {
    return parts;
  }
  return clean.contains('|') ? [clean] : const [];
}
