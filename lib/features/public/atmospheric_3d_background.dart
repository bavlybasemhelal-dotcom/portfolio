import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/preferences.dart';

/// 3D Vector for mathematical projection
class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);

  _Vec3 rotate(double yaw, double pitch, double roll) {
    // Yaw (around Y axis)
    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final x1 = x * cosY + z * sinY;
    final y1 = y;
    final z1 = -x * sinY + z * cosY;

    // Pitch (around X axis)
    final cosP = math.cos(pitch), sinP = math.sin(pitch);
    final x2 = x1;
    final y2 = y1 * cosP - z1 * sinP;
    final z2 = y1 * sinP + z1 * cosP;

    // Roll (around Z axis)
    final cosR = math.cos(roll), sinR = math.sin(roll);
    return _Vec3(
      x2 * cosR - y2 * sinR,
      x2 * sinR + y2 * cosR,
      z2,
    );
  }
}

class _Face3D {
  final List<_Vec3> points;
  final Color baseColor;
  const _Face3D(this.points, this.baseColor);

  double get depth =>
      points.fold<double>(0, (sum, p) => sum + p.z) / points.length;
}

/// A floating 3D shape definition in space
class _PolyObject {
  final _Vec3 center;
  final double size;
  final List<List<int>> faceIndices;
  final List<_Vec3> vertices;
  final Color primaryColor;
  final double speedYaw, speedPitch, speedRoll;
  final double phase;

  _PolyObject({
    required this.center,
    required this.size,
    required this.vertices,
    required this.faceIndices,
    required this.primaryColor,
    required this.speedYaw,
    required this.speedPitch,
    required this.speedRoll,
    required this.phase,
  });

  static _PolyObject createOctahedron({
    required _Vec3 center,
    required double size,
    required Color color,
    required double speedYaw,
    required double speedPitch,
    required double phase,
  }) {
    final v = [
      const _Vec3(1, 0, 0),
      const _Vec3(-1, 0, 0),
      const _Vec3(0, 1, 0),
      const _Vec3(0, -1, 0),
      const _Vec3(0, 0, 1),
      const _Vec3(0, 0, -1),
    ];
    final faces = [
      [0, 2, 4],
      [2, 1, 4],
      [1, 3, 4],
      [3, 0, 4],
      [2, 0, 5],
      [1, 2, 5],
      [3, 1, 5],
      [0, 3, 5],
    ];
    return _PolyObject(
      center: center,
      size: size,
      vertices: v,
      faceIndices: faces,
      primaryColor: color,
      speedYaw: speedYaw,
      speedPitch: speedPitch,
      speedRoll: speedYaw * 0.5,
      phase: phase,
    );
  }

  static _PolyObject createCube({
    required _Vec3 center,
    required double size,
    required Color color,
    required double speedYaw,
    required double speedPitch,
    required double phase,
  }) {
    final v = [
      const _Vec3(-1, -1, -1),
      const _Vec3(1, -1, -1),
      const _Vec3(1, 1, -1),
      const _Vec3(-1, 1, -1),
      const _Vec3(-1, -1, 1),
      const _Vec3(1, -1, 1),
      const _Vec3(1, 1, 1),
      const _Vec3(-1, 1, 1),
    ];
    final faces = [
      [0, 1, 2, 3], // Back
      [4, 5, 6, 7], // Front
      [0, 4, 7, 3], // Left
      [1, 5, 6, 2], // Right
      [3, 2, 6, 7], // Top
      [0, 1, 5, 4], // Bottom
    ];
    return _PolyObject(
      center: center,
      size: size,
      vertices: v,
      faceIndices: faces,
      primaryColor: color,
      speedYaw: speedYaw,
      speedPitch: speedPitch,
      speedRoll: speedPitch * 0.7,
      phase: phase,
    );
  }

