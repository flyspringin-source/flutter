import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/upstox_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _fingerprint = true;
  bool _alerts = true;
  bool _orderSound = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = context.watch<ThemeController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Appearance',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ThemeChoice(
              label: 'Light',
              icon: Icons.light_mode_outlined,
              selected: theme.mode == ThemeMode.light,
              onTap: () => theme.setMode(ThemeMode.light),
            ),
            const SizedBox(width: 8),
            _ThemeChoice(
              label: 'Dark',
              icon: Icons.dark_mode_outlined,
              selected: theme.mode == ThemeMode.dark,
              onTap: () => theme.setMode(ThemeMode.dark),
            ),
            const SizedBox(width: 8),
            _ThemeChoice(
              label: 'Phone',
              icon: Icons.smartphone_outlined,
              selected: theme.mode == ThemeMode.system,
              onTap: () => theme.setMode(ThemeMode.system),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const UpstoxSettingsCard(),
        const SizedBox(height: 16),
        _card(colors, [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fingerprint unlock'),
            subtitle: const Text('Use biometrics on login'),
            value: _fingerprint,
            activeThumbColor: AppColors.accent,
            onChanged: (value) => setState(() => _fingerprint = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Price alerts'),
            subtitle: const Text('Notify on LTP moves'),
            value: _alerts,
            activeThumbColor: AppColors.accent,
            onChanged: (value) => setState(() => _alerts = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Order sounds'),
            subtitle: const Text('Play a tone on fills'),
            value: _orderSound,
            activeThumbColor: AppColors.accent,
            onChanged: (value) => setState(() => _orderSound = value),
          ),
        ]),
        const SizedBox(height: 14),
        _card(colors, [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune, color: AppColors.accent),
            title: const Text('Default product'),
            subtitle: const Text('Intraday / MIS'),
            trailing: Icon(Icons.chevron_right, color: colors.textMuted),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.notifications_none,
              color: AppColors.gold,
            ),
            title: const Text('Notification preferences'),
            trailing: Icon(Icons.chevron_right, color: colors.textMuted),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline, color: colors.textSecondary),
            title: const Text('About Flyspring'),
            subtitle: const Text('Version 1.0.0'),
            trailing: Icon(Icons.chevron_right, color: colors.textMuted),
          ),
        ]),
      ],
    );
  }

  Widget _card(AppColors colors, List<Widget> children) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Column(children: children),
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Expanded(
      child: Material(
        color: selected ? colors.accentSoft : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.accent : colors.border,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.accent : colors.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.accent : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
