import '../auth/account_auth.dart';
import 'document_store.dart';
import 'read_collection.dart';

class PendingAccount implements Exception {
  final AuthAccount account;
  final String login;
  const PendingAccount(this.account, this.login);
  @override
  String toString() => 'account_created_role_pending';
}

class AccountsRepository {
  final DocumentStore store;
  final FirebaseAuthApi api;
  final String actor, site;
  AccountsRepository(
    this.store,
    this.api, {
    required this.actor,
    this.site = 'yogen',
  });
  String path(String uid) => 'sites/$site/adminUsers/$uid';
  Future<void> requireManager() async {
    final role = await store.get(path(actor));
    if (role?.data['role'] != 'manager' || role?.data['enabled'] != true) {
      throw const DataFailure('manager_required');
    }
  }

  Future<AuthAccount> createEditor(String login, String password) async {
    await requireManager();
    final name = LoginIdentity.normalize(login);
    final account = await api.register(name, password);
    try {
      await grantEditor(account, name);
    } catch (_) {
      throw PendingAccount(account, name);
    }
    return account;
  }

  Future<void> grantEditor(AuthAccount account, String login) async {
    await requireManager();
    await store.commit([
      DocumentWrite.set(path(account.uid), {
        'uid': account.uid,
        'loginName': LoginIdentity.normalize(login),
        'authEmail': account.email,
        'recoveryKind': 'owner',
        'role': 'editor',
        'enabled': true,
        'createdAt': serverTime,
        'createdBy': actor,
        'updatedAt': serverTime,
        'updatedBy': actor,
      }),
    ]);
  }

  Future<List<StoredDocument>> list() async {
    await requireManager();
    return readCollection(store, 'sites/$site/adminUsers');
  }

  Future<void> setEnabled(String uid, bool enabled) async {
    await requireManager();
    if (uid == actor) throw const DataFailure('cannot_disable_current_manager');
    await store.transaction((tx) async {
      final old = await tx.get(path(uid));
      if (old == null || old.data['role'] != 'editor') {
        throw const DataFailure('editor_missing');
      }
      tx.set(path(uid), {
        ...old.data,
        'enabled': enabled,
        'updatedAt': serverTime,
        'updatedBy': actor,
      });
    });
  }
}
