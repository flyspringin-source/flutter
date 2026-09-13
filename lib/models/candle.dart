import 'dart:math' as math;

enum ChartRange {
  m1('1m', true),
  m5('5m', true),
  m15('15m', true),
  m30('30m', true),
  h1('1H', true),
  day('1D', false),
  week('1W', false),
  month('1M', false),
  months3('3M', false),
  year('1Y', false);

  const ChartRange(this.label, this.intraday);
  final String label;
  final bool intraday;
}

enum ChartStyle { line, candle }

class Candle {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  bool get isUp => close >= open;

  Candle copyWith({
    DateTime? time,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
  }) {
    return Candle(
      time: time ?? this.time,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
    );
  }
}

List<Candle> parseUpstoxCandles(dynamic raw) {
  final rows = raw is Map ? raw['candles'] : raw;
  if (rows is! List) {
    return const [];
  }
  final candles = <Candle>[];
  for (final row in rows) {
    if (row is! List || row.length < 5) {
      continue;
    }
    final time = DateTime.tryParse('${row[0]}');
    final open = _asDouble(row[1]);
    final high = _asDouble(row[2]);
    final low = _asDouble(row[3]);
    final close = _asDouble(row[4]);
    final volume = row.length > 5 ? _asDouble(row[5]) : 0.0;
    if (time == null || close <= 0) {
      continue;
    }
    candles.add(
      Candle(
        time: time,
        open: open > 0 ? open : close,
        high: math.max(high, close),
        low: low > 0 ? math.min(low, close) : close,
        close: close,
        volume: volume,
      ),
    );
  }
  candles.sort((left, right) => left.time.compareTo(right.time));
  return candles;
}

List<Candle> applyLiveClose(List<Candle> candles, double ltp) {
  if (candles.isEmpty || ltp <= 0) {
    return candles;
  }
  final last = candles.last;
  return [
    ...candles.sublist(0, candles.length - 1),
    last.copyWith(
      close: ltp,
      high: math.max(last.high, ltp),
      low: last.low <= 0 ? ltp : math.min(last.low, ltp),
    ),
  ];
}

List<Candle> applyLivePrice(
  List<Candle> candles,
  double ltp, {
  required ChartRange range,
  DateTime? now,
}) {
  if (ltp <= 0) {
    return candles;
  }
  final clock = now ?? DateTime.now();
  if (candles.isEmpty) {
    return [
      Candle(time: clock, open: ltp, high: ltp, low: ltp, close: ltp),
    ];
  }
  final last = candles.last;
  final step = _stepFor(range);
  if (clock.difference(last.time) >= step) {
    final aligned = DateTime(
      clock.year,
      clock.month,
      clock.day,
      clock.hour,
      range.intraday ? (clock.minute - clock.minute % _minuteBucket(range)) : 0,
    );
    return [
      ...candles,
      Candle(
        time: aligned.isAfter(last.time) ? aligned : last.time.add(step),
        open: ltp,
        high: ltp,
        low: ltp,
        close: ltp,
      ),
    ];
  }
  return applyLiveClose(candles, ltp);
}

Duration _stepFor(ChartRange range) {
  return switch (range) {
    ChartRange.m1 => const Duration(minutes: 1),
    ChartRange.m5 => const Duration(minutes: 5),
    ChartRange.m15 => const Duration(minutes: 15),
    ChartRange.m30 => const Duration(minutes: 30),
    ChartRange.h1 => const Duration(hours: 1),
    ChartRange.day => const Duration(days: 1),
    ChartRange.week => const Duration(days: 7),
    ChartRange.month => const Duration(days: 30),
    ChartRange.months3 => const Duration(days: 1),
    ChartRange.year => const Duration(days: 7),
  };
}

int _minuteBucket(ChartRange range) {
  return switch (range) {
    ChartRange.m1 => 1,
    ChartRange.m5 => 5,
    ChartRange.m15 => 15,
    ChartRange.m30 => 30,
    ChartRange.h1 => 60,
    _ => 1,
  };
}

