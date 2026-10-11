import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/firebase_bootstrap.dart';
import '../core/firebase_config.dart';

class AuthFailure implements Exception {
  final String code;
  const AuthFailure(this.code);
  @override
  String toString() => code;
}

class LoginIdentity {
  static String normalize(String name) {
    final v = name.trim().toLowerCase();
    if (v.length < 3 ||
        v.length > 200 ||
        !RegExp(r'^[a-z0-9][a-z0-9@._+-]*$').hasMatch(v)) {
      throw const AuthFailure('invalid_login_name');
    }
    return v;
  }

  static String email(String name) =>
      '${sha256.convert(utf8.encode(normalize(name)))}@login.yogen.invalid';
  static void password(String value) {
    if (value.length < 12 || value.length > 128) {
      throw const AuthFailure('password_minimum_12');
    }
  }
}

class AuthAccount {
  final String uid, email;
  const AuthAccount(this.uid, this.email);
}

abstract class SessionVault {
  Future<String?> read();
  Future<void> write(String refreshToken);
  Future<void> clear();
}

class SecureSessionVault implements SessionVault {
  final String key;
  final FlutterSecureStorage storage;
  const SecureSessionVault({
    this.storage = const FlutterSecureStorage(),
    this.key = 'yogen.firebase.refresh.v1',
  });
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
  @override
  Future<void> clear() => storage.delete(key: key);
}

abstract class AccountAuth {
  AuthAccount? get current;
  Stream<AuthAccount?> get changes;
  Future<void> restore();
  Future<AuthAccount> signIn(String login, String password);
  Future<String?> token();
  Future<void> signOut();
  Future<void> changePassword(String oldPassword, String newPassword);
}

class FirebaseAuthApi {
  final String apiKey, origin, refreshOrigin;
  final http.Client client;
  FirebaseAuthApi(
    this.apiKey, {
    http.Client? client,
    this.origin = 'https://identitytoolkit.googleapis.com',
    this.refreshOrigin = 'https://securetoken.googleapis.com',
  }) : client = client ?? http.Client() {
    for (final item in [origin, refreshOrigin]) {
      final uri = Uri.parse(item);
      if (!(item == 'https://identitytoolkit.googleapis.com' ||
          item == 'https://securetoken.googleapis.com' ||
          (uri.scheme == 'http' && uri.host == '127.0.0.1'))) {
        throw const AuthFailure('untrusted_auth_endpoint');
      }
    }
  }
  void close() => client.close();
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, Object?> body,
  ) async {
    final uri = Uri.parse(
      '$origin/v1/accounts:$action',
    ).replace(queryParameters: {'key': apiKey});
    final response = await client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    return decode(response);
  }

  Map<String, dynamic> decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const AuthFailure('invalid_auth_response');
    }
    if (response.statusCode >= 400) {
      final code = decoded is Map
          ? (decoded['error']?['message'] as String?)
          : null;
      throw AuthFailure(code?.split(' : ').first ?? 'auth_failed');
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final uri = Uri.parse(
      '$refreshOrigin/v1/token',
    ).replace(queryParameters: {'key': apiKey});
    return decode(
      await client
          .post(
            uri,
            body: {
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
            },
          )
          .timeout(const Duration(seconds: 25)),
    );
  }

  /// Sign-up is independent of the active SDK/REST session.
  Future<AuthAccount> register(String login, String password) async {
    LoginIdentity.password(password);
    final email = LoginIdentity.email(login);
    final value = await call('signUp', {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });
    return AuthAccount(value['localId'] as String, email);
  }
}

