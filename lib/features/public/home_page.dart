import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/yogen_app.dart' show tr;
import '../../core/preferences.dart';
import '../../core/viewport_visibility.dart';
import '../../data/public_content_repository.dart';
import 'depth_scene.dart';
import 'logo_admin_entry.dart';
import 'project_widgets.dart';
import 'public_shell.dart';

class StoryGeometry {
  final double viewport;
  final bool pinned;
  final int count;
  const StoryGeometry(this.viewport, this.pinned, this.count);
  double get heroTravel =>
      pinned ? math.max(1700, viewport * 2.4) - viewport : 0;
  double get heroExtent => pinned ? viewport + heroTravel : 0;
  double get stageTravel => math.max(0, count - 1) * 240.0;
  int selected(double local) => ((local.clamp(0, stageTravel) + .01) / 240)
      .floor()
      .clamp(0, math.max(0, count - 1));
  double turn(double offset) =>
      heroTravel == 0 ? 0 : (offset / heroTravel).clamp(0, 1);
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final controller = ScrollController();
  StoryGeometry? previous;
  String? selectedId;
  bool inStage = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void scroll(double target, bool reduced) {
    if (!controller.hasClients) return;
    final value = target.clamp(0.0, controller.position.maxScrollExtent);
    if (reduced) {
      controller.jumpTo(value);
    } else {
      controller.animateTo(
        value,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    final reduced = reducedMotion(c, ref);
    final value = ref.watch(publicContentProvider);
    final data = value.asData?.value;
    final projects = data?.projects ?? [];
    return LayoutBuilder(
      builder: (c, box) {
        final pinned =
            box.maxWidth >= 320 &&
            box.maxHeight >= (box.maxWidth > 900 ? 420 : 560) &&
            MediaQuery.textScalerOf(c).scale(16) <= 20 &&
            !reduced &&
            projects.every(
              (p) =>
                  p.content.title.ar.length < 100 &&
                  p.content.title.en.length < 100 &&
                  p.content.summary.ar.length < 450 &&
                  p.content.summary.en.length < 450,
            );
        final geometry = StoryGeometry(box.maxHeight, pinned, projects.length);
        if (previous != null &&
            previous!.pinned &&
            geometry.pinned &&
            previous!.heroExtent != geometry.heroExtent &&
            inStage &&
            selectedId != null) {
          final index = projects.indexWhere((p) => p.id == selectedId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && controller.hasClients && index >= 0) {
              controller.jumpTo(
                (geometry.heroExtent + index * 240).clamp(
                  0,
                  controller.position.maxScrollExtent,
                ),
              );
            }
          });
        }
        previous = geometry;
        return Focus(
          autofocus: true,
          child: CustomScrollView(
            key: const PageStorageKey('home-scroll'),
            controller: controller,
            slivers: [
              SliverToBoxAdapter(
                child: pinned
                    ? AnimatedBuilder(
                        animation: controller,
                        builder: (c, _) {
                          final offset = controller.hasClients
                              ? controller.offset
                              : 0.0;
                          return SizedBox(
                            height: geometry.heroExtent,
                            child: Stack(
                              children: [
                                Positioned(
                                  top: offset.clamp(0, geometry.heroTravel),
                                  left: 0,
                                  right: 0,
                                  child: SizedBox(
                                    height: geometry.viewport,
                                    child: HeroChapter(
                                      turn: geometry.turn(offset),
                                      visible: offset < geometry.heroExtent,
                                      storyMode: true,
                                      projects: projects,
                                      endpoint: data?.endpoint ?? '',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : AnimatedBuilder(
                        animation: controller,
                        builder: (c, _) => HeroChapter(
                          turn:
                              ((controller.hasClients ? controller.offset : 0) /
                                      math.max(600, box.maxHeight * 1.3))
                                  .clamp(0.0, 1.0),
                          projects: projects,
                          endpoint: data?.endpoint ?? '',
                        ),
                      ),
              ),
              if (value.isLoading)
                const SliverToBoxAdapter(
                  child: ContentState(builder: _identityData),
                ),
              if (value.hasError)
                SliverToBoxAdapter(
                  child: ContentState(builder: (d) => const SizedBox.shrink()),
                ),
              if (data != null && projects.isEmpty)
                SliverToBoxAdapter(
                  child: PublicFrame(
                    child: PublicMessage(
                      icon: Icons.grid_view_outlined,
                      title: tr(
                        c,
                        'أعمالنا، قريبًا هنا',
                        'Our work, coming here soon',
                      ),
                      description: tr(
                        c,
                        'نجهّز عرض مشاريعنا. تقدر تتعرف على خدماتنا وطريقة عملنا في الوقت الحالي.',
                        'We are preparing our project showcase. Explore our service and how we work in the meantime.',
                      ),
                      action: OutlinedButton(
                        onPressed: () => publicGo(c, '/services'),
                        child: Text(
                          tr(c, 'تعرف على خدماتنا', 'Explore our service'),
                        ),
                      ),
                    ),
                  ),
                ),
              if (data != null && projects.isNotEmpty)
                if (pinned)
                  SliverToBoxAdapter(
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (c, _) {
                        final local =
                            (controller.hasClients ? controller.offset : 0) -
                            geometry.heroExtent;
                        final index = geometry.selected(local);
                        selectedId = projects[index].id;
                        inStage = local >= 0 && local <= geometry.stageTravel;
                        return SizedBox(
                          height: geometry.viewport + geometry.stageTravel,
                          child: Stack(
                            children: [
                              Positioned(
                                top: local.clamp(0, geometry.stageTravel),
                                left: 0,
                                right: 0,
                                child: SizedBox(
                                  height: geometry.viewport,
                                  child: ProjectStage(
                                    project: projects[index],
                                    endpoint: data.endpoint,
                                    index: index,
                                    count: projects.length,
                                    compact: geometry.viewport < 630,
                                    onSelect: (i) => scroll(
                                      geometry.heroExtent + i * 240,
                                      reduced,
                                    ),
                                    onSkip: () => scroll(
                                      geometry.heroExtent +
                                          geometry.stageTravel +
                                          geometry.viewport,
                                      reduced,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: projects.length,
                    itemBuilder: (c, index) => PublicFrame(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index == 0) ...[
                            Text(
                              tr(
                                c,
                                'كل فكرة، لها تجربة',
                                'Every idea has its own experience',
                              ),
                              style: Theme.of(c).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 24),
                          ],
                          ProjectCard(
                            project: projects[index],
                            endpoint: data.endpoint,
                          ),
                        ],
                      ),
                    ),
                  ),
              const SliverToBoxAdapter(child: ProcessChapter()),
              SliverToBoxAdapter(
                child: PublicFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          c,
                          'خلّينا نبدأ بفكرتك.',
                          'Let’s start with your idea.',
                        ),
                        style: TextStyle(
                          fontSize: box.maxWidth < 600 ? 34 : 48,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => publicGo(c, '/contact'),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(tr(c, 'ابدأ مشروعك', 'Start your project')),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: PublicFooter()),
            ],
          ),
        );
      },
    );
  }
}

Widget _identityData(PublicContent _) => const SizedBox.shrink();

class HeroChapter extends ConsumerWidget {
  final double turn;
  final bool visible, storyMode;
  final List<PublicProject> projects;
  final String endpoint;
  const HeroChapter({
    super.key,
    this.turn = 0,
    this.visible = true,
    this.storyMode = false,
    this.projects = const [],
    this.endpoint = '',
  });
  @override
  Widget build(BuildContext c, WidgetRef ref) => PublicFrame(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    child: LayoutBuilder(
      builder: (c, b) {
        final mobile = b.maxWidth < 850;
        final compact = MediaQuery.sizeOf(c).height < 760;
        if (mobile && storyMode) {
          return _MobileStoryHero(
            turn: turn,
            visible: visible,
            projects: projects,
            endpoint: endpoint,
          );
        }
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(
                c,
                'YOGEN / تطوير برمجيات حسب الطلب',
                'YOGEN / CUSTOM SOFTWARE',
              ),
              style: TextStyle(
                color: Theme.of(c).colorScheme.tertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: mobile ? 0 : 1,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr(c, 'أفكارك تستحق', 'Your ideas deserve'),
              style: TextStyle(
                fontSize: mobile
                    ? 38
                    : compact
                    ? 48
                    : 64,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                colors: Theme.of(c).brightness == Brightness.dark
                    ? const [Color(0xff91bcff), Color(0xff6ddcf1)]
                    : const [Color(0xff125bc4), Color(0xff146a8a)],
              ).createShader(rect),
              child: Text(
                tr(c, 'تطبيقًا يليق بها.', 'software that fits.'),
                style: TextStyle(
                  fontSize: mobile
                      ? 38
                      : compact
                      ? 48
                      : 64,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr(
                c,
                'نطوّر تطبيقات برمجية حسب احتياجك. استكشف أعمالنا، وشوف نقطة البداية لمشروعك القادم.',
                'We create software around your needs. Explore our work and find the starting point for your next project.',
              ),
              style: TextStyle(
                fontSize: mobile ? 17 : 19,
                height: 1.7,
                color: Theme.of(c).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => publicGo(c, '/contact'),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(tr(c, 'ابدأ مشروعك', 'Start your project')),
                ),
                OutlinedButton(
                  onPressed: () => publicGo(c, '/work'),
                  child: Text(tr(c, 'استكشف كل الأعمال', 'Explore all work')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              tr(
                c,
                'من فكرة واضحة إلى تجربة عملية.',
                'From a clear idea to a practical experience.',
              ),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(c).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
        final scene = SizedBox(
          height: mobile
              ? 360
              : compact
              ? 400
              : 540,
          child: LogoAdminEntry(
            turn: turn,
            visible: visible,
            small: mobile,
            reduced: reducedMotion(c, ref),
            previews: projects.isEmpty
                ? null
                : HeroProjectOrbit(
                    projects: projects,
                    endpoint: endpoint,
                    visible: visible,
                  ),
          ),
        );
        return mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, const SizedBox(height: 24), scene],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 32),
                  Expanded(child: scene),
                ],
              );
      },
    ),
  );
}

class _MobileStoryHero extends ConsumerWidget {
  final double turn;
  final bool visible;
  final List<PublicProject> projects;
  final String endpoint;
  const _MobileStoryHero({
    required this.turn,
    required this.visible,
    required this.projects,
    required this.endpoint,
  });
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final colors = Theme.of(c).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(c, 'YOGEN / من الفكرة إلى التطبيق', 'YOGEN / IDEAS INTO SOFTWARE'),
          style: TextStyle(color: colors.tertiary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            c,
            'أفكارك تستحق\nتطبيقًا يليق بها.',
            'Your ideas deserve\nsoftware that fits.',
          ),
          style: TextStyle(
            fontSize: 28,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            c,
            'نطوّر تطبيقات برمجية حسب احتياجك. مرّر لاكتشاف أعمالنا.',
            'Software built around your needs. Scroll to discover our work.',
          ),
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: colors.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: LogoAdminEntry(
            turn: turn,
            visible: visible,
            small: true,
            reduced: reducedMotion(c, ref),
            previews: projects.isEmpty
                ? null
                : HeroProjectOrbit(
                    projects: projects,
                    endpoint: endpoint,
                    visible: visible,
                    small: true,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => publicGo(c, '/contact'),
                child: Text(
                  tr(c, 'ابدأ مشروعك', 'Start your project'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => publicGo(c, '/work'),
                child: Text(
                  tr(c, 'كل الأعمال', 'All work'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            c,
            '↓ مرّر لتتحرك الفكرة وتظهر الأعمال',
            '↓ Scroll to bring the idea and work into view',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Decorative published previews; the main showcase stays driven by scrolling.
class HeroProjectOrbit extends ConsumerStatefulWidget {
  final List<PublicProject> projects;
  final String endpoint;
  final bool visible, small;
  const HeroProjectOrbit({
    super.key,
    required this.projects,
    required this.endpoint,
    this.visible = true,
    this.small = false,
  });
  @override
  ConsumerState<HeroProjectOrbit> createState() => _HeroProjectOrbitState();
}

class _HeroProjectOrbitState extends ConsumerState<HeroProjectOrbit>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const positions = [
    Alignment.topRight,
    Alignment.centerLeft,
    Alignment.bottomRight,
    Alignment.topLeft,
    Alignment.centerRight,
    Alignment.bottomLeft,
  ];
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
    value: .2,
  );
  int index = 0;
  bool onScreen = true, running = false;
  bool foreground =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clock.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          running &&
          mounted &&
          widget.projects.isNotEmpty) {
        setState(() => index = (index + 1) % widget.projects.length);
        clock.forward(from: 0);
      }
    });
  }

  void visibility(bool value) {
    if (!value) {
      running = false;
      clock.stop();
    }
    if (mounted && value != onScreen) setState(() => onScreen = value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      running = false;
      clock.stop();
    }
    if (mounted)
      setState(() => foreground = state == AppLifecycleState.resumed);
  }

  @override
  void didUpdateWidget(HeroProjectOrbit old) {
    super.didUpdateWidget(old);
    final id = index < old.projects.length ? old.projects[index].id : null;
    final next = widget.projects.indexWhere((p) => p.id == id);
    index = next < 0 ? 0 : next;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (widget.projects.isEmpty) {
      running = false;
      clock.stop();
      return const SizedBox.shrink();
    }
    final prefs = ref.watch(preferencesProvider);
    final reduced = reducedMotion(c, ref);
    running =
        !prefs.paused &&
        !reduced &&
        foreground &&
        onScreen &&
        widget.visible &&
        TickerMode.valuesOf(c).enabled;
    if (running && !clock.isAnimating) clock.forward();
    if (!running) clock.stop();
    final project = widget.projects[index];
    final code = Localizations.localeOf(c).languageCode;
    final colors = Theme.of(c).colorScheme;
    return ViewportVisibility(
      onChanged: visibility,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: clock,
              child: Container(
                key: ValueKey('hero-orbit-${project.id}'),
                width: widget.small ? 104 : 156,
                height: widget.small ? 88 : 120,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: .12),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LayoutBuilder(
                          builder: (c, b) => ProjectCover(
                            project: project,
                            endpoint: widget.endpoint,
                            height: b.maxHeight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localized(project.content.title, code),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.small ? 9 : 11,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      '${index + 1} · ${widget.projects.length}',
                      key: const ValueKey('hero-orbit-index'),
                      style: TextStyle(
                        fontSize: 9,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              builder: (c, child) {
                final phase = clock.value;
                final fade = reduced
                    ? 1.0
                    : math
                          .min(1.0, math.min(phase / .15, (1 - phase) / .15))
                          .clamp(0.0, 1.0);
                return Align(
                  alignment: positions[index % positions.length],
                  child: Opacity(
                    opacity: fade,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .001)
                        ..rotateY(
                          reduced ? 0 : .15 * math.sin(phase * math.pi * 2),
                        )
                        ..rotateZ(reduced ? 0 : -.04)
                        ..translateByDouble(
                          0,
                          reduced ? 0 : 5 * math.sin(phase * math.pi * 2),
                          0,
                          1,
                        ),
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ProjectStage extends ConsumerWidget {
  final PublicProject project;
  final String endpoint;
  final int index, count;
  final bool compact;
  final void Function(int) onSelect;
  final VoidCallback onSkip;
  const ProjectStage({
    super.key,
    required this.project,
    required this.endpoint,
    required this.index,
    required this.count,
    required this.onSelect,
    required this.onSkip,
    this.compact = false,
  });
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final code = Localizations.localeOf(c).languageCode;
    if (MediaQuery.sizeOf(c).width <= 900) {
      return _MobileProjectStage(
        project: project,
        endpoint: endpoint,
        index: index,
        count: count,
        onSelect: onSelect,
        onSkip: onSkip,
      );
    }
    return Stack(
      children: [
        const Positioned.fill(child: DepthScene(identity: false)),
        PublicFrame(
          padding: EdgeInsets.symmetric(
            horizontal: 32,
            vertical: compact ? 12 : 28,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        c,
                        '02 / أعمالنا — مرّر لاكتشاف المشروع التالي',
                        '02 / OUR WORK — SCROLL TO DISCOVER',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(c).colorScheme.tertiary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onSkip,
                    child: Text(tr(c, 'تخطي المعرض', 'Skip showcase')),
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 28),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localized(project.category, code),
                              style: TextStyle(
                                color: Theme.of(c).colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            AnimatedSwitcher(
                              duration: Duration(
                                milliseconds: reducedMotion(c, ref) ? 0 : 300,
                              ),
                              child: Align(
                                key: ValueKey(project.id),
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  localized(project.content.title, code),
                                  style: TextStyle(
                                    fontSize: compact ? 30 : 44,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              localized(project.content.summary, code),
                              style: TextStyle(
                                fontSize: compact ? 16 : 18,
                                color: Theme.of(c).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => openProject(c, project.id),
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(
                                tr(c, 'استكشف المشروع', 'Explore project'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                    Expanded(
                      flex: 6,
                      child: LayoutBuilder(
                        builder: (c, b) => Center(
                          child: SizedBox(
                            height: math.min(
                              b.maxHeight - 20,
                              compact ? 240 : 420,
                            ),
                            child: Stack(
                              children: [
                                for (final layer in [2, 1])
                                  Positioned.fill(
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..setEntry(3, 2, .001)
                                        ..rotateY(-.09)
                                        ..rotateZ(layer * .06)
                                        ..translateByDouble(
                                          layer * 12.0,
                                          -layer * 12.0,
                                          -layer * 18.0,
                                          1,
                                        ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(c)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: .75),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(
                                              c,
                                            ).colorScheme.outlineVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, .001)
                                      ..rotateY(-.07)
                                      ..rotateZ(-.025),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(c).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Theme.of(
                                            c,
                                          ).colorScheme.outlineVariant,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: .18,
                                            ),
                                            blurRadius: 40,
                                            offset: const Offset(0, 20),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'YOGEN',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  letterSpacing: 2,
                                                ),
                                              ),
                                              const Spacer(),
                                              const ExcludeSemantics(
                                                child: Icon(
                                                  Icons.more_horiz,
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: ProjectCover(
                                                project: project,
                                                endpoint: endpoint,
                                                height: math.min(
                                                  b.maxHeight - 70,
                                                  compact ? 185 : 345,
                                                ),
                                                thumbnail: false,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 12 : 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: tr(c, 'المشروع السابق', 'Previous project'),
                    onPressed: index > 0 ? () => onSelect(index - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        '${index + 1} / $count',
                        key: const ValueKey('stage-index'),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr(c, 'المشروع التالي', 'Next project'),
                    onPressed: index < count - 1
                        ? () => onSelect(index + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileProjectStage extends StatelessWidget {
  final PublicProject project;
  final String endpoint;
  final int index, count;
  final void Function(int) onSelect;
  final VoidCallback onSkip;
  const _MobileProjectStage({
    required this.project,
    required this.endpoint,
    required this.index,
    required this.count,
    required this.onSelect,
    required this.onSkip,
  });
  @override
  Widget build(BuildContext c) {
    final code = Localizations.localeOf(c).languageCode;
    final colors = Theme.of(c).colorScheme;
    return Stack(
      children: [
        const Positioned.fill(child: DepthScene(identity: false)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        c,
                        '02 / مرّر للعمل التالي',
                        '02 / SCROLL TO DISCOVER',
                      ),
                      style: TextStyle(fontSize: 12, color: colors.tertiary),
                    ),
                  ),
                  TextButton(
                    onPressed: onSkip,
                    child: Text(tr(c, 'تخطي المعرض', 'Skip showcase')),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final layer in [2, 1])
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .001)
                            ..rotateY(-.06)
                            ..rotateZ(layer * .045)
                            ..translateByDouble(
                              layer * 5.0,
                              -layer * 8.0,
                              -layer * 16.0,
                              1,
                            ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                          ),
                        ),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .001)
                          ..rotateY(-.04),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: colors.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow.withValues(alpha: .12),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'YOGEN / ${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LayoutBuilder(
                                    builder: (c, b) => ProjectCover(
                                      key: ValueKey(
                                        'mobile-cover-${project.id}',
                                      ),
                                      project: project,
                                      endpoint: endpoint,
                                      height: b.maxHeight,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                localized(project.category, code),
                style: TextStyle(fontSize: 12, color: colors.tertiary),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  localized(project.content.title, code),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localized(project.content.summary, code),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => openProject(c, project.id),
                icon: const Icon(Icons.arrow_forward),
                label: Text(tr(c, 'استكشف المشروع', 'Explore project')),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: tr(c, 'المشروع السابق', 'Previous project'),
                    onPressed: index > 0 ? () => onSelect(index - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Semantics(
                      label: tr(c, 'اختيار المشروع', 'Choose project'),
                      child: DropdownButton<int>(
                        key: const ValueKey('mobile-stage-selector'),
                        isExpanded: true,
                        value: index,
                        items: List.generate(
                          count,
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text(
                              '${i + 1} / $count',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) onSelect(value);
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr(c, 'المشروع التالي', 'Next project'),
                    onPressed: index < count - 1
                        ? () => onSelect(index + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProcessChapter extends StatelessWidget {
  const ProcessChapter({super.key});
  @override
  Widget build(BuildContext c) => PublicFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(c, '03 / من الفكرة للتطبيق', '03 / FROM IDEA TO APPLICATION'),
          style: TextStyle(
            color: Theme.of(c).colorScheme.tertiary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          tr(c, 'نبني حول احتياجك.', 'Built around your needs.'),
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (c, b) {
            final width = b.maxWidth > 850 ? (b.maxWidth - 48) / 3 : b.maxWidth;
            return Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                for (final entry in [
                  (
                    '01',
                    tr(c, 'نفهم الفكرة', 'Understand the idea'),
                    tr(
                      c,
                      'نحدد الهدف والمستخدمين والأولويات معاك.',
                      'We clarify goals, users and priorities together.',
                    ),
                  ),
                  (
                    '02',
                    tr(c, 'نصمم التجربة', 'Design the experience'),
                    tr(
                      c,
                      'نحوّل المتطلبات لتجربة واضحة قابلة للمراجعة.',
                      'We turn requirements into a clear experience you can review.',
                    ),
                  ),
                  (
                    '03',
                    tr(c, 'نطوّر ونراجع', 'Build and review'),
                    tr(
                      c,
                      'ننّفذ التطبيق ونراجع الوظائف قبل التسليم.',
                      'We build the application and review its behavior before delivery.',
                    ),
                  ),
                ])
                  SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          c,
                        ).colorScheme.surface.withValues(alpha: .8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(c).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.$1,
                            style: TextStyle(
                              fontSize: 30,
                              color: Theme.of(c).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            entry.$2,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(entry.$3),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => publicGo(c, '/services'),
          child: Text(tr(c, 'اعرف أكتر عن خدماتنا', 'Explore our service')),
        ),
      ],
    ),
  );
}
