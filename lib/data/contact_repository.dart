import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/admin_session.dart' show activeSite;
import '../core/firebase_config.dart';
import '../domain/contact_request.dart';
import 'document_store.dart';
import 'read_collection.dart';

class ContactRepository {
  final DocumentStore store;
  final String site;
  ContactRepository(this.store, {this.site = 'yogen'});
  String requestPath(String id) => 'sites/$site/contactRequests/$id';
  String receiptPath(String id) => 'sites/$site/contactReceipts/$id';
  Future<bool> confirmed(String id) async {
    final receipt = await store.get(receiptPath(id));
    return receipt?.data['requestId'] == id &&
        receipt?.data['receivedAt'] is DateTime;
  }

  Future<void> submit(String id, ContactInput input) async {
    input.validate();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw const DataFailure('invalid_request_id');
    }
    if (await confirmed(id)) return;
    // Immutable pair: a retry uses the same random ID and never overwrites input.
    // Receipts contain no personal data; listing receipts is denied by rules.
    try {
      await store.commit([
        DocumentWrite.set(requestPath(id), {
          ...input.toMap(),
          'requestId': id,
          'createdAt': serverTime,
          'status': 'new',
          'note': '',
          'updatedAt': serverTime,
          'updatedBy': '',
        }),
        DocumentWrite.set(receiptPath(id), {
          'requestId': id,
          'receivedAt': serverTime,
        }),
      ]);
    } catch (_) {
      if (await confirmed(id)) return;
      rethrow;
    }
  }

  Future<List<ContactRequest>> inbox() async {
    final rows = (await readCollection(
      store,
      'sites/$site/contactRequests',
    )).map(ContactRequest.fromDocument).toList();
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<void> update(
    String id,
    String actor,
    String status,
    String note,
  ) async {
    if (!['new', 'inProgress', 'closed'].contains(status) ||
        note.length > 5000) {
      throw const DataFailure('invalid_contact_update');
    }
    await store.transaction((tx) async {
      final current = await tx.get(requestPath(id));
      if (current == null) throw const DataFailure('NOT_FOUND');
      tx.set(requestPath(id), {
        ...current.data,
        'status': status,
        'note': note,
        'updatedAt': serverTime,
        'updatedBy': actor,
      });
    });
  }
}

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  final store = FirestoreRestStore(
    projectId: FirebaseConfig.projectId,
    token: () async => null,
  );
  ref.onDispose(store.close);
  return ContactRepository(store, site: activeSite);
});
