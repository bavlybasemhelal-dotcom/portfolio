import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/auth/account_auth.dart';
import 'package:yogen_portfolio/data/accounts_repository.dart';
import 'package:yogen_portfolio/data/document_store.dart';

String secret() =>
    base64UrlEncode(List.generate(32, (_) => Random.secure().nextInt(256)));
Future<void> prepare() async {
  final owner =
      jsonDecode(File('.runtime/yogen-owner.local.json').readAsStringSync())
          as Map;
  final key =
      (jsonDecode(File('config/firebase.web.json').readAsStringSync())
              as Map)['FIREBASE_API_KEY']
          as String;
  final api = FirebaseAuthApi(key);
  final session = await api.call('signInWithPassword', {
    'email': owner['email'],
    'password': owner['password'],
    'returnSecureToken': true,
  });
  final db = FirestoreRestStore(
    projectId: 'portfolio-14d15',
    token: () async => session['idToken'] as String,
  );
  final fixture = <String, dynamic>{
    'projectId': 'portfolio-14d15',
    'apiKey': key,
    'site': 'phase04-test',
    'runId': DateTime.now().millisecondsSinceEpoch.toString(),
    'generatedPassword': secret(),
    'users': [
      {
        'name': 'rest-manager',
        'login': owner['loginName'],
        'uid': owner['uid'],
        'email': owner['email'],
        'password': owner['password'],
      },
    ],
  };
  final file = File('.runtime/phase04-cloud-fixtures.local.json');
  void save() => file.writeAsStringSync(jsonEncode(fixture));
  save();
  try {
    final accounts = AccountsRepository(
      db,
      api,
      actor: owner['uid'] as String,
      site: 'phase04-test',
    );
    for (final name in [
      'rest-editor',
      'rest-editor2',
      'rest-editor3',
      'rest-outsider',
    ]) {
      final login = '$name-${fixture['runId']}', password = secret();
      final user = name == 'rest-outsider'
          ? await api.register(login, password)
          : await accounts.createEditor(login, password);
      (fixture['users'] as List).add({
        'name': name,
        'login': login,
        'email': user.email,
        'password': password,
        'uid': user.uid,
      });
      save();
    }
    await db.commit([
      DocumentWrite.set('sites/phase04-test/categories/systems', {
        'name': {'ar': 'تصنيف اختبار', 'en': 'Test category'},
        'enabled': true,
        'order': 0,
        'updatedAt': serverTime,
        'updatedBy': owner['uid'],
      }),
    ]);
    final old = await db.get('sites/phase04-test/media/cover');
    await db.commit([
      DocumentWrite.set('sites/phase04-test/media/cover', {
        'public': {
          'id': 'cover',
          'driveFileId': '1v0XR_P4WEUoXsgWXg2S6YqsyQsugly29',
          'name': 'phase03-known-image.png',
          'mime': 'image/png',
          'bytes': 36009,
          'alt': {'ar': 'صورة اختبار', 'en': 'Test image'},
        },
        'ready': true,
        'createdAt': old?.data['createdAt'] ?? serverTime,
        'createdBy': old?.data['createdBy'] ?? owner['uid'],
        'updatedAt': serverTime,
        'updatedBy': owner['uid'],
      }),
    ]);
    stdout.writeln(
      'Isolated cloud fixtures prepared: manager, three test editors and roleless account. No real team or public site content created.',
    );
  } catch (e) {
    stdout.writeln(
      'Cloud fixture preparation failed: ${e is AuthFailure
          ? e.code
          : e is DataFailure
          ? e.code
          : e.runtimeType}',
    );
    rethrow;
  } finally {
    db.close();
    api.close();
  }
}

void main() {
  test(
    'Prepare isolated cloud fixtures',
    prepare,
    skip: Platform.environment['YOGEN_PREPARE_CLOUD'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
