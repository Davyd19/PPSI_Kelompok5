import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Durasi dan kurva animasi bersama agar seluruh aplikasi bergerak dengan ritme yang sama.
const motionFast = Duration(milliseconds: 180);
const motionBase = Duration(milliseconds: 260);
const motionCurve = Curves.easeOutCubic;

/// Pop-up di tengah layar yang muncul dengan memudar dan sedikit membesar.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  IconData? icon,
  Color? iconColor,
  Color? iconBackground,
  List<Widget>? actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x730E2A47),
    transitionDuration: motionBase,
    pageBuilder: (context, _, _) => _AppDialog(
      title: title,
      icon: icon,
      iconColor: iconColor,
      iconBackground: iconBackground,
      actions: actions,
      child: child,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: motionCurve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: .92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AppDialog extends StatelessWidget {
  const _AppDialog({
    required this.title,
    required this.child,
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.actions,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Color? iconColor, iconBackground;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: size.height * .8,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: iconBackground ?? soft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: iconColor ?? navy, size: 24),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    DefaultTextStyle.merge(
                      style: const TextStyle(color: muted, height: 1.45),
                      child: child,
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children:
                            actions ??
                            [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Tutup'),
                              ),
                            ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Masuk dengan memudar dan naik sedikit. [index] membuat daftar muncul berurutan.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: motionBase,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: motionCurve,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    final wait = Duration(milliseconds: 40 * widget.index.clamp(0, 8));
    if (wait == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(wait, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, .04),
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
}

/// Sedikit mengecil saat ditekan agar kartu terasa responsif.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});
  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? .97 : 1,
      duration: motionFast,
      curve: motionCurve,
      child: widget.child,
    ),
  );
}
