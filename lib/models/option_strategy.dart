import 'option_strike.dart';

enum OptionStrategyKind {
  custom,
  straddle,
  strangle,
  bullCall,
  bearPut,
  ironFly,
}

extension OptionStrategyKindX on OptionStrategyKind {
  String get label => switch (this) {
    OptionStrategyKind.custom => 'Custom',
    OptionStrategyKind.straddle => 'Straddle',
    OptionStrategyKind.strangle => 'Strangle',
    OptionStrategyKind.bullCall => 'Bull Call',
    OptionStrategyKind.bearPut => 'Bear Put',
    OptionStrategyKind.ironFly => 'Iron Fly',
  };
}

class OptionStrategyLeg {
  const OptionStrategyLeg({
    required this.token,
    required this.strike,
    required this.isCall,
    required this.side,
    required this.quantity,
    required this.price,
    this.product = 'D',
  });

  final String token;
  final double strike;
  final bool isCall;
  final String side;
  final int quantity;
  final double price;
  final String product;

  bool get isBuy => side.toUpperCase() == 'BUY';

  String get optionType => isCall ? 'CE' : 'PE';

  OptionStrategyLeg copyWith({
    String? side,
    int? quantity,
    double? price,
    String? product,
  }) {
    return OptionStrategyLeg(
      token: token,
      strike: strike,
      isCall: isCall,
      side: side ?? this.side,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      product: product ?? this.product,
    );
  }

  Map<String, dynamic> toMarginInstrument() {
    return {
      'instrument_key': token,
      'quantity': quantity,
      'transaction_type': side.toUpperCase(),
      'product': product,
      if (price > 0) 'price': price,
    };
  }

  Map<String, dynamic> toOrderBody() {
    return {
      'instrument_token': token,
      'quantity': quantity,
      'transaction_type': side.toUpperCase(),
      'product': product,
      'order_type': price > 0 ? 'LIMIT' : 'MARKET',
      'price': price,
    };
  }
}

List<OptionStrategyLeg> buildStrategyLegs({
  required OptionStrategyKind kind,
  required List<OptionStrike> rows,
  required int anchorIndex,
  required bool tappedCall,
  required int quantity,
  required double Function(String token) ltpOf,
}) {
  if (rows.isEmpty || anchorIndex < 0 || anchorIndex >= rows.length) {
    return const [];
  }
  final row = rows[anchorIndex];
  OptionStrategyLeg? leg({
    required String? token,
    required double strike,
    required bool isCall,
    required String side,
  }) {
    if (token == null || token.isEmpty) {
      return null;
    }
    return OptionStrategyLeg(
      token: token,
      strike: strike,
      isCall: isCall,
      side: side,
      quantity: quantity,
      price: ltpOf(token),
    );
  }

  final higher = anchorIndex + 1 < rows.length ? rows[anchorIndex + 1] : null;
  final lower = anchorIndex > 0 ? rows[anchorIndex - 1] : null;

  switch (kind) {
    case OptionStrategyKind.custom:
      return [
        ?leg(
          token: tappedCall ? row.callToken : row.putToken,
          strike: row.strike,
          isCall: tappedCall,
          side: 'BUY',
        ),
      ];
    case OptionStrategyKind.straddle:
      return [
        ?leg(
          token: row.callToken,
          strike: row.strike,
          isCall: true,
          side: 'BUY',
        ),
        ?leg(
          token: row.putToken,
          strike: row.strike,
          isCall: false,
          side: 'BUY',
        ),
      ];
    case OptionStrategyKind.strangle:
      final callRow = higher ?? row;
      final putRow = lower ?? row;
      return [
        ?leg(
          token: callRow.callToken,
          strike: callRow.strike,
          isCall: true,
          side: 'BUY',
        ),
        ?leg(
          token: putRow.putToken,
          strike: putRow.strike,
          isCall: false,
          side: 'BUY',
        ),
      ];
    case OptionStrategyKind.bullCall:
      return [
        ?leg(
          token: row.callToken,
          strike: row.strike,
          isCall: true,
          side: 'BUY',
        ),
        ?leg(
          token: (higher ?? row).callToken,
          strike: (higher ?? row).strike,
          isCall: true,
          side: 'SELL',
        ),
      ];
    case OptionStrategyKind.bearPut:
      return [
        ?leg(
          token: row.putToken,
          strike: row.strike,
          isCall: false,
          side: 'BUY',
        ),
        ?leg(
          token: (lower ?? row).putToken,
          strike: (lower ?? row).strike,
          isCall: false,
          side: 'SELL',
        ),
      ];
    case OptionStrategyKind.ironFly:
      return [
        ?leg(
          token: row.callToken,
          strike: row.strike,
          isCall: true,
          side: 'SELL',
        ),
        ?leg(
          token: row.putToken,
          strike: row.strike,
          isCall: false,
          side: 'SELL',
        ),
        ?leg(
          token: (higher ?? row).callToken,
          strike: (higher ?? row).strike,
          isCall: true,
          side: 'BUY',
        ),
        ?leg(
          token: (lower ?? row).putToken,
          strike: (lower ?? row).strike,
          isCall: false,
          side: 'BUY',
        ),
      ];
  }
}
