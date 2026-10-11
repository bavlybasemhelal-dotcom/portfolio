import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/project_repository.dart';
import '../../domain/project.dart';
import '../../core/preferences.dart';
import '../../app/yogen_app.dart' show tr;

final editorLeaveGuardProvider = Provider((ref) => EditorLeaveGuard());

class EditorLeaveGuard {
  Future<bool> Function(BuildContext)? callback;
  Future<bool> confirm(BuildContext context) async =>
      await callback?.call(context) ?? true;
}

/// Account/site scoped local recovery, never used by the anonymous reader.
class DraftRecovery {
  final SharedPreferences storage;
  final String actor, site;
  DraftRecovery(this.storage, this.actor, this.site);
  String key(String id) => 'draft.v7.$site.$actor.$id';
  Future<void> save(
    String id,
    ProjectContent value,
    String note,
    int revision,
  ) => storage.setString(
    key(id),
    jsonEncode({
      'content': value.toMap(),
      'note': note,
      'revision': revision,
      'at': DateTime.now().toUtc().toIso8601String(),
    }),
  );
  Map<String, dynamic>? read(String id) {
    try {
      final value = storage.getString(key(id));
      return value == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String id) async {
    await storage.remove(key(id));
  }

  List<String> get pendingIds => storage
      .getKeys()
      .where((k) => k.startsWith('draft.v7.$site.$actor.'))
      .map((k) => k.substring('draft.v7.$site.$actor.'.length))
      .toList();
}

/// Confirmed server revision and editable form are separate. Edits arriving
/// during a save stay dirty; failed/conflicting writes preserve local recovery.
class ProjectEditorSession extends ChangeNotifier {
  final String id;
  final ProjectRepository repository;
  final DraftRecovery recovery;
  ProjectContent content;
  String note;
  int revision, generation = 0;
  bool dirty = false, busy = false, disposed = false, recovered = false;
  Object? failure;
  DateTime? confirmedAt;
  Timer? autosave;
  Future<void> recoveryQueue = Future.value();
  ProjectEditorSession(
    this.id,
    this.repository,
    this.recovery,
    ProjectDraft? draft,
  ) : content = draft?.content ?? const ProjectContent(),
      note = draft?.internalNote ?? '',
      revision = draft?.revision ?? 0,
      confirmedAt = draft?.updatedAt;
  void changed(ProjectContent value, String internalNote) {
    content = value;
    note = internalNote;
    dirty = true;
    failure = null;
    generation++;
    persist();
    autosave?.cancel();
    autosave = Timer(const Duration(seconds: 2), () => unawaited(save()));
    notifyListeners();
  }

  Future<void> persist() {
    final v = content, n = note, r = revision;
    recoveryQueue = recoveryQueue
        .catchError((_) {})
        .then((_) => recovery.save(id, v, n, r));
    return recoveryQueue;
  }

  void restoreRecovery(Map<String, dynamic> value) {
    recovered = true;
    // Keep the old base revision. A newer remote version must raise conflict.
    revision = (value['revision'] as num).toInt();
    changed(
      ProjectContent.fromMap(
        Map<String, dynamic>.from(value['content'] as Map),
      ),
      value['note'] as String? ?? '',
    );
  }

  Future<bool> save() async {
    if (busy) return false;
    if (!dirty && revision > 0) return true;
    autosave?.cancel();
    busy = true;
    failure = null;
    notifyListeners();
    final epoch = generation, v = content, n = note;
    try {
      await persist();
      revision = await repository.saveDraft(
        id,
        v,
        expectedRevision: revision,
        internalNote: n,
      );
      confirmedAt = DateTime.now().toUtc();
      await recoveryQueue;
      dirty = epoch != generation;
      if (dirty) {
        await persist();
      } else {
        // Serialize deletion with local writes. A change during deletion queues
        // its recovery after it, so no newer edit is cleared by the old save.
        recoveryQueue = recoveryQueue.then((_) => recovery.clear(id));
        await recoveryQueue;
        dirty = epoch != generation;
        if (dirty) await persist();
      }
      return true;
    } catch (e) {
      failure = e;
      try {
        await persist();
      } catch (_) {
        /* keep form in memory */
      }
      return false;
    } finally {
      busy = false;
      if (!disposed) {
        notifyListeners();
        if (dirty && failure == null) {
          autosave = Timer(const Duration(seconds: 2), () => unawaited(save()));
        }
      }
    }
  }

  Future<bool> canLeave(BuildContext context) async {
    if (!dirty) return true;
    final choice = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'تعديلات لم تصل للحفظ', 'Changes are not saved yet')),
        content: Text(
          tr(
            c,
            'تقدر تحفظها، أو تخرج وتستكمل النسخة المحلية بعد تسجيل الدخول بنفس الحساب.',
            'Save them, or leave and recover the local draft when you sign in with this account.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 0),
            child: Text(tr(c, 'البقاء', 'Stay')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 1),
            child: Text(tr(c, 'الخروج مع نسخة استكمال', 'Leave with recovery')),
          ),
          FilledButton(
            onPressed: busy ? null : () => Navigator.pop(c, 2),
            child: Text(tr(c, 'حفظ وخروج', 'Save and leave')),
          ),
        ],
      ),
    );
    if (choice == 1) {
      await persist();
      return true;
    }
    return choice == 2 ? await save() && !dirty : false;
  }

  @override
  void dispose() {
    disposed = true;
    autosave?.cancel();
    if (dirty) unawaited(persist());
    super.dispose();
  }
}

final draftRecoveryProvider = Provider.family<DraftRecovery, String>(
  (ref, actor) => DraftRecovery(
    ref.read(preferencesStorageProvider),
    actor,
    const String.fromEnvironment('YOGEN_SITE', defaultValue: 'yogen'),
  ),
);