class RestAccountAuth implements AccountAuth {
  final FirebaseAuthApi api;
  final SessionVault vault;
  final DateTime Function() clock;
  AuthAccount? _current;
  String? _idToken, _refreshToken;
  DateTime? _expires;
  Future<String?>? _refreshing;
  int _generation = 0;
  Future<void> _storageTail = Future.value();
  final _changes = StreamController<AuthAccount?>.broadcast();
  RestAccountAuth(this.api, this.vault, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  @override
  AuthAccount? get current => _current;
  @override
  Stream<AuthAccount?> get changes => _changes.stream;
  Future<void> _storage(Future<void> Function() body) {
    final next = _storageTail.then((_) => body());
    _storageTail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _accept(
    Map<String, dynamic> value, {
    bool refreshed = false,
    required int generation,
  }) async {
    final token = value[refreshed ? 'id_token' : 'idToken'] as String;
    final refresh =
        value[refreshed ? 'refresh_token' : 'refreshToken'] as String;
    final uid = value[refreshed ? 'user_id' : 'localId'] as String;
    final expires = int.parse(
      value[refreshed ? 'expires_in' : 'expiresIn'].toString(),
    );
    AuthAccount accountValue;
    if (refreshed) {
      final account = await api.call('lookup', {'idToken': token});
      final user = (account['users'] as List).first as Map;
      accountValue = AuthAccount(uid, user['email'] as String);
    } else {
      accountValue = AuthAccount(uid, value['email'] as String);
    }
    await _storage(() async {
      if (generation != _generation) throw const AuthFailure('session_changed');
      await vault.write(refresh);
    });
    if (generation != _generation) throw const AuthFailure('session_changed');
    _idToken = token;
    _refreshToken = refresh;
    _expires = clock().add(Duration(seconds: expires));
    _current = accountValue;
    _changes.add(_current);
  }

  @override
  Future<void> restore() async {
    final value = await vault.read();
    if (value == null) return;
    _refreshToken = value;
    try {
      await _renew();
    } on AuthFailure catch (e) {
      if ([
        'TOKEN_EXPIRED',
        'USER_DISABLED',
        'INVALID_REFRESH_TOKEN',
        'USER_NOT_FOUND',
      ].contains(e.code)) {
        await signOut();
      } else {
        rethrow;
      }
    }
  }

  Future<String?> _renew() async {
    final generation = _generation;
    final value = _refreshToken;
    if (value == null) return null;
    try {
      await _accept(
        await api.refresh(value),
        refreshed: true,
        generation: generation,
      );
      return _idToken;
    } on AuthFailure catch (e) {
      if ([
        'TOKEN_EXPIRED',
        'USER_DISABLED',
        'INVALID_REFRESH_TOKEN',
        'USER_NOT_FOUND',
      ].contains(e.code)) {
        await signOut();
      }
      rethrow;
    }
  }

  @override
  Future<AuthAccount> signIn(String login, String password) async {
    final generation = ++_generation;
    final value = await api.call('signInWithPassword', {
      'email': LoginIdentity.email(login),
      'password': password,
      'returnSecureToken': true,
    });
    await _accept(value, generation: generation);
    return _current!;
  }

  @override
  Future<String?> token() async {
    if (_refreshToken == null) return null;
    if (_idToken != null &&
        _expires!.isAfter(clock().add(const Duration(minutes: 1)))) {
      return _idToken;
    }
    final pending = _refreshing ??= _renew();
    try {
      return await pending;
    } finally {
      if (identical(_refreshing, pending)) _refreshing = null;
    }
  }

  @override
  Future<void> signOut() async {
    _generation++;
    _idToken = null;
    _refreshToken = null;
    _expires = null;
    _current = null;
    await _storage(vault.clear);
    _changes.add(null);
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final generation = _generation;
    LoginIdentity.password(newPassword);
    final user = _current;
    if (user == null) throw const AuthFailure('sign_in_required');
    final fresh = await api.call('signInWithPassword', {
      'email': user.email,
      'password': oldPassword,
      'returnSecureToken': true,
    });
    final changed = await api.call('update', {
      'idToken': fresh['idToken'],
      'password': newPassword,
      'returnSecureToken': true,
    });
    await _accept(changed, generation: generation);
  }

  Future<void> dispose() async {
    api.close();
    await _changes.close();
  }
}

class SdkAccountAuth implements AccountAuth {
  final FirebaseAuth auth;
  SdkAccountAuth(this.auth);
  static Future<SdkAccountAuth> connect(FirebaseConfig config) async =>
      SdkAccountAuth(
        FirebaseAuth.instanceFor(
          app: await FirebaseBootstrap.initialize(config),
        ),
      );
  AuthAccount? convert(User? user) =>
      user == null ? null : AuthAccount(user.uid, user.email ?? '');
  @override
  AuthAccount? get current => convert(auth.currentUser);
  @override
  Stream<AuthAccount?> get changes => auth.userChanges().map(convert);
  @override
  Future<void> restore() async {
    await auth.authStateChanges().first;
  }

  @override
  Future<AuthAccount> signIn(String login, String password) async {
    final result = await auth.signInWithEmailAndPassword(
      email: LoginIdentity.email(login),
      password: password,
    );
    return convert(result.user)!;
  }

  @override
  Future<String?> token() async => auth.currentUser?.getIdToken();
  @override
  Future<void> signOut() => auth.signOut();
  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    LoginIdentity.password(newPassword);
    final user = auth.currentUser;
    if (user == null) throw const AuthFailure('sign_in_required');
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: oldPassword),
    );
    await user.updatePassword(newPassword);
  }
}