  static _PolyObject createTetrahedron({
    required _Vec3 center,
    required double size,
    required Color color,
    required double speedYaw,
    required double speedPitch,
    required double phase,
  }) {
    const s = 1.0;
    final v = [
      const _Vec3(s, s, s),
      const _Vec3(-s, -s, s),
      const _Vec3(-s, s, -s),
      const _Vec3(s, -s, -s),
    ];
    final faces = [
      [0, 1, 2],
      [0, 3, 1],
      [0, 2, 3],
      [1, 3, 2],
    ];
    return _PolyObject(
      center: center,
      size: size,
      vertices: v,
      faceIndices: faces,
      primaryColor: color,
      speedYaw: speedYaw,
      speedPitch: speedPitch,
      speedRoll: 0.1,
      phase: phase,
    );
  }
}

/// Floating cyber star / ambient particle
class _Particle {
  final double relX, relY, relZ;
  final double radius;
  final double speed;
  final Color color;
  const _Particle(this.relX, this.relY, this.relZ, this.radius, this.speed, this.color);
}

/// Professional 3D Geometric Atmospheric Background
class Atmospheric3DBackground extends ConsumerStatefulWidget {
  const Atmospheric3DBackground({super.key});

  @override
  ConsumerState<Atmospheric3DBackground> createState() =>
      _Atmospheric3DBackgroundState();
}

class _Atmospheric3DBackgroundState extends ConsumerState<Atmospheric3DBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  bool _resumed = true;

  bool get _isTesting =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_isTesting) {
      _clock.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (!_resumed) {
      _clock.stop();
    } else {
      if (!_isTesting && !_clock.isAnimating) _clock.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final reduced = prefs.reduced ||
        prefs.paused ||
        MediaQuery.disableAnimationsOf(context) ||
        _isTesting ||
        !TickerMode.valuesOf(context).enabled;
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (reduced && _clock.isAnimating) {
      _clock.stop();
    } else if (!reduced && _resumed && !_clock.isAnimating) {
      _clock.repeat();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (c, _) => CustomPaint(
          painter: _Atmospheric3DPainter(
            progress: reduced ? 0.25 : _clock.value,
            dark: dark,
            reduced: reduced,
          ),
          isComplex: true,
          willChange: !reduced,
        ),
      ),
    );
  }
}

class _Atmospheric3DPainter extends CustomPainter {
  final double progress;
  final bool dark;
  final bool reduced;

  _Atmospheric3DPainter({
    required this.progress,
    required this.dark,
    required this.reduced,
  });

