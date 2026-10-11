import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/data/contact_repository.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/domain/contact_request.dart';
import 'package:yogen_portfolio/features/public/contact_session.dart';
import 'media_repository_test.dart' show MemoryStore;

class ContactStore extends MemoryStore {
  bool offline = false, loseResponse = false, failReceiptRead = false;
  int commits = 0;
  Completer<void>? gate;
  @override
  Future<StoredDocument?> get(String path) async {
    if (offline || failReceiptRead) throw const DataFailure('UNAVAILABLE');
    return super.get(path);
  }

  @override
  Future<void> commit(List<DocumentWrite> writes) async {
    commits++;
    if (gate != null) await gate!.future;
    if (offline) throw const DataFailure('UNAVAILABLE');
    await super.commit(writes);
    if (loseResponse) {
      failReceiptRead = true;
      throw TimeoutException('Simulated response loss after commit');
    }
  }
}

const input = ContactInput(
  name: 'QA visitor',
  contact: 'qa@example.invalid',
  details: 'A labelled technical contact request.',
  language: 'en',
);
void main() {
  late ContactStore store;
  late SharedPreferences prefs;
  late ContactSession session;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = ContactStore();
    session = ContactSession(ContactRepository(store), prefs, 'yogen');
  });
  tearDown(() => session.dispose());
  test('P08-T04 strict contact address and bounded brief', () {
    expect(validContactAddress('+201234567890'), true);
    for (final address in ['hello', '01123456789', 'a@b', '+012345678']) {
      expect(validContactAddress(address), false);
    }
    expect(
      const ContactInput(
        name: '',
        contact: 'bad',
        details: 'short',
        language: 'ar',
      ).validate,
      throwsA(isA<DataFailure>()),
    );
    expect(
      () => ContactInput(
        name: 'x',
        contact: 'a@b.c',
        details: 'x' * 5001,
        language: 'en',
      ).validate(),
      throwsA(isA<DataFailure>()),
    );
  });
  test(
    'P08-T04 acknowledge only after private input and receipt commit',
    () async {
      session.field('name', input.name);
      expect(await session.send(input), true);
      final id = session.confirmedId!;
      expect(
        store.docs['sites/yogen/contactRequests/$id']!['name'],
        input.name,
      );
      expect(
        store.docs['sites/yogen/contactReceipts/$id']!.keys,
        unorderedEquals(['requestId', 'receivedAt']),
      );
      expect(prefs.getString(session.key), isNull);
    },
  );
  test('P08-T05 rapid double press performs one write', () async {
    store.gate = Completer<void>();
    final first = session.send(input);
    await Future<void>.delayed(Duration.zero);
    expect(await session.send(input), false);
    store.gate!.complete();
    expect(await first, true);
    expect(store.commits, 1);
    expect(await session.send(input), false);
  });
  test(
    'P08-T05 offline unknown outcome freezes payload and persists same ID',
    () async {
      session.field('name', input.name);
      store.offline = true;
      expect(await session.send(input), false);
      final id = session.pendingId;
      expect(session.confirmedId, isNull);
      session.field('name', 'different');
      expect(session.fields['name'], input.name);
      final recovered = ContactSession(
        ContactRepository(store),
        prefs,
        'yogen',
      );
      expect(recovered.pendingId, id);
      store.offline = false;
      expect(
        await recovered.send(
          const ContactInput(
            name: 'Changed',
            contact: 'other@example.invalid',
            details: 'Changed retry input',
            language: 'ar',
          ),
        ),
        true,
      );
      expect(recovered.confirmedId, id);
      expect(store.docs['sites/yogen/contactRequests/$id']!['language'], 'en');
      recovered.dispose();
    },
  );
  test(
    'P08-T05 committed request with lost response is confirmed on retry without a new write',
    () async {
      store.loseResponse = true;
      expect(await session.send(input), false);
      final id = session.pendingId;
      expect(store.commits, 1);
      store.loseResponse = false;
      store.failReceiptRead = false;
      expect(await session.send(input), true);
      expect(session.confirmedId, id);
      expect(store.commits, 1);
    },
  );
  test(
    'P08-T05 recovery separates site scopes and clear leaves unresolved submission intact',
    () async {
      store.offline = true;
      await session.send(input);
      final id = session.pendingId;
      await session.clear();
      expect(session.pendingId, id);
      final other = ContactSession(
        ContactRepository(store, site: 'phase04-test'),
        prefs,
        'phase04-test',
      );
      expect(other.pending, isNull);
      other.dispose();
    },
  );
  test(
    'P08-T06 immutable project ID, both names and original language survive recovery',
    () async {
      store.offline = true;
      await session.send(
        const ContactInput(
          name: 'QA',
          contact: '+201234567890',
          details: 'Technical similar project request',
          language: 'ar',
          project: {
            'id': 'published-a',
            'nameAr': 'مشروع',
            'nameEn': 'Project',
          },
        ),
      );
      final recovered = ContactSession(
        ContactRepository(store),
        prefs,
        'yogen',
      );
      expect(recovered.pending!.project['id'], 'published-a');
      expect(recovered.pending!.project['nameEn'], 'Project');
      expect(recovered.pending!.language, 'ar');
      recovered.dispose();
    },
  );
  test(
    'P08-T07 staff status changes preserve submitted input and audit actor',
    () async {
      await session.send(input);
      final id = session.confirmedId!;
      final repo = ContactRepository(store);
      await repo.update(id, 'editor', 'inProgress', 'Private QA note');
      final row = (await repo.inbox()).single;
      expect(row.input.toMap(), input.toMap());
      expect(row.status, 'inProgress');
      expect(row.note, 'Private QA note');
      expect(store.docs[repo.requestPath(id)]!['updatedBy'], 'editor');
    },
  );
}
