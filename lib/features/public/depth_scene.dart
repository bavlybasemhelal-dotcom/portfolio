import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/preferences.dart';
import '../validation/scene_page.dart' show IdentityPainter;

/// One isolated native canvas per scene, no JavaScript/engine dependency.
class DepthScene extends ConsumerStatefulWidget {
  final double turn;
  final bool identity, visible;
  final Widget Function(Widget logo, double angle, double orbit, bool dark)?
  identityBuilder;
  const DepthScene({
    super.key,
    this.turn = 0,
    this.identity = true,
    this.visible = true,
    this.identityBuilder,
  });
  @override
  ConsumerState<DepthScene> createState() => _DepthSceneState();
}

class _DepthSceneState extends ConsumerState<DepthScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  bool foreground =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool onScreen = true, scheduled = false;
  ScrollPosition? scrollPosition;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != scrollPosition) {
      scrollPosition?.removeListener(visibility);
      scrollPosition = next;
      next?.addListener(visibility);
    }
    visibility();
  }

  void visibility() {
    if (scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final visible = (box.localToGlobal(Offset.zero) & box.size).overlaps(
        Offset.zero & MediaQuery.sizeOf(context),
      );
      if (visible != onScreen) setState(() => onScreen = visible);
    });
  }

  @override
  void didChangeMetrics() {
    visibility();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hidden tabs may suspend frame delivery, so stop before waiting for build.
    if (state != AppLifecycleState.resumed) clock.stop();
    if (mounted) {
      setState(() => foreground = state == AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scrollPosition?.removeListener(visibility);
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final p = ref.watch(preferencesProvider);
    final reduced = p.reduced || MediaQuery.disableAnimationsOf(c);
    final active =
        !p.paused &&
        !reduced &&
        foreground &&
        widget.visible &&
        onScreen &&
        TickerMode.valuesOf(c).enabled;
    if (active && !clock.isAnimating) clock.repeat();
    if (!active && clock.isAnimating) clock.stop();
    final dark = Theme.of(c).brightness == Brightness.dark;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: clock,
        builder: (_, _) {
          final orbit = clock.value * math.pi * 6;
          final angle = reduced
              ? -.18
              : widget.turn * math.pi * 2 - .18 + clock.value * math.pi * 2;
          final logo = Padding(
            padding: const EdgeInsets.all(28),
            child: LayoutBuilder(
              builder: (_, box) => CustomPaint(
                key: const ValueKey('public-identity-scene'),
                painter: IdentityPainter(
                  angle: angle,
                  orbit: orbit,
                  dark: dark,
                  transparent: true,
                  fallback: reduced,
                  interactionSize: widget.identityBuilder == null
                      ? null
                      : box.biggest,
                ),
              ),
            ),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: IgnorePointer(
                  child: CustomPaint(painter: GeometryPainter(orbit, dark)),
                ),
              ),
              if (widget.identity)
                widget.identityBuilder?.call(logo, angle, orbit, dark) ??
                    ExcludeSemantics(child: IgnorePointer(child: logo)),
            ],
          );
        },
      ),
    );
  }
}

class GeometryPainter extends CustomPainter {
  final double angle;
  final bool dark;
  const GeometryPainter(this.angle, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Color(dark ? 0xff61b9f5 : 0xff2173c0);
    final points = <Offset>[];
    final depths = <double>[];
    final radius = math.min(size.width, size.height) * .12;
    final center = Offset(size.width * .19, size.height * .2);
    for (final z in [-1.0, 1.0]) {
      for (final y in [-1.0, 1.0]) {
        for (final x in [-1.0, 1.0]) {
          final rx = x * math.cos(angle * .55) + z * math.sin(angle * .55);
          final rz = -x * math.sin(angle * .55) + z * math.cos(angle * .55);
          final py = y * math.cos(.48) - rz * math.sin(.48);
          final pz = y * math.sin(.48) + rz * math.cos(.48);
          final perspective = 4 / (4 - pz * .3);
          points.add(center + Offset(rx, py) * radius * perspective);
          depths.add(pz);
        }
      }
    }
    const faces = [
      [0, 1, 3, 2],
      [4, 5, 7, 6],
      [0, 1, 5, 4],
      [2, 3, 7, 6],
      [0, 2, 6, 4],
      [1, 3, 7, 5],
    ];
    final sorted = faces.toList()
      ..sort(
        (a, b) => a
            .fold<double>(0, (v, i) => v + depths[i])
            .compareTo(b.fold<double>(0, (v, i) => v + depths[i])),
      );
    for (final f in sorted) {
      final p = Path()..addPolygon(f.map((i) => points[i]).toList(), true);
      canvas.drawPath(
        p,
        Paint()..color = ink.withValues(alpha: dark ? .09 : .06),
      );
      canvas.drawPath(
        p,
        Paint()
          ..color = ink.withValues(alpha: .42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
    }
    canvas.save();
    canvas.translate(size.width * .71, size.height * .74);
    canvas.rotate(-.18 + math.sin(angle) * .1);
    final ring = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .61,
      height: size.height * .21,
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = ink.withValues(alpha: .35),
    );
    canvas.drawCircle(
      Offset(
        math.cos(angle) * ring.width / 2,
        math.sin(angle) * ring.height / 2,
      ),
      4,
      Paint()..color = ink,
    );
    canvas.restore();
    for (var i = 0; i < 14; i++) {
      final x = size.width * ((i * .173 + .13) % 1);
      final y = size.height * ((i * .271 + .23) % 1) + math.sin(angle + i) * 5;
      canvas.drawCircle(
        Offset(x, y),
        1,
        Paint()..color = ink.withValues(alpha: .18),
      );
    }
  }

  @override
  bool shouldRepaint(GeometryPainter old) =>
      old.angle != angle || old.dark != dark;
}
