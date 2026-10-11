import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yogen_portfolio/features/media/drive_bridge.dart';

void main() {
  const endpoint = 'https://script.google.com/macros/s/phase03-test/exec';
  final image = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  Map<String, Object> response() => {
    'success': true,
    'fileId': 'test-file-123456',
    'fileName': 'صورة اختبار.png',
    'mimeType': 'image/png',
    'fileSize': image.length,
    'directUrl': '',
    'viewUrl': '',
    'downloadUrl': '',
  };
  test(
    'Base64 request retains Arabic name and authenticated identity in POST body',
    () async {
      final bridge = DriveBridge(
        client: MockClient((r) async {
          final body = jsonDecode(r.body) as Map;
          expect(r.headers['Content-Type'], startsWith('text/plain'));
          expect(r.url.query, isEmpty);
          expect(body['idToken'], 'isolated-test-token');
          expect(body['category'], 'phase03');
          expect(body['fileName'], 'صورة اختبار.png');
          expect(base64Decode(body['fileData'] as String), image);
          return http.Response(
            jsonEncode(response()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final saved = await bridge.upload(
        url: endpoint,
        token: 'isolated-test-token',
        bytes: image,
        name: 'صورة اختبار.png',
        mime: 'image/png',
        requestId: 'test-run-123',
      );
      expect(saved.name, 'صورة اختبار.png');
      expect(saved.bytes, image.length);
    },
  );
  test('Reject unsafe endpoint before sending any request', () {
    for (final url in [
      'http://script.google.com/macros/s/test/exec',
      'https://script.google.com.attacker.invalid/macros/s/test/exec',
      'https://user@script.google.com/macros/s/test/exec',
      '$endpoint?token=bad',
    ]) {
      expect(() => DriveBridge.endpoint(url), throwsA(isA<DriveFailure>()));
    }
  });
  test('Reject oversized, empty and unsupported file locally', () {
    expect(
      () => MediaPolicy.validate(Uint8List(0), 'image/png'),
      throwsA(isA<DriveFailure>()),
    );
    expect(
      () => MediaPolicy.validate(image, 'text/html'),
      throwsA(isA<DriveFailure>()),
    );
    expect(
      () => MediaPolicy.validate(
        Uint8List(MediaPolicy.maxTestBytes + 1),
        'image/png',
      ),
      throwsA(isA<DriveFailure>()),
    );
  });
  test(
    'ContentService redirect uses only Google GET and does not forward token',
    () async {
      var calls = 0;
      final bridge = DriveBridge(
        client: MockClient((r) async {
          calls++;
          if (calls == 1) {
            return http.Response(
              '',
              302,
              headers: {
                'location':
                    'https://script.googleusercontent.com/macros/echo?test=1',
              },
            );
          }
          expect(r.method, 'GET');
          expect(r.body, isEmpty);
          expect(r.headers['Authorization'], isNull);
          return http.Response('{"success":true}', 200);
        }),
      );
      await bridge.ping(endpoint, 'isolated-test-token');
      expect(calls, 2);
    },
  );
  test('Reject redirect to unrelated host', () async {
    final bridge = DriveBridge(
      client: MockClient(
        (_) async => http.Response(
          '',
          302,
          headers: {'location': 'https://attacker.invalid/collect'},
        ),
      ),
    );
    await expectLater(
      bridge.ping(endpoint, 'isolated-test-token'),
      throwsA(isA<DriveFailure>()),
    );
  });
  test('Timeout is surfaced; no automatic duplicate upload', () async {
    var requests = 0;
    final bridge = DriveBridge(
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{"success":true}', 200);
      }),
    );
    await expectLater(
      bridge.ping(endpoint, 'isolated-test-token'),
      throwsA(isA<TimeoutException>()),
    );
    expect(requests, 1);
  });
  test('Anonymous image request has no Firebase token', () async {
    final bridge = DriveBridge(
      client: MockClient((r) async {
        final body = jsonDecode(r.body) as Map;
        expect(body['action'], 'image');
        expect(body.containsKey('idToken'), false);
        return http.Response(
          jsonEncode({
            'success': true,
            'mimeType': 'image/png',
            'fileData': base64Encode(image),
          }),
          200,
        );
      }),
    );
    expect(await bridge.image(endpoint, 'test-file-123456'), image);
  });
  test(
    'HTML error and malformed upload response do not become success',
    () async {
      final bridge = DriveBridge(
        client: MockClient(
          (_) async => http.Response('<html>login</html>', 200),
        ),
      );
      await expectLater(
        bridge.ping(endpoint, 'isolated-test-token'),
        throwsA(isA<DriveFailure>()),
      );
      expect(
        () =>
            DriveFile.fromMap({'success': true, 'fileId': 'x', 'fileSize': 0}),
        throwsA(isA<DriveFailure>()),
      );
    },
  );
}
