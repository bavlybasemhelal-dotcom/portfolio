import 'package:flutter/material.dart';

/// Reports visibility after layout; does not poll or create its own ticker.
/// The child must reserve its final size so that deferred content stays stable.
class ViewportVisibility extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool> onChanged;
  const ViewportVisibility({
    super.key,
    required this.child,
    required this.onChanged,
  });
  @override
  State<ViewportVisibility> createState() => _ViewportVisibilityState();
}

class _ViewportVisibilityState extends State<ViewportVisibility>
    with WidgetsBindingObserver {
  ScrollPosition? position;
  bool scheduled = false;
  bool? visible;
  bool get foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != position) {
      position?.removeListener(check);
      position = next;
      next?.addListener(check);
    }
    check();
  }

  void check() {
    if (scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final next =
          foreground &&
          (box.localToGlobal(Offset.zero) & box.size).overlaps(
            Offset.zero & MediaQuery.sizeOf(context),
          );
      if (next != visible) {
        visible = next;
        widget.onChanged(next);
      }
    });
  }

  @override
  void didChangeMetrics() => check();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (visible != false) {
        visible = false;
        widget.onChanged(false);
      }
    } else {
      check();
    }
  }

  @override
  void didUpdateWidget(ViewportVisibility old) {
    super.didUpdateWidget(old);
    check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    position?.removeListener(check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
