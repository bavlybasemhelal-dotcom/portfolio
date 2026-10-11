import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:yogen_portfolio/data/document_store.dart';

Future<void> main() async {
  final fixtures =
      jsonDecode(
            File(
              '.runtime/phase04-emulator-fixtures.local.json',
            ).readAsStringSync(),
          )
          as Map;
  final user = fixtures['users'][0] as Map;
  final client = http.Client();
  final response = await client
      .get(
        Uri.parse(
          'http://127.0.0.1:8084/v1/projects/demo-yogen-phase04/databases/(default)/documents/sites/phase04-test/adminUsers/${user['uid']}',
        ),
        headers: {'Authorization': 'Bearer ${user['idToken']}'},
      )
      .timeout(const Duration(seconds: 8));
  stdout.writeln(
    'Direct Dart GET: ${response.statusCode}, bytes=${response.bodyBytes.length}',
  );
  final store = FirestoreRestStore(
    projectId: 'demo-yogen-phase04',
    token: () async => user['idToken'] as String,
    origin: 'http://127.0.0.1:8084',
    timeout: const Duration(seconds: 8),
  );
  stdout.writeln('Store read starts');
  final read = await store.get('sites/phase04-test/adminUsers/${user['uid']}');
  stdout.writeln('Store role: ${read?.data['role']}');
  stdout.writeln('Transaction starts');
  await store.transaction((tx) async {
    final value = await tx.get('sites/phase04-test/projectDrafts/probe');
    stdout.writeln('Transaction missing document: ${value == null}');
  });
  store.close();
  client.close();
}
