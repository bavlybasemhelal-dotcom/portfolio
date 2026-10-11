import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/yogen_app.dart';
import '../../core/preferences.dart';

class ScenePage extends ConsumerStatefulWidget {
  const ScenePage({super.key});
  @override
  ConsumerState<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends ConsumerState<ScenePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  double progress = 0;
  bool fallback = false;
  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final prefs = ref.watch(preferencesProvider);
    final reduced = prefs.reduced || MediaQuery.of(c).disableAnimations;
    final active = !prefs.paused && !reduced && !fallback;
    if (active && !clock.isAnimating) clock.repeat();
    if (!active && clock.isAnimating) clock.stop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(c, 'هوية مجسمة داخل Flutter', 'A dimensional identity in Flutter'),
          style: Theme.of(c).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            c,
            'اسحب شريط الدوران أو مرّر داخل المشهد لدورة كاملة. الرسم محدود ومعزول لاختبار المنظور والإضاءة.',
            'Use the rotation slider or scroll inside the scene for a full turn. This isolated drawing verifies perspective and lighting.',
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Rotation ${(progress * 360).round()} degrees',
          child: Slider(
            key: const ValueKey('rotation'),
            value: progress,
            divisions: 360,
            label: '${(progress * 360).round()}°',
            onChanged: reduced || fallback
                ? null
                : (v) => setState(() => progress = v),
          ),
        ),
        Text(
          '${(progress * 360).round()}° / 360° · ${prefs.paused ? tr(c, 'متوقفة', 'Paused') : tr(c, 'جاهزة', 'Ready')}',
        ),
        const SizedBox(height: 12),
        RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 360,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: clock,
                      builder: (c, _) => CustomPaint(
                        key: const ValueKey('native-scene'),
                        painter: IdentityPainter(
                          angle: reduced || fallback
                              ? 0
                              : progress * math.pi * 2,
                          orbit: active ? clock.value * math.pi * 2 : 0,
                          dark: Theme.of(c).brightness == Brightness.dark,
                          fallback: fallback,
                        ),
                      ),
                    ),
                  ),
                  if (!reduced && !fallback)
                    Positioned.fill(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.maxScrollExtent > 0) {
                            setState(
                              () => progress =
                                  (n.metrics.pixels / n.metrics.maxScrollExtent)
                                      .clamp(0, 1),
                            );
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          child: SizedBox(
                            height: 1100,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  tr(
                                    c,
                                    'مرّر داخل المشهد ↓',
                                    'Scroll inside the scene ↓',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: prefs.reduced,
          onChanged: (_) => ref.read(preferencesProvider.notifier).reduce(),
          title: Text(tr(c, 'تقليل الحركة', 'Reduced motion')),
        ),
        SwitchListTile(
          value: fallback,
          onChanged: (v) => setState(() => fallback = v),
          title: Text(tr(c, 'البديل الثابت', 'Static fallback')),
        ),
        Text(
          tr(
            c,
            'الحقول والأزرار تظل مستقيمة. فحص الهاتف هنا فحص حجم شاشة؛ أداء جهاز هاتف فعلي يحتاج تجربة منفصلة.',
            'Controls stay flat. A mobile viewport verifies layout; physical phone performance needs a separate check.',
          ),
        ),
      ],
    );
  }
}

class _V {
  final double x, y, z;
  const _V(this.x, this.y, this.z);
  _V rotate(double yaw, double pitch) {
    final a = x * math.cos(yaw) + z * math.sin(yaw);
    final b = -x * math.sin(yaw) + z * math.cos(yaw);
    return _V(
      a,
      y * math.cos(pitch) - b * math.sin(pitch),
      y * math.sin(pitch) + b * math.cos(pitch),
    );
  }
}

class _Face {
  final List<_V> points;
  final Color color;
  const _Face(this.points, this.color);
  double get depth => points.fold<double>(0, (v, p) => v + p.z) / points.length;
}

