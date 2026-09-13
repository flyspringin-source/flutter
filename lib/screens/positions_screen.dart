import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/upstox_account.dart';
import '../state/upstox_account_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/position_summary_sheet.dart';

class PositionsScreen extends StatelessWidget {
  const PositionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final account = context.watch<UpstoxAccountController>();
    final positions = account.positions;

    return RefreshIndicator(
      onRefresh: account.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Positions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Open positions',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          _PnlSummary(
            dayPnl: account.dayPnl,
            unrealised: account.unrealisedPnl,
          ),
          if (account.displayPositionsError != null) ...[
            const SizedBox(height: 10),
            Text(
              account.displayPositionsError!,
              style: const TextStyle(color: AppColors.loss, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          if (account.loading && positions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (positions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: Text(
                'No open positions',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          else
            ...positions.map((item) => _PositionTile(item: item)),
        ],
      ),
    );
  }
}

class _PnlSummary extends StatelessWidget {
  const _PnlSummary({required this.dayPnl, required this.unrealised});

  final double dayPnl;
  final double unrealised;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day P&L',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  formatSignedRupee(dayPnl),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: dayPnl >= 0 ? AppColors.profit : AppColors.loss,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Unrealized',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  formatSignedRupee(unrealised),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: unrealised >= 0 ? AppColors.profit : AppColors.loss,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({required this.item});

  final UpstoxPosition item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final up = item.pnl >= 0;
    final color = up ? AppColors.profit : AppColors.loss;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => showPositionSummarySheet(context, item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.symbol,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    formatSignedRupee(item.pnl),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _meta(colors, 'Qty', '${item.quantity}'),
                  _meta(colors, 'Avg', formatPrice(item.averagePrice)),
                  _meta(colors, 'LTP', formatPrice(item.lastPrice)),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _meta(AppColors colors, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: colors.textMuted)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
