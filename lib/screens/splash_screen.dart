import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/kite_mark.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _word = 'FLYSPRING';

  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _openLogin();
      }
    });
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _openLogin() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 480),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final glow = 0.18 +
              0.16 *
                  Curves.easeInOut.transform(
                    ((_intro.value - 0.2).clamp(0.0, 0.8)) / 0.8,
                  );
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF102038), Color(0xFF0B0F14), Color(0xFF0E1624)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -0.22 +
                        0.10 *
                            Curves.easeInOut.transform(
                              Interval(0.05, 0.55).transform(_intro.value),
                            ),
                    child: Transform.scale(
                      scale: Tween<double>(begin: 0.72, end: 1).transform(
                        Curves.easeOutBack.transform(
                          Interval(0, 0.38, curve: Curves.linear)
                              .transform(_intro.value)
                              .clamp(0.0, 1.0),
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: glow),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const KiteMark(size: 108),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    label: 'FLYSPRING',
                    child: Row(
                      key: const ValueKey('splash-flyspring'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _word.length; i++)
                          _AnimatedLetter(
                            letter: _word[i],
                            progress: Interval(
                              0.18 + i * 0.055,
                              0.42 + i * 0.055,
                              curve: Curves.easeOutCubic,
                            ).transform(_intro.value),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: Interval(0.62, 0.86, curve: Curves.easeOut)
                        .transform(_intro.value),
                    child: Align(
                      alignment: Alignment.center,
                      child: FractionallySizedBox(
                        widthFactor: 0.42,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: Interval(0.62, 0.92, curve: Curves.easeInOut)
                                .transform(_intro.value),
                            minHeight: 3,
                            backgroundColor: const Color(0xFF2A3441),
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: Interval(0.72, 1, curve: Curves.easeOut)
                        .transform(_intro.value),
                    child: const Text(
                      'TRADE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedLetter extends StatelessWidget {
  const _AnimatedLetter({required this.letter, required this.progress});

  final String letter;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 18),
        child: Transform.scale(
          scale: 0.86 + (0.14 * t),
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
              color: Color(0xFFF2F5F8),
            ),
          ),
        ),
      ),
    );
  }
}
