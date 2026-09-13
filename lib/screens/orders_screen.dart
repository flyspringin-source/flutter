import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/scrip_catalog.dart';
import '../models/upstox_account.dart';
import '../models/watchlist_stock.dart';
import '../state/upstox_account_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/order_ticket_sheet.dart';
import '../widgets/scrip_detail_sheet.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  var _group = UpstoxOrderGroup.pending;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final account = context.watch<UpstoxAccountController>();
    final orders = account.ordersIn(_group);

    return RefreshIndicator(
      onRefresh: account.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Today · order book',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          if (account.displayOrdersError != null) ...[
            const SizedBox(height: 8),
            Text(
              account.displayOrdersError!,
              style: const TextStyle(color: AppColors.loss, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              for (final group in UpstoxOrderGroup.values) ...[
                if (group.index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _GroupChip(
                    label: upstoxOrderGroupLabel(group),
                    count: account.countIn(group),
                    selected: _group == group,
                    onTap: () => setState(() => _group = group),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (account.loading && account.orders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                'No ${upstoxOrderGroupLabel(_group).toLowerCase()} orders',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          else
            ...orders.map((order) => _OrderTile(order: order)),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.accentSoft : colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : colors.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.accent : colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.accent : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final UpstoxOrder order;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final buy = order.side == 'BUY';
    final sideColor = buy ? AppColors.profit : AppColors.loss;
    final statusColor = switch (order.group) {
      UpstoxOrderGroup.executed => AppColors.profit,
      UpstoxOrderGroup.rejected => AppColors.loss,
      UpstoxOrderGroup.cancelled => colors.textMuted,
      UpstoxOrderGroup.pending => AppColors.gold,
    };
    final price = order.averagePrice > 0 ? order.averagePrice : order.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sideColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order.side.isEmpty ? '--' : order.side,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: sideColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: order.symbol.isEmpty
                      ? null
                      : () => openScripDetails(context, symbol: order.symbol),
                  child: Text(
                    order.symbol.isEmpty ? order.orderId : order.symbol,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    'Qty ${order.quantity}',
                    if (price > 0) '₹${formatPrice(price)}',
                    if (order.orderType.isNotEmpty) order.orderType,
                  ].join('  ·  '),
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                if (order.statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    order.statusMessage,
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                upstoxOrderGroupLabel(order.group),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              if (order.canModify)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => showOrderTicketSheet(
                    context,
                    stock: WatchlistStock(
                      symbol: order.symbol.isEmpty ? order.orderId : order.symbol,
                      name: order.symbol,
                      token: '',
                      ltp: order.price > 0 ? order.price : order.averagePrice,
                      change: 0,
                      kind: ScripKind.equity,
                    ),
                    side: order.side.isEmpty ? 'BUY' : order.side,
                    instrumentToken: order.instrumentToken,
                    existing: order,
                  ),
                  child: const Text('Modify'),
                ),
              if (order.canCancel)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.loss,
                  ),
                  onPressed: () => _cancelOrder(context, order),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _cancelOrder(BuildContext context, UpstoxOrder order) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Cancel order?'),
        content: Text(
          [
            order.side,
            if (order.symbol.isNotEmpty) order.symbol,
            'qty ${order.quantity}',
          ].join(' · '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await context.read<UpstoxAccountController>().cancelOrder(order.orderId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancelled ${order.symbol.isEmpty ? order.orderId : order.symbol}')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUpstoxError(error))));
    }
  }
}
