import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yogen_portfolio/auth/account_auth.dart';

class TestVault implements SessionVault {
  String? value;
  final writes = <String>[];
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
    writes.add(v);
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  const login = 'admin@gmail.com';
  final email = LoginIdentity.email(login);
  Map<String, Object?> signed({
    String token = 'id-memory',
    String refresh = 'refresh-secret',
  }) => {
    'localId': 'uid-manager',
    'email': email,
    'idToken': token,
    'refreshToken': refresh,
    'expiresIn': '3600',
  };
  http.Response response(Object body) => http.Response(jsonEncode(body), 200);
  test(
    'Login alias is normalized and never sends mail to the entered Gmail address',
    () {
      expect(LoginIdentity.email(' Admin@Gmail.com '), email);
      expect(email, endsWith('@login.yogen.invalid'));
      expect(email, isNot(login));
      expect(
        () => LoginIdentity.email('../invalid'),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
  test(
    'Desktop session persists refresh only; independent signup never replaces manager',
    () async {
      final vault = TestVault();
      final api = FirebaseAuthApi(
        'public-key',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['email'], isNot(login));
          if (request.url.path.endsWith('signUp')) {
            return response({...signed(), 'localId': 'uid-editor'});
          }
          return response(signed());
        }),
      );
      final auth = RestAccountAuth(api, vault);
      await auth.signIn(login, 'A-private-password-123');
      final created = await api.register('editor1', 'An-editor-password-123');
      expect(created.uid, 'uid-editor');
      expect(auth.current!.uid, 'uid-manager');
      expect(vault.writes, ['refresh-secret']);
      expect(await auth.token(), 'id-memory');
      await auth.signOut();
      expect(auth.current, isNull);
      expect(vault.value, isNull);
      await auth.dispose();
    },
  );
  test(
    'Restart restores via refresh and concurrent expiration calls share one refresh',
    () async {
      final vault = TestVault()..value = 'old-refresh';
      var now = DateTime.utc(2026), refreshes = 0;
      final api = FirebaseAuthApi(
        'public-key',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/token')) {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return response({
              'user_id': 'uid-manager',
              'id_token': 'renewed-$refreshes',
              'refresh_token': 'new-refresh',
              'expires_in': '3600',
            });
          }
          return response({
            'users': [
              {'localId': 'uid-manager', 'email': email},
            ],
          });
        }),
      );
      final auth = RestAccountAuth(api, vault, clock: () => now);
      await auth.restore();
      expect(auth.current!.uid, 'uid-manager');
      expect(refreshes, 1);
      now = now.add(const Duration(hours: 2));
      expect(await Future.wait([auth.token(), auth.token(), auth.token()]), [
        'renewed-2',
        'renewed-2',
        'renewed-2',
      ]);
      expect(refreshes, 2);
      await auth.dispose();
    },
  );
  test(
    'A refresh completing after logout cannot restore or persist the old session',
    () async {
      final vault = TestVault()..value = 'old-refresh',
          gate = Completer<void>();
      final api = FirebaseAuthApi(
        'public-key',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/token')) {
            await gate.future;
            return response({
              'user_id': 'uid-manager',
              'id_token': 'late-id',
              'refresh_token': 'late-refresh',
              'expires_in': '3600',
            });
          }
          return response({
            'users': [
              {'localId': 'uid-manager', 'email': email},
            ],
          });
        }),
      );
      final auth = RestAccountAuth(api, vault);
      final restore = auth.restore();
      final failed = expectLater(
        restore,
        throwsA(
          isA<AuthFailure>().having((v) => v.code, 'code', 'session_changed'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await auth.signOut();
      gate.complete();
      await failed;
      expect(auth.current, isNull);
      expect(vault.value, isNull);
      await auth.dispose();
    },
  );
  test(
    'Invalid refresh clears the stored session; untrusted endpoints refused',
    () async {
      final vault = TestVault()..value = 'revoked';
      final auth = RestAccountAuth(
        FirebaseAuthApi(
          'key',
          client: MockClient(
            (_) async => http.Response(
              '{"error":{"message":"INVALID_REFRESH_TOKEN"}}',
              400,
            ),
          ),
        ),
        vault,
      );
      await auth.restore();
      expect(vault.value, isNull);
      expect(auth.current, isNull);
      await auth.dispose();
      expect(
        () => FirebaseAuthApi('key', origin: 'https://attacker.invalid'),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
}