  static final List<_Particle> _particles = List.generate(35, (i) {
    final rnd = math.Random(i * 197 + 42);
    final x = rnd.nextDouble();
    final y = rnd.nextDouble();
    final z = rnd.nextDouble() * 0.8 + 0.2;
    final r = rnd.nextDouble() * 2.2 + 1.2;
    final speed = rnd.nextDouble() * 0.4 + 0.15;
    final colors = [
      const Color(0xff12c6eb),
      const Color(0xff1678f5),
      const Color(0xff7928ca),
      const Color(0xff91bcff),
    ];
    return _Particle(x, y, z, r, speed, colors[i % colors.length]);
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final t = progress * math.pi * 2;

    // 1. Atmospheric Ambient Aura Orbs (Deep Soft Glowing Lights)
    _drawAmbientGlows(canvas, size, t);

    // 2. Subtle Cyber Grid Floor / Depth Horizon
    _drawCyberGrid(canvas, size, t);

    // 3. Floating 3D Polyhedral Crystals
    _drawFloating3DPolyhedra(canvas, size, t);

    // 4. Floating 3D Orbital Rings
    _drawOrbitalRings(canvas, size, t);

    // 5. Star Dust & Micro Depth Particles
    _drawParticles(canvas, size, t);
  }

  void _drawAmbientGlows(Canvas canvas, Size size, double t) {
    final aura1 = Offset(
      size.width * 0.82 + math.sin(t * 0.7) * 45,
      size.height * 0.15 + math.cos(t * 0.6) * 35,
    );
    final aura2 = Offset(
      size.width * 0.12 + math.cos(t * 0.8) * 40,
      size.height * 0.60 + math.sin(t * 0.5) * 50,
    );
    final aura3 = Offset(
      size.width * 0.75 + math.sin(t * 0.5) * 50,
      size.height * 0.85 + math.cos(t * 0.7) * 40,
    );

    // Cyan Glow Top Right
    final r1 = math.min(size.width, size.height) * 0.42;
    canvas.drawCircle(
      aura1,
      r1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff12c6eb).withValues(alpha: dark ? 0.14 : 0.08),
            const Color(0xff1678f5).withValues(alpha: dark ? 0.06 : 0.03),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: aura1, radius: r1)),
    );

    // Royal Blue Glow Center Left
    final r2 = math.min(size.width, size.height) * 0.48;
    canvas.drawCircle(
      aura2,
      r2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff1678f5).withValues(alpha: dark ? 0.16 : 0.09),
            const Color(0xff0c2540).withValues(alpha: dark ? 0.07 : 0.04),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: aura2, radius: r2)),
    );

    // Cosmic Violet Glow Bottom Right
    final r3 = math.min(size.width, size.height) * 0.45;
    canvas.drawCircle(
      aura3,
      r3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff7928ca).withValues(alpha: dark ? 0.13 : 0.07),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: aura3, radius: r3)),
    );
  }

  void _drawCyberGrid(Canvas canvas, Size size, double t) {
    final gridPaint = Paint()
      ..color = (dark ? const Color(0xff12c6eb) : const Color(0xff1678f5))
          .withValues(alpha: dark ? 0.035 : 0.025)
      ..strokeWidth = 1.0;

    // Horizontal perspective lines near bottom
    final baseline = size.height * 0.75;
    for (int i = 0; i < 6; i++) {
      final y = baseline + (i * i * 8.0);
      if (y < size.height) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }
  }

  void _drawFloating3DPolyhedra(Canvas canvas, Size size, double t) {
    // We position 4 floating geometric objects around the scene margins
    final objects = [
      // Top Left: Glowing Cyan Octahedron
      _PolyObject.createOctahedron(
        center: _Vec3(
          size.width * 0.08 + math.sin(t * 0.6) * 18,
          size.height * 0.18 + math.cos(t * 0.5) * 22,
          1.2,
        ),
        size: math.min(size.width, size.height) * 0.045 + 16,
        color: const Color(0xff12c6eb),
        speedYaw: 0.9,
        speedPitch: 0.6,
        phase: 0.0,
      ),
      // Top Right: Royal Blue 3D Cube
      _PolyObject.createCube(
        center: _Vec3(
          size.width * 0.92 + math.cos(t * 0.7) * 20,
          size.height * 0.28 + math.sin(t * 0.8) * 24,
          1.5,
        ),
        size: math.min(size.width, size.height) * 0.04 + 14,
        color: const Color(0xff1678f5),
        speedYaw: -0.7,
        speedPitch: 0.8,
        phase: 1.2,
      ),
      // Center Right: Futuristic Tetrahedron
      _PolyObject.createTetrahedron(
        center: _Vec3(
          size.width * 0.88 + math.sin(t * 0.5) * 25,
          size.height * 0.72 + math.cos(t * 0.6) * 20,
          1.0,
        ),
        size: math.min(size.width, size.height) * 0.05 + 18,
        color: const Color(0xff91bcff),
        speedYaw: 1.1,
        speedPitch: -0.5,
        phase: 2.5,
      ),
      // Bottom Left: Violet Octahedron
      _PolyObject.createOctahedron(
        center: _Vec3(
          size.width * 0.14 + math.cos(t * 0.6) * 22,
          size.height * 0.82 + math.sin(t * 0.7) * 18,
          1.3,
        ),
        size: math.min(size.width, size.height) * 0.038 + 12,
        color: const Color(0xff7928ca),
        speedYaw: -0.8,
        speedPitch: -0.6,
        phase: 3.8,
      ),
    ];

    for (final obj in objects) {
      _render3DObject(canvas, obj, t);
    }
  }

  void _render3DObject(Canvas canvas, _PolyObject obj, double t) {
    final yaw = t * obj.speedYaw + obj.phase;
    final pitch = t * obj.speedPitch + obj.phase * 0.7;
    final roll = t * obj.speedRoll;

    // Transform and project vertices
    final rotated = obj.vertices.map((v) => v.rotate(yaw, pitch, roll)).toList();

    // Build faces
    final faces = <_Face3D>[];
    for (final f in obj.faceIndices) {
      final facePts = f.map((idx) => rotated[idx]).toList();
      faces.add(_Face3D(facePts, obj.primaryColor));
    }

    // Depth sort faces
    faces.sort((a, b) => a.depth.compareTo(b.depth));

    final centerOffset = Offset(obj.center.x, obj.center.y);
    final scale = obj.size;

    for (final face in faces) {
      final projected = face.points.map((p) {
        final persp = 4.0 / (4.0 - p.z * 0.35);
        return centerOffset + Offset(p.x * scale * persp, p.y * scale * persp);
      }).toList();

      final path = Path()..addPolygon(projected, true);

      // Face fill with soft glassmorphism opacity
      final illumination = (0.55 + 0.45 * math.cos(yaw + face.depth)).clamp(0.25, 1.0);
      final faceColor = obj.primaryColor.withValues(
        alpha: (dark ? 0.18 : 0.12) * illumination,
      );

      canvas.drawPath(path, Paint()..color = faceColor);

      // Neon glowing wireframe stroke
      final strokeColor = obj.primaryColor.withValues(
        alpha: (dark ? 0.55 : 0.40) * illumination,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = strokeColor,
      );
    }
  }

  void _drawOrbitalRings(Canvas canvas, Size size, double t) {
    // 3D Orbital ring floating on the background
    final ringCenter = Offset(
      size.width * 0.08 + math.sin(t * 0.6) * 18,
      size.height * 0.18 + math.cos(t * 0.5) * 22,
    );
    final ringRadius = math.min(size.width, size.height) * 0.08 + 24;

    canvas.save();
    canvas.translate(ringCenter.dx, ringCenter.dy);

    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: ringRadius * 2.0,
      height: ringRadius * 0.55,
    );

    canvas.drawOval(
      ringRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xff12c6eb).withValues(alpha: dark ? 0.28 : 0.18),
    );

    // Orbiting spark
    final sparkAngle = t * 1.8;
    final sparkX = math.cos(sparkAngle) * ringRadius;
    final sparkY = math.sin(sparkAngle) * ringRadius * 0.275;
    canvas.drawCircle(
      Offset(sparkX, sparkY),
      6.0,
      Paint()..color = const Color(0xff12c6eb).withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      Offset(sparkX, sparkY),
      2.5,
      Paint()..color = const Color(0xff12c6eb).withValues(alpha: 0.95),
    );

    canvas.restore();
  }

  void _drawParticles(Canvas canvas, Size size, double t) {
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final currentY = (p.relY - (t * p.speed * 0.05)) % 1.0;
      final px = p.relX * size.width + math.sin(t * 0.5 + i) * 12;
      final py = currentY * size.height;

      final pulse = 0.5 + 0.5 * math.sin(t * 1.5 + i * 2);
      final alpha = (dark ? 0.35 : 0.22) * pulse * p.relZ;

      canvas.drawCircle(
        Offset(px, py),
        p.radius,
        Paint()..color = p.color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_Atmospheric3DPainter old) =>
      old.progress != progress || old.dark != dark || old.reduced != reduced;
}
