// Explicit verification entry point; never used by the application build.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'auth/account_auth.dart';
import 'data/document_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const fixturePath = String.fromEnvironment('YOGEN_PHASE04_FIXTURE');
  const resultPath = String.fromEnvironment('YOGEN_PHASE04_RESULT');
  if (fixturePath.isEmpty || resultPath.isEmpty) exit(2);
  final report = <String, Object?>{
    'platform': Platform.operatingSystem,
    'checks': <String>[],
    'ok': false,
  };
  const vault = SecureSessionVault(key: 'yogen.phase04.native.check');
  FirebaseAuthApi api() => FirebaseAuthApi(
    'emulator-key',
    origin: 'http://127.0.0.1:9094/identitytoolkit.googleapis.com',
    refreshOrigin: 'http://127.0.0.1:9094/securetoken.googleapis.com',
  );
  RestAccountAuth? first, restarted;
  FirestoreRestStore? db;
  try {
    final fixture = jsonDecode(File(fixturePath).readAsStringSync()) as Map;
    final user =
        (fixture['users'] as List).firstWhere(
              (u) => u['name'] == 'rest-manager',
            )
            as Map;
    await vault.clear();
    first = RestAccountAuth(api(), vault);
    await first.signIn(user['name'] as String, user['password'] as String);
    if (await vault.read() == null) {
      throw StateError('native_vault_write_failed');
    }
    (report['checks'] as List).add('Actual native encrypted vault write/read');
    await first.dispose();
    first = null;
    restarted = RestAccountAuth(api(), vault);
    await restarted.restore();
    if (restarted.current?.uid != user['uid']) {
      throw StateError('native_restore_failed');
    }
    (report['checks'] as List).add(
      'New Auth instance restores and refreshes persisted session',
    );
    db = FirestoreRestStore(
      projectId: fixture['projectId'] as String,
      token: restarted.token,
      origin: 'http://127.0.0.1:8084',
    );
    final role = await db.get(
      'sites/phase04-test/adminUsers/${restarted.current!.uid}',
    );
    if (role?.data['role'] != 'manager') throw StateError('native_role_failed');
    (report['checks'] as List).add(
      'Native user-token Firestore read obeys rules',
    );
    await restarted.signOut();
    if (await vault.read() != null) throw StateError('native_logout_failed');
    (report['checks'] as List).add('Logout removes native persisted secret');
    report['ok'] = true;
  } catch (e) {
    report['errorType'] = e.runtimeType.toString();
  } finally {
    db?.close();
    await first?.dispose();
    await restarted?.dispose();
    await vault.clear();
    File(resultPath).writeAsStringSync(jsonEncode(report));
  }
  exit(report['ok'] == true ? 0 : 1);
}