List<Candle> fallbackCandles({
  required String symbol,
  required double ltp,
  required double change,
  double? open,
  double? high,
  double? low,
  double? close,
  required ChartRange range,
  DateTime? now,
}) {
  final end = now ?? DateTime.now();
  final prev = close != null && close > 0
      ? close
      : math.max(ltp - change, ltp * 0.99);
  final sessionOpen = open != null && open > 0 ? open : prev;
  final sessionHigh = high != null && high > 0
      ? high
      : math.max(ltp, sessionOpen) * 1.004;
  final sessionLow = low != null && low > 0
      ? low
      : math.min(ltp, sessionOpen) * 0.996;
  final count = switch (range) {
    ChartRange.m1 => 75,
    ChartRange.m5 => 78,
    ChartRange.m15 => 40,
    ChartRange.m30 => 24,
    ChartRange.h1 => 24,
    ChartRange.day => 78,
    ChartRange.week => 35,
    ChartRange.month => 22,
    ChartRange.months3 => 63,
    ChartRange.year => 52,
  };
  final step = _stepFor(range);
  final seed = symbol.hashCode;
  final start = end.subtract(step * (count - 1));
  final candles = <Candle>[];
  var previous = sessionOpen;
  for (var i = 0; i < count; i++) {
    final t = count == 1 ? 1.0 : i / (count - 1);
    final wave =
        0.38 * math.sin((t * 6.2) + (seed % 17) / 6) +
        0.18 * math.sin((t * 13.5) + (seed % 11) / 4);
    final towardHigh = (1 - (t - 0.32).abs() / 0.32).clamp(0.0, 1.0);
    final towardLow = (1 - (t - 0.68).abs() / 0.32).clamp(0.0, 1.0);
    var price =
        sessionOpen * (1 - t) +
        ltp * t +
        (sessionHigh - sessionOpen) * towardHigh * 0.55 +
        (sessionLow - sessionOpen) * towardLow * 0.55 +
        (sessionHigh - sessionLow) * wave * 0.18;
    price = price.clamp(sessionLow * 0.998, sessionHigh * 1.002);
    if (i == count - 1) {
      price = ltp > 0 ? ltp : price;
    }
    final candleHigh = math.max(previous, price);
    final candleLow = math.min(previous, price);
    candles.add(
      Candle(
        time: start.add(step * i),
        open: previous,
        high: candleHigh,
        low: candleLow,
        close: price,
      ),
    );
    previous = price;
  }
  return candles;
}

String formatChartTime(DateTime time, ChartRange range) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  switch (range) {
    case ChartRange.m1:
    case ChartRange.m5:
    case ChartRange.m15:
    case ChartRange.m30:
    case ChartRange.h1:
    case ChartRange.day:
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return range.intraday ? '$hour:$minute' : '${time.day} ${months[time.month - 1]}';
    case ChartRange.week:
    case ChartRange.month:
      return '${time.day} ${months[time.month - 1]}';
    case ChartRange.months3:
    case ChartRange.year:
      return months[time.month - 1];
  }
}

String chartHistoryPath({
  required String instrumentKey,
  required ChartRange range,
  DateTime? now,
}) {
  final encoded = Uri.encodeComponent(instrumentKey);
  final to = now ?? DateTime.now();
  switch (range) {
    case ChartRange.m1:
      return '/historical-candle/intraday/$encoded/minutes/1';
    case ChartRange.m5:
      return '/historical-candle/intraday/$encoded/minutes/5';
    case ChartRange.m15:
      return '/historical-candle/intraday/$encoded/minutes/15';
    case ChartRange.m30:
      return '/historical-candle/intraday/$encoded/minutes/30';
    case ChartRange.h1:
      return '/historical-candle/intraday/$encoded/hours/1';
    case ChartRange.day:
      return '/historical-candle/$encoded/days/1/${_ymd(to)}/${_ymd(to.subtract(const Duration(days: 180)))}';
    case ChartRange.week:
      return '/historical-candle/$encoded/weeks/1/${_ymd(to)}/${_ymd(to.subtract(const Duration(days: 730)))}';
    case ChartRange.month:
      return '/historical-candle/$encoded/months/1/${_ymd(to)}/${_ymd(to.subtract(const Duration(days: 1825)))}';
    case ChartRange.months3:
      return '/historical-candle/$encoded/days/1/${_ymd(to)}/${_ymd(to.subtract(const Duration(days: 100)))}';
    case ChartRange.year:
      return '/historical-candle/$encoded/weeks/1/${_ymd(to)}/${_ymd(to.subtract(const Duration(days: 400)))}';
  }
}

String _ymd(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
}
