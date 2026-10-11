import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/firebase_config.dart';
import '../data/document_store.dart';
import 'account_auth.dart';

const activeSite = String.fromEnvironment('YOGEN_SITE', defaultValue: 'yogen');
final accountAuthProvider = FutureProvider<AccountAuth>((ref) async {
  final config = FirebaseConfig.environment;
  if (!config.isConfigured) throw const AuthFailure('firebase_not_configured');
  final AccountAuth auth;
  if (!kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.linux,
      ].contains(defaultTargetPlatform)) {
    final rest = RestAccountAuth(
      FirebaseAuthApi(config.apiKey),
      const SecureSessionVault(),
    );
    ref.onDispose(() => unawaited(rest.dispose()));
    auth = rest;
  } else {
    auth = await SdkAccountAuth.connect(config);
  }
  await auth.restore();
  return auth;
});
final documentStoreProvider = FutureProvider<FirestoreRestStore>((ref) async {
  final auth = await ref.watch(accountAuthProvider.future);
  final store = FirestoreRestStore(
    projectId: FirebaseConfig.projectId,
    token: auth.token,
  );
  ref.onDispose(store.close);
  return store;
});

class AdminAccess {
  final String? uid, loginName, role;
  final bool enabled;
  const AdminAccess({
    this.uid,
    this.loginName,
    this.role,
    this.enabled = false,
  });
  bool get allowed => enabled && ['manager', 'editor'].contains(role);
  bool get manager => allowed && role == 'manager';
}

final adminSessionProvider = AsyncNotifierProvider<AdminSession, AdminAccess>(
  AdminSession.new,
);

class AdminSession extends AsyncNotifier<AdminAccess> {
  int generation = 0;
  @override
  Future<AdminAccess> build() async {
    final auth = await ref.watch(accountAuthProvider.future);
    final store = await ref.watch(documentStoreProvider.future);
    final initial = await role(auth, store);
    final subscription = auth.changes.listen((_) => unawaited(refresh()));
    final timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (auth.current != null) unawaited(refresh());
    });
    ref.onDispose(() {
      generation++;
      timer.cancel();
      unawaited(subscription.cancel());
    });
    return initial;
  }

  Future<AdminAccess> role(AccountAuth auth, DocumentStore store) async {
    final current = auth.current;
    if (current == null) return const AdminAccess();
    final doc = await store.get('sites/$activeSite/adminUsers/${current.uid}');
    if (doc == null) return AdminAccess(uid: current.uid);
    return AdminAccess(
      uid: current.uid,
      loginName: doc.data['loginName'] as String,
      role: doc.data['role'] as String,
      enabled: doc.data['enabled'] == true,
    );
  }

  Future<void> refresh() async {
    final epoch = ++generation;
    final next = await AsyncValue.guard(
      () async => role(
        await ref.read(accountAuthProvider.future),
        await ref.read(documentStoreProvider.future),
      ),
    );
    if (epoch == generation) state = next;
  }

  Future<void> signIn(String name, String password) async {
    state = const AsyncLoading();
    try {
      await (await ref.read(accountAuthProvider.future)).signIn(name, password);
      await refresh();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    generation++;
    await (await ref.read(accountAuthProvider.future)).signOut();
    state = const AsyncData(AdminAccess());
  }
}
