import 'document_store.dart';

Future<List<StoredDocument>> readCollection(
  DocumentStore store,
  String collection,
) => store is FirestoreRestStore
    ? store.listAll(collection)
    : store.list(collection, limit: 100);
