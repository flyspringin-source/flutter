import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/biometric_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/kite_mark.dart';
import '../widgets/pin_keypad.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String validMpin = '1111';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final BiometricAuth _biometricAuth = BiometricAuth();
  String _pin = '';
  String? _error;
  bool _busy = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _onDigit(String digit) async {
    if (_busy || _pin.length >= 4) {
      return;
    }
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      await _verifyPin();
    }
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (_pin == LoginScreen.validMpin) {
      _openApp();
      return;
    }
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    setState(() {
      _pin = '';
      _error = 'Incorrect MPIN. Try 1111.';
      _busy = false;
    });
  }

  Future<void> _unlockWithFingerprint() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final available = await _biometricAuth.isAvailable();
    if (!available) {
      setState(() {
        _busy = false;
        _error = 'Fingerprint is not available. Use MPIN 1111.';
      });
      return;
    }

    final ok = await _biometricAuth.authenticate();
    if (!mounted) {
      return;
    }
    if (ok) {
      _openApp();
      return;
    }
    setState(() {
      _busy = false;
      _error = 'Fingerprint not recognized. Try again or use MPIN.';
    });
  }

  void _openApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const MainShell(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const _BrandMark(),
                    const SizedBox(height: 28),
                    Text(
                      'Unlock trading',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter MPIN or use fingerprint',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) {
                        final dx = _shake.value < 1
                            ? (1 - _shake.value) *
                                10 *
                                ((_shake.value * 8).floor().isEven ? 1 : -1)
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final filled = index < _pin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? AppColors.gold
                                  : Colors.transparent,
                            border: Border.all(
                              color: filled
                                  ? AppColors.gold
                                  : colors.border,
                                width: 1.6,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 20,
                      child: Text(
                        _error ?? '',
                        style: const TextStyle(
                          color: AppColors.loss,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    PinKeypad(
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      onFingerprint: _unlockWithFingerprint,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Default MPIN  ·  1111',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const KiteMark(size: 78),
        const SizedBox(height: 14),
        Text(
          'FLYSPRING',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.5,
            color: AppColors.of(context).textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'TRADE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 5,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }
}
