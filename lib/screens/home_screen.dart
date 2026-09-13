import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/option_analysis.dart';
import '../data/scrip_catalog.dart';
import '../data/upstox_instruments.dart';
import '../models/market_index.dart';
import '../models/market_quote.dart';
import '../models/option_strike.dart';
import '../models/upstox_account.dart';
import '../state/index_controller.dart';
import '../state/market_feed_controller.dart';
import '../state/scrip_master_controller.dart';
import '../state/upstox_account_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/scrip_detail_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.active = true});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [_IndexChainAnalysis(active: active)],
    );
  }
}

class _IndexChainAnalysis extends StatefulWidget {
  const _IndexChainAnalysis({required this.active});

  final bool active;

  @override
  State<_IndexChainAnalysis> createState() => _IndexChainAnalysisState();
}

class _IndexChainAnalysisState extends State<_IndexChainAnalysis> {
  final _price = TextEditingController();
  String _windowKey = '';
  var _units = 1;
  var _byLots = true;
  var _priceEdited = false;
  var _qtyEdited = false;
  String _priceToken = '';
  String _qtyToken = '';

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final indices = context.read<IndexController>();
    final master = context.read<ScripMasterController>();
    final feed = context.read<MarketFeedController>();
    final account = context.read<UpstoxAccountController>();
    return ListenableBuilder(
      listenable: widget.active
          ? Listenable.merge([feed, indices, master, account])
          : Listenable.merge([master, account]),
      builder: (context, _) => _buildCard(
        context,
        colors: colors,
        indices: indices,
        master: master,
        feed: feed,
        account: account,
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required AppColors colors,
    required IndexController indices,
    required ScripMasterController master,
    required MarketFeedController feed,
    required UpstoxAccountController account,
  }) {
    final symbols = <String>[
      for (final item in [...indices.selectedIndices, ...indices.indices])
        item.scripSymbol,
    ];
    final pick = nearestIndexExpiry(
      symbols: symbols,
      expiriesFor: master.expiriesFor,
    );
    final symbol = pick?.symbol ?? 'NIFTY';
    final expiry = pick?.expiry ?? '';
    final index = _indexForSymbol(indices, symbol);
    final live = index == null ? null : feed.quoteFor(index.token);
    final spot = live?.ltp ?? index?.ltp ?? 0;
    final rows = expiry.isEmpty
        ? const <OptionStrike>[]
        : atmWindow(master.chainFor(symbol, expiry), spot, radius: 2);
    final tokens = [
      if (index != null) index.token,
      for (final row in rows) ...row.tokens,
    ];
    final key = '$symbol|$expiry|${tokens.join(',')}';
    if (feed.optionChainOpen) {
      _windowKey = '';
    } else if (widget.active && key != _windowKey && tokens.length > 1) {
      _windowKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active && !feed.optionChainOpen) {
          feed.watchChain(tokens);
        }
      });
    }
    final stats = windowStats(rows: rows, quoteFor: feed.quoteFor);
    final trade = adviseTrade(
      rows: rows,
      quoteFor: feed.quoteFor,
      spot: spot,
      expiry: expiry,
      bias: stats.bias,
    );
    final lotSize = trade == null
        ? defaultLotSize(symbol)
        : master.lotSizeFor(trade.token, symbol);
    final positions = account.positions
        .where(
          (item) =>
              item.quantity != 0 &&
              item.symbol.toUpperCase().contains(symbol),
        )
        .toList();
    final atmStrike = rows.isEmpty
        ? null
        : atmWindow(rows, spot, radius: 0).firstOrNull?.strike;
    var maxOi = 0.0;
    for (final row in rows) {
      final callOi =
          (row.callToken == null ? null : feed.quoteFor(row.callToken!))
              ?.openInterest ??
          0;
      final putOi =
          (row.putToken == null ? null : feed.quoteFor(row.putToken!))
              ?.openInterest ??
          0;
      if (callOi > maxOi) {
        maxOi = callOi;
      }
      if (putOi > maxOi) {
        maxOi = putOi;
      }
    }
    final action = trade?.action ?? TradeAction.call;
    final biasColor = action == TradeAction.call
        ? AppColors.profit
        : AppColors.loss;
    final premium = double.tryParse(_price.text.trim()) ??
        trade?.entry ??
        trade?.ltp ??
        0;
    final units = _displayUnits(
      token: trade?.token ?? '',
      available: account.funds?.availableMargin,
      premium: premium,
      lotSize: lotSize,
    );
    _schedulePriceSync(trade);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExpiryHeadline(
            symbol: symbol,
            expiry: expiry,
          ),
          const SizedBox(height: 10),
          _OhlcBar(
            ltp: spot,
            open: live?.open ?? index?.open,
            high: live?.high ?? index?.high,
            low: live?.low ?? index?.low,
            prevClose: live?.close ?? index?.prevClose,
          ),
          const SizedBox(height: 12),
          _SideTotals(
            leftLabel: 'Call OI',
            rightLabel: 'Put OI',
            leftValue: stats.callOi,
            rightValue: stats.putOi,
            leftShare: stats.callOiShare,
          ),
          const SizedBox(height: 12),
          _SideTotals(
            leftLabel: 'Call OI chg',
            rightLabel: 'Put OI chg',
            leftValue: stats.callOiChange,
            rightValue: stats.putOiChange,
            leftShare: stats.callOiChangeShare,
            signed: true,
          ),
          const SizedBox(height: 12),
          _SideTotals(
            leftLabel: 'Call volume',
            rightLabel: 'Put volume',
            leftValue: stats.callVolume,
            rightValue: stats.putVolume,
            leftShare: stats.callVolumeShare,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _LotStepper(
                  units: units,
                  lotSize: lotSize,
                  byLots: _byLots,
                  onToggle: () => _toggleQtyMode(lotSize),
                  onMinus: () => _stepQty(lotSize, -1, current: units),
                  onPlus: () => _stepQty(lotSize, 1, current: units),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                height: 52,
                child: TextField(
                  key: const ValueKey('entry-price'),
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    _priceEdited = true;
                    setState(() {});
                  },
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Price',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('analysis-buy'),
                  onPressed: trade == null || !trade.canBuy || account.placing
                      ? null
                      : () => _placeBuy(
                          context,
                          account: account,
                          master: master,
                          trade: trade,
                          symbol: symbol,
                          lotSize: lotSize,
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: biasColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    trade?.sideLabel ?? 'Buy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (trade != null) ...[
            const SizedBox(height: 12),
            _TradePlanCard(trade: trade),
          ],
          if (positions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Positions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final position in positions)
              _OpenPositionRow(
                position: position,
                placing: account.placing,
                onExit: () => _exitPosition(context, account, position),
              ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'CALL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.profit,
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  'STRIKE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'PUT',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.loss,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No option chain for $symbol',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          else
            for (final row in rows)
              _AnalysisStrikeRow(
                row: row,
                atm: row.strike == atmStrike,
                maxOi: maxOi,
                call: row.callToken == null
                    ? null
                    : feed.quoteFor(row.callToken!),
                put: row.putToken == null ? null : feed.quoteFor(row.putToken!),
              ),
        ],
      ),
    );
  }

  void _schedulePriceSync(SuggestedTrade? trade) {
    if (trade == null || _priceEdited) {
      return;
    }
    if (_priceToken != trade.token) {
      _priceToken = trade.token;
      _priceEdited = false;
    }
    final ltp = trade.entry ?? trade.ltp;
    final text = ltp != null && ltp > 0 ? ltp.toStringAsFixed(2) : '';
    if (_price.text == text) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _priceEdited || _price.text == text) {
        return;
      }
      _price.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  int _displayUnits({
    required String token,
    required double? available,
    required double premium,
    required int lotSize,
  }) {
    if (token.isNotEmpty && token != _qtyToken) {
      _qtyToken = token;
      _qtyEdited = false;
    }
    if (_qtyEdited) {
      return _units;
    }
    final lots = lotsFromMargin(
      availableMargin: available ?? 0,
      premium: premium,
      lotSize: lotSize,
    );
    return _byLots ? lots : lots * lotSize;
  }

  void _toggleQtyMode(int lotSize) {
    setState(() {
      if (_qtyEdited) {
        if (_byLots) {
          _units = _units * lotSize;
        } else {
          _units = (_units / lotSize).round().clamp(1, 9999);
        }
      }
      _byLots = !_byLots;
    });
  }

  void _stepQty(int lotSize, int direction, {required int current}) {
    setState(() {
      if (!_qtyEdited) {
        _units = current;
      }
      _qtyEdited = true;
      if (_byLots) {
        _units = (_units + direction).clamp(1, 9999);
      } else {
        final next = _units + direction * lotSize;
        _units = next < lotSize ? lotSize : next;
      }
    });
  }

  int _orderQuantity({
    required int lotSize,
    required String token,
    required double? available,
    required double premium,
  }) {
    final units = _displayUnits(
      token: token,
      available: available,
      premium: premium,
      lotSize: lotSize,
    );
    if (_byLots) {
      return units * lotSize;
    }
    if (lotSize <= 1) {
      return units < 1 ? 1 : units;
    }
    final lots = (units / lotSize).round().clamp(1, 9999);
    return lots * lotSize;
  }

  Future<void> _placeBuy(
    BuildContext context, {
    required UpstoxAccountController account,
    required ScripMasterController master,
    required SuggestedTrade trade,
    required String symbol,
    required int lotSize,
  }) async {
    if (!account.hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generate Upstox access tokens in Settings'),
        ),
      );
      return;
    }
    final scrip = master.byToken(trade.token);
    final token =
        upstoxInstrumentKey(
          token: trade.token,
          symbol: scrip?.symbol ?? symbol,
          exchange: scrip?.exchange ?? 'NSE',
          kind: ScripKind.option,
        ) ??
        trade.token;
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final quantity = _orderQuantity(
      lotSize: lotSize,
      token: trade.token,
      available: account.funds?.availableMargin,
      premium: price > 0 ? price : (trade.entry ?? trade.ltp ?? 0),
    );
    try {
      await account.placeOrder(
        instrumentToken: token,
        side: 'BUY',
        quantity: quantity,
        product: 'I',
        orderType: price > 0 ? 'LIMIT' : 'MARKET',
        price: price,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Placed ${trade.buttonLabel} · $quantity qty'
              '${price > 0 ? ' @ ${formatPrice(price)}' : ''}',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

Future<void> _exitPosition(
  BuildContext context,
  UpstoxAccountController account,
  UpstoxPosition position,
) async {
  if (position.instrumentToken.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No instrument key to exit this position')),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Exit position?'),
        content: Text(
          '${position.symbol} · qty ${position.quantity.abs()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await account.placeOrder(
      instrumentToken: position.instrumentToken,
      side: position.quantity > 0 ? 'SELL' : 'BUY',
      quantity: position.quantity.abs(),
      product: position.product.isEmpty ? 'I' : position.product,
      orderType: 'MARKET',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exited ${position.symbol}')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _TradePlanCard extends StatelessWidget {
  const _TradePlanCard({required this.trade});

  final SuggestedTrade trade;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final actionColor = trade.isBuy ? AppColors.profit : AppColors.loss;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: actionColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: actionColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trade.buttonLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: actionColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _planCell(colors, 'Strike', formatStrike(trade.strike)),
              _planCell(colors, 'LTP', formatMaybe(trade.ltp)),
              _planCell(colors, 'Entry', formatMaybe(trade.entry)),
              _planCell(colors, 'Stop loss', formatMaybe(trade.stopLoss)),
              _planCell(colors, 'Target', formatMaybe(trade.target), end: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planCell(
    AppColors colors,
    String label,
    String value, {
    bool end = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: end
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: colors.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OhlcBar extends StatelessWidget {
  const _OhlcBar({
    required this.ltp,
    required this.open,
    required this.high,
    required this.low,
    required this.prevClose,
  });

  final double ltp;
  final double? open;
  final double? high;
  final double? low;
  final double? prevClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final values = <double>[
      if (ltp > 0) ltp,
      if (open != null && open! > 0) open!,
      if (high != null && high! > 0) high!,
      if (low != null && low! > 0) low!,
      if (prevClose != null && prevClose! > 0) prevClose!,
    ];
    final min = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 0.01 ? 1.0 : max - min;

    double align(double? value) {
      if (value == null || value <= 0) {
        return 0.5;
      }
      return ((value - min) / span).clamp(0.0, 1.0);
    }

    return Column(
      children: [
        Row(
          children: [
            _ohlcCell(colors, 'Prev. close', prevClose),
            _ohlcCell(colors, 'Open', open),
            _ohlcCell(colors, 'High', high, color: AppColors.profit),
            _ohlcCell(colors, 'Low', low, color: AppColors.loss, end: true),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 28,
          child: LayoutBuilder(
            builder: (context, constraints) {
              Widget mark(double? value, Color color, {double width = 3}) {
                if (value == null || value <= 0) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: align(value) * constraints.maxWidth - width / 2,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: width,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  Center(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: const LinearGradient(
                          colors: [AppColors.loss, AppColors.gold, AppColors.profit],
                        ),
                      ),
                    ),
                  ),
                  mark(prevClose, colors.textPrimary, width: 2),
                  mark(open, AppColors.accent, width: 2),
                  mark(ltp, Colors.white, width: 4),
                ],
              );
            },
          ),
        ),
        Text(
          'LTP ${formatMaybe(ltp)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _ohlcCell(
    AppColors colors,
    String label,
    double? value, {
    Color? color,
    bool end = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: end
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: colors.textMuted)),
          const SizedBox(height: 2),
          Text(
            formatMaybe(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LotStepper extends StatelessWidget {
  const _LotStepper({
    required this.units,
    required this.lotSize,
    required this.byLots,
    required this.onToggle,
    required this.onMinus,
    required this.onPlus,
  });

  final int units;
  final int lotSize;
  final bool byLots;
  final VoidCallback onToggle;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final alt = byLots
        ? '${units * lotSize} qty'
        : '${(units / lotSize).toStringAsFixed(units % lotSize == 0 ? 0 : 1)} lots';
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _stepButton(
            key: const ValueKey('lot-minus'),
            icon: Icons.remove,
            onTap: onMinus,
          ),
          Expanded(
            child: InkWell(
              key: const ValueKey('qty-mode'),
              onTap: onToggle,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$units',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    byLots ? 'Lots' : 'Qty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                  Text(
                    alt,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          _stepButton(
            key: const ValueKey('lot-plus'),
            icon: Icons.add,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }

  Widget _stepButton({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 52,
        child: Icon(icon, size: 20, color: AppColors.accent),
      ),
    );
  }
}

class _OpenPositionRow extends StatelessWidget {
  const _OpenPositionRow({
    required this.position,
    required this.placing,
    required this.onExit,
  });

  final UpstoxPosition position;
  final bool placing;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = position.pnl >= 0 ? AppColors.profit : AppColors.loss;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position.symbol,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Qty ${position.quantity} · ${formatSignedRupee(position.pnl)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: ValueKey('position-exit-${position.instrumentToken}'),
              onPressed: placing ? null : onExit,
              child: const Text('Exit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryHeadline extends StatelessWidget {
  const _ExpiryHeadline({required this.symbol, required this.expiry});

  final String symbol;
  final String expiry;

  @override
  Widget build(BuildContext context) {
    final expiryText = expiry.isEmpty ? 'No live expiry' : formatExpiryLong(expiry);
    final dte = expiry.isEmpty ? '' : daysToExpiryLabel(expiry);
    return Row(
      children: [
        Expanded(child: _HighlightChip(text: symbol, emphasis: true)),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _HighlightChip(text: expiryText)),
        if (dte.isNotEmpty) ...[
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _HighlightChip(text: dte)),
        ],
      ],
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.text, this.emphasis = false});

  final String text;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: emphasis
            ? AppColors.accent.withValues(alpha: 0.14)
            : colors.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: emphasis ? 14 : 12,
          fontWeight: FontWeight.w800,
          color: emphasis ? AppColors.accent : colors.textPrimary,
        ),
      ),
    );
  }
}

class _SideTotals extends StatelessWidget {
  const _SideTotals({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftValue,
    required this.rightValue,
    required this.leftShare,
    this.signed = false,
  });

  final String leftLabel;
  final String rightLabel;
  final double leftValue;
  final double rightValue;
  final double leftShare;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                leftLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.profit,
                ),
              ),
            ),
            Text(
              signed
                  ? formatCompactSigned(leftValue)
                  : formatCompactQty(leftValue),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: signed ? _changeColor(colors, leftValue) : colors.textPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              signed
                  ? formatCompactSigned(rightValue)
                  : formatCompactQty(rightValue),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: signed ? _changeColor(colors, rightValue) : colors.textPrimary,
              ),
            ),
            Expanded(
              child: Text(
                rightLabel,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.loss,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ShareBar(leftShare: leftShare),
      ],
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.leftShare});

  final double leftShare;

  @override
  Widget build(BuildContext context) {
    final putShare = (1 - leftShare).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: ((leftShare * 1000).round()).clamp(1, 1000),
              child: ColoredBox(
                color: AppColors.profit.withValues(alpha: 0.35),
              ),
            ),
            Expanded(
              flex: ((putShare * 1000).round()).clamp(1, 1000),
              child: ColoredBox(
                color: AppColors.loss.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisStrikeRow extends StatelessWidget {
  const _AnalysisStrikeRow({
    required this.row,
    required this.atm,
    required this.maxOi,
    required this.call,
    required this.put,
  });

  final OptionStrike row;
  final bool atm;
  final double maxOi;
  final MarketQuote? call;
  final MarketQuote? put;

  static const _track = Colors.transparent;
  static const _fill = Color(0x4DFFF6D0);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return RepaintBoundary(
      child: Container(
      decoration: BoxDecoration(
        color: atm ? AppColors.gold.withValues(alpha: 0.06) : null,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: _OiGraphCell(
                oi: call?.openInterest ?? 0,
                maxOi: maxOi,
                fromStrike: true,
                onTap: row.callToken == null
                    ? null
                    : () => openScripDetails(context, token: row.callToken!),
                child: Row(
                  children: [
                    _OiVolCell(
                      oi: call?.openInterest,
                      volume: call?.volume,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _LtpChange(
                        ltp: call?.ltp,
                        change: call?.change,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  formatStrike(row.strike),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _changeColor(
                      colors,
                      (call?.change ?? 0) + (put?.change ?? 0),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _OiGraphCell(
                oi: put?.openInterest ?? 0,
                maxOi: maxOi,
                fromStrike: false,
                onTap: row.putToken == null
                    ? null
                    : () => openScripDetails(context, token: row.putToken!),
                child: Row(
                  children: [
                    Expanded(
                      child: _LtpChange(
                        ltp: put?.ltp,
                        change: put?.change,
                        alignEnd: false,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _OiVolCell(
                      oi: put?.openInterest,
                      volume: put?.volume,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _OiVolCell extends StatelessWidget {
  const _OiVolCell({required this.oi, required this.volume});

  final double? oi;
  final double? volume;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: colors.textMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('O: ${formatCompactQty(oi)}', style: style),
        Text('V: ${formatCompactQty(volume)}', style: style),
      ],
    );
  }
}

class _LtpChange extends StatelessWidget {
  const _LtpChange({
    required this.ltp,
    required this.change,
    required this.alignEnd,
  });

  final double? ltp;
  final double? change;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chg = change;
    final chgColor = _changeColor(colors, chg);
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          formatMaybe(ltp),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: chgColor,
          ),
        ),
        Text(
          chg == null || chg == 0 ? '--' : formatSigned(chg),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: chgColor,
          ),
        ),
      ],
    );
  }
}

Color _changeColor(AppColors colors, double? change) {
  if (change == null || change == 0) {
    return colors.textMuted;
  }
  return change > 0 ? AppColors.profit : AppColors.loss;
}

class _OiGraphCell extends StatelessWidget {
  const _OiGraphCell({
    required this.oi,
    required this.maxOi,
    required this.fromStrike,
    required this.child,
    this.onTap,
  });

  final double oi;
  final double maxOi;
  final bool fromStrike;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final factor = maxOi <= 0 || oi <= 0 ? 0.0 : (oi / maxOi).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: _AnalysisStrikeRow._track),
            ),
            Positioned.fill(
              child: Align(
                alignment: fromStrike
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: factor * 0.5,
                  heightFactor: 1,
                  child: const ColoredBox(color: _AnalysisStrikeRow._fill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

MarketIndex? _indexForSymbol(IndexController indices, String symbol) {
  final key = symbol.toUpperCase();
  for (final index in [...indices.selectedIndices, ...indices.indices]) {
    if (index.scripSymbol == key) {
      return index;
    }
  }
  return null;
}
