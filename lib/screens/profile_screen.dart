import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/upstox_account.dart';
import '../state/upstox_account_controller.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final account = context.watch<UpstoxAccountController>();
    final profile = account.profile;
    final funds = account.funds;
    final name = (profile?.userName.trim().isNotEmpty ?? false)
        ? profile!.userName
        : (account.hasToken ? 'Upstox account' : 'Not linked');
    final clientId = profile?.userId.isNotEmpty == true
        ? 'Client ID  ${profile!.userId}'
        : (account.hasToken
              ? (profile?.email.isNotEmpty == true
                    ? profile!.email
                    : 'Loading Upstox profile')
              : '');

    return RefreshIndicator(
      onRefresh: account.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.accentSoft,
                  child: Text(
                    profile?.initials ?? 'U',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clientId,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (profile != null && profile.exchanges.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.exchanges.join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (account.loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MarginCard(account: account, funds: funds),
          if (account.displayProfileError != null) ...[
            const SizedBox(height: 10),
            Text(
              account.displayProfileError!,
              style: const TextStyle(color: AppColors.loss, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          _row(colors, Icons.account_balance_outlined, 'Bank & demat'),
          _row(colors, Icons.verified_user_outlined, 'KYC details'),
          _row(colors, Icons.support_agent_outlined, 'Support'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.loss,
                side: const BorderSide(color: AppColors.loss),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppColors colors, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            leading: Icon(icon, color: AppColors.accent),
            title: Text(title),
            trailing: Icon(Icons.chevron_right, color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _MarginCard extends StatelessWidget {
  const _MarginCard({required this.account, required this.funds});

  final UpstoxAccountController account;
  final UpstoxFunds? funds;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final available = funds?.availableMargin;
    final used = funds?.usedMargin;
    final value = funds == null ? null : (available ?? 0) + (used ?? 0);
    final pnl = account.dayPnl;
    final up = pnl >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.portfolioStart, colors.portfolioEnd],
        ),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AVAILABLE + USED MARGIN',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatRupee(value),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                up ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: up ? AppColors.profit : AppColors.loss,
              ),
              const SizedBox(width: 6),
              Text(
                '${formatSignedRupee(pnl)} day P&L',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: up ? AppColors.profit : AppColors.loss,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _FundCell(label: 'Used margin', value: formatRupee(used)),
              _FundCell(label: 'Available', value: formatRupee(available)),
              _FundCell(
                label: 'Collateral',
                value: formatRupee(funds?.collateral),
              ),
            ],
          ),
          if (account.displayFundsError != null) ...[
            const SizedBox(height: 12),
            Text(
              account.displayFundsError!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: account.fundsClosed ? AppColors.gold : AppColors.loss,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FundCell extends StatelessWidget {
  const _FundCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Expanded(
      child: Column(
        children: [
        Text(label, style: TextStyle(fontSize: 11, color: colors.textMuted)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        ],
      ),
    );
  }
}
