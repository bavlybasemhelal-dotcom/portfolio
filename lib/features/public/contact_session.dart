import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/admin_session.dart' show activeSite;
import '../../core/preferences.dart';
import '../../data/contact_repository.dart';
import '../../data/document_store.dart';
import '../../domain/contact_request.dart';

class ContactSession extends ChangeNotifier {
  final ContactRepository repository;
  final SharedPreferences storage;
  final String key;
  Map<String, String> fields = {};
  ContactInput? pending;
  String? pendingId, confirmedId, error;
  bool busy = false;
  ContactSession(this.repository, this.storage, String site)
    : key = 'contact.v8.$site' {
    try {
      final raw = storage.getString(key);
      if (raw == null) return;
      final v = jsonDecode(raw) as Map;
      fields = Map<String, String>.from(v['fields'] as Map);
      pendingId = v['id'] as String?;
      if (pendingId != null) {
        pending = ContactInput.fromMap(
          Map<String, dynamic>.from(v['pending'] as Map),
        );
        pending!.validate();
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(pendingId!)) {
          throw const FormatException();
        }
      }
    } catch (_) {
      fields = {};
      pending = null;
      pendingId = null;
    }
  }
  Future<void> persist() async {
    final saved = await storage.setString(
      key,
      jsonEncode({
        'fields': fields,
        'id': pendingId,
        'pending': pending?.toMap(),
      }),
    );
    if (!saved) throw const DataFailure('local_save_failed');
  }

  void field(String name, String value) {
    if (busy || pending != null || confirmedId != null) return;
    fields = {...fields, name: value};
    persist().catchError((Object _) {});
  }

  Future<bool> send(ContactInput input) async {
    if (busy || confirmedId != null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final frozen = pending ?? input;
      frozen.validate();
      pending = frozen;
      pendingId ??= newContactId();
      // Persist before any write so a lost response/reload can reuse its ID.
      await persist();
      await repository.submit(pendingId!, frozen);
      confirmedId = pendingId;
      pending = null;
      pendingId = null;
      fields = {};
      // A local cleanup failure cannot turn an acknowledged server write
      // into a retry under a fresh ID.
      await storage.remove(key).catchError((Object _) => false);
      return true;
    } catch (e) {
      error = e is DataFailure ? e.code : 'uncertain';
      if ([
        'PERMISSION_DENIED',
        'INVALID_ARGUMENT',
        'invalid_contact_input',
        'invalid_request_id',
        'local_save_failed',
      ].contains(error)) {
        pending = null;
        pendingId = null;
        await persist().catchError((Object _) {});
      }
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    if (busy || pending != null) return;
    fields = {};
    confirmedId = null;
    error = null;
    await storage.remove(key);
    notifyListeners();
  }
}

final contactSessionProvider = Provider<ContactSession>((ref) {
  final session = ContactSession(
    ref.watch(contactRepositoryProvider),
    ref.watch(preferencesStorageProvider),
    activeSite,
  );
  ref.onDispose(session.dispose);
  return session;
});
