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
  void open() {
    if (opening) return;
    opening = true;
    context.go('/admin/login');
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
        label: tr(context, 'شعار YOGEN القابل للسحب', 'Draggable YOGEN logo'),
        hint: tr(
          context,
          'اسحبه إلى المربع لفتح تسجيل دخول الإدارة، أو حدده ثم اضغط المربع.',
          'Drag to the square to open admin sign-in, or select it then activate the square.',
        ),
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
              delay: const Duration(milliseconds: 220),
              maxSimultaneousDrags: 1,
              hitTestBehavior: HitTestBehavior.deferToChild,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              rootOverlay: true,
              feedback: Transform.translate(
                offset: const Offset(-48, -48),
                child: SizedBox(
                  width: 96,
                  height: 96,
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
              onDragStarted: () => setState(() {
                dragging = true;
                selected = false;
              }),
              onDragEnd: (_) {
                if (mounted) setState(() => dragging = false);
              },
              childWhenDragging: Opacity(opacity: .22, child: logo),
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
        PositionedDirectional(
          bottom: 12,
          end: 12,
          child: DragTarget<_LogoKey>(
            key: const ValueKey('admin-logo-target'),
            onWillAcceptWithDetails: (d) =>
                d.data == _LogoKey.yogen && !opening,
            onAcceptWithDetails: (_) => open(),
            builder: (c, candidates, _) {
              final ready = candidates.isNotEmpty || selected;
              return Semantics(
                label: tr(c, 'مربع دخول الإدارة', 'Admin sign-in square'),
                hint: tr(c, 'ضع الشعار هنا', 'Drop the logo here'),
                child: Tooltip(
                  message: tr(c, 'ضع الشعار هنا', 'Drop the logo here'),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: selected ? open : null,
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: Duration(
                          milliseconds:
                              widget.reduced ||
                                  MediaQuery.disableAnimationsOf(c)
                              ? 0
                              : 180,
                        ),
                        width: widget.small ? 56 : 68,
                        height: widget.small ? 56 : 68,
                        decoration: BoxDecoration(
                          color: ready
                              ? colors.primaryContainer
                              : colors.surface.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: ready ? colors.primary : colors.outline,
                            width: ready ? 2 : 1,
                          ),
                          boxShadow: ready
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: .2),
                                    blurRadius: 24,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          ready ? Icons.lock_open_outlined : Icons.crop_square,
                          color: ready
                              ? colors.onPrimaryContainer
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        PositionedDirectional(
          bottom: 20,
          start: 12,
          end: widget.small ? 80 : 96,
          child: IgnorePointer(
            child: Text(
              selected
                  ? tr(
                      c,
                      'اضغط المربع لإكمال الدخول',
                      'Activate the square to continue',
                    )
                  : tr(
                      c,
                      'اضغط قليلًا واسحب الشعار إلى المربع',
                      'Hold briefly and drag the logo to the square',
                    ),
              textAlign: TextAlign.center,
              maxLines: 3,
              style: TextStyle(
                fontSize: widget.small ? 11 : 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