/// Native Dart face projection. This is a small mesh proof, not a 3D engine.
class IdentityPainter extends CustomPainter {
  final double angle, orbit;
  final bool dark, fallback;
  final bool transparent;
  final Size? interactionSize;
  const IdentityPainter({
    required this.angle,
    required this.orbit,
    required this.dark,
    this.fallback = false,
    this.transparent = false,
    this.interactionSize,
  });
  static const shapes = <List<List<double>>>[
    [
      [-1.27, 1.05],
      [-1.27, 1.76],
      [-.10, .91],
      [-.52, .49],
    ],
    [
      [-.52, -.72],
      [-.52, .35],
      [-.37, .78],
      [1.28, 1.77],
      [1.28, 1.05],
      [.21, .43],
      [.02, .20],
      [.02, -1.11],
    ],
    [
      [-.52, -.73],
      [.02, -1.11],
      [1.23, -.43],
      [1.23, .28],
      [.87, .48],
      [.35, .21],
      [.35, .045],
      [.78, -.13],
      [.78, -.28],
      [.13, -.66],
      [.13, -.12],
      [-.52, -.42],
    ],
  ];
  // Only the projected mark catches presses; the surrounding scene still scrolls.
  @override
  bool hitTest(Offset position) {
    final size = interactionSize;
    if (size == null) return false;
    final scale = math.min(size.width / 4.3, size.height / 3.7);
    final center = Offset(size.width / 2, size.height / 2 + 24);
    for (final poly in shapes) {
      for (final z in [-.13, .13]) {
        final points = poly.map((p) {
          final v = _V(
            p[0],
            p[1],
            z,
          ).rotate(angle + (fallback ? 0 : .2), fallback ? 0 : -.12);
          final perspective = 5 / (5 - v.z);
          return center +
              Offset(
                v.x * scale * perspective,
                -(v.y - .25) * scale * perspective,
              );
        }).toList();
        final path = Path()..addPolygon(points, true);
        if (path.contains(position) ||
            path.getBounds().inflate(12).contains(position))
          return true;
      }
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!transparent) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            colors: dark
                ? const [Color(0xff0c2540), Color(0xff191532)]
                : const [Color(0xffd9f3ff), Color(0xffe9e3ff)],
          ).createShader(Offset.zero & size),
      );
    }
    final scale = math.min(size.width / 4.3, size.height / 3.7);
    final center = Offset(size.width / 2, size.height / 2 + 24);
    final faces = <_Face>[];
    const colors = [Color(0xff0fc4ee), Color(0xff146ff0), Color(0xff1641a5)];
    _V rotate(_V v) =>
        v.rotate(angle + (fallback ? 0 : .2), fallback ? 0 : -.12);
    Offset project(_V v) {
      final perspective = 5 / (5 - v.z);
      return center +
          Offset(v.x * scale * perspective, -(v.y - .25) * scale * perspective);
    }

    for (var index = 0; index < shapes.length; index++) {
      final poly = shapes[index];
      final front = poly.map((p) => rotate(_V(p[0], p[1], .13))).toList();
      final back = poly.map((p) => rotate(_V(p[0], p[1], -.13))).toList();
      final illumination = (.68 + .32 * math.cos(angle)).clamp(.35, 1.0);
      Color shade(Color color, double factor) => Color.fromARGB(
        255,
        (color.r * 255 * factor).round().clamp(0, 255),
        (color.g * 255 * factor).round().clamp(0, 255),
        (color.b * 255 * factor).round().clamp(0, 255),
      );
      faces.add(_Face(back, shade(colors[index], .52)));
      for (var i = 0; i < poly.length; i++) {
        final next = (i + 1) % poly.length;
        faces.add(
          _Face([
            front[i],
            front[next],
            back[next],
            back[i],
          ], shade(colors[index], .45 + .18 * (i % 3))),
        );
      }
      faces.add(_Face(front, shade(colors[index], illumination)));
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 25),
        width: scale * 2,
        height: 24,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? .25 : .08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faces) {
      final points = face.points.map(project).toList();
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, Paint()..color = face.color);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = const Color(0xff5db7ff).withValues(alpha: .45),
      );
    }
    if (!fallback) {
      final outline = Paint()
        ..color = const Color(0xff25ade5).withValues(alpha: dark ? .45 : .3)
        ..style = PaintingStyle.stroke;
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: scale * 3.25,
          height: scale * .65,
        ),
        outline,
      );
      canvas.drawCircle(
        center +
            Offset(
              math.cos(orbit) * scale * 1.6,
              math.sin(orbit) * scale * .33,
            ),
        4,
        Paint()..color = const Color(0xff28ccea),
      );
    }
  }

  @override
  bool shouldRepaint(IdentityPainter old) =>
      old.angle != angle ||
      old.orbit != orbit ||
      old.dark != dark ||
      old.fallback != fallback;
}
