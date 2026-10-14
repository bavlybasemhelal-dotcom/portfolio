import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart' show tr;
import '../validation/scene_page.dart' show IdentityPainter;
import 'depth_scene.dart';

enum _LogoKey { yogen }

/// A visual doorway to sign-in. Authorization remains in the admin router/backend.
class LogoAdminEntry extends StatefulWidget {
  final double turn;
  final bool visible, small, reduced;
  final Widget? previews;
  const LogoAdminEntry({
    super.key,
    required this.turn,
    required this.visible,
    this.small = false,
    this.reduced = false,
    this.previews,
  });
  @override
  State<LogoAdminEntry> createState() => _LogoAdminEntryState();
}

class _LogoAdminEntryState extends State<LogoAdminEntry> {
  bool dragging = false, selected = false, opening = false, focused = false;

  void select() => setState(() => selected = !selected);
  Future<void> open() async {
    if (opening) return;
    opening = true;
    HapticFeedback.mediumImpact();
    if (mounted) {
      context.go('/admin/login');
    }
  }

  Widget draggable(Widget logo, double angle, double orbit, bool dark) {
    return Focus(
      onFocusChange: (value) => setState(() => focused = value),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          select();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        button: true,
        selected: selected,
        label: tr(context, 'شعار YOGEN', 'YOGEN logo'),
        onTap: select,
        child: MouseRegion(
          cursor: dragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          hitTestBehavior: HitTestBehavior.deferToChild,
          child: GestureDetector(
            onTap: select,
            child: LongPressDraggable<_LogoKey>(
              key: const ValueKey('admin-logo-drag'),
              data: _LogoKey.yogen,
              delay: const Duration(milliseconds: 100),
              maxSimultaneousDrags: 1,
              hitTestBehavior: HitTestBehavior.deferToChild,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              rootOverlay: true,
              feedback: Material(
                type: MaterialType.transparency,
                child: Transform.translate(
                  offset: const Offset(-52, -52),
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: CustomPaint(
                      painter: IdentityPainter(
                        angle: angle,
                        orbit: orbit,
                        dark: dark,
                        transparent: true,
                      ),
                    ),
                  ),
                ),
              ),
              onDragStarted: () => setState(() {
                dragging = true;
                selected = false;
              }),
              onDragEnd: (_) {
                if (mounted) setState(() => dragging = false);
              },
              childWhenDragging: Opacity(opacity: .18, child: logo),
              child: logo,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final colors = Theme.of(c).colorScheme;
    final dark = Theme.of(c).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (c, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final radius = math.min(w, h) * .12;
        final cubeCenter = Offset(w * .19, h * .2);
        final targetSize = math.max(radius * 2.8, 92.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            DepthScene(
              turn: widget.turn,
              visible: widget.visible && !dragging,
              identityBuilder: draggable,
            ),
            if (focused)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.primary, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            if (widget.previews != null)
              Positioned(
                top: widget.small ? 8 : 32,
                bottom: widget.small ? 80 : 112,
                left: widget.small ? 8 : 12,
                right: widget.small ? 8 : 12,
                child: widget.previews!,
              ),
            // Secret 3D wireframe cube portal target (no explanatory hints/text)
            Positioned(
              left: cubeCenter.dx - targetSize / 2,
              top: cubeCenter.dy - targetSize / 2,
              width: targetSize,
              height: targetSize,
              child: DragTarget<_LogoKey>(
                key: const ValueKey('admin-logo-target'),
                onWillAcceptWithDetails: (d) =>
                    d.data == _LogoKey.yogen && !opening,
                onAcceptWithDetails: (_) => open(),
                builder: (c, candidates, _) {
                  final ready = candidates.isNotEmpty || (selected && dragging);
                  return Semantics(
                    button: true,
                    selected: selected,
                    onTap: selected ? open : null,
                    child: MouseRegion(
                      cursor: ready || selected
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: GestureDetector(
                        onTap: selected ? open : null,
                        behavior: HitTestBehavior.translucent,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          decoration: ready
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      (dark
                                              ? const Color(0xff0fc4ee)
                                              : const Color(0xff146ff0))
                                          .withValues(alpha: 0.38),
                                      (dark
                                              ? const Color(0xff146ff0)
                                              : const Color(0xff1641a5))
                                          .withValues(alpha: 0.16),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.55, 1.0],
                                  ),
                                  border: Border.all(
                                    color: (dark
                                            ? const Color(0xff0fc4ee)
                                            : const Color(0xff146ff0))
                                        .withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (dark
                                              ? const Color(0xff0fc4ee)
                                              : const Color(0xff146ff0))
                                          .withValues(alpha: 0.35),
                                      blurRadius: 28,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                )
                              : const BoxDecoration(
                                  color: Colors.transparent,
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
