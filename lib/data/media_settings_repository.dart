import '../features/media/drive_bridge.dart';
import '../features/media/media_transport.dart';
import 'document_store.dart';

class MediaSettingsRepository {
  final DocumentStore store;
  final MediaTransport transport;
  final TokenGetter token;
  final String actor, site;
  MediaSettingsRepository(
    this.store,
    this.transport,
    this.token, {
    required this.actor,
    this.site = 'yogen',
  });
  Future<Map<String, dynamic>> testAndSave(
    String endpoint, {
    String administrativeEmail = '',
  }) async {
    DriveBridge.endpoint(endpoint);
    if (administrativeEmail.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(administrativeEmail)) {
      throw const DriveFailure('invalid_administrative_email');
    }
    final role = await store.get('sites/$site/adminUsers/$actor');
    if (role?.data['role'] != 'manager' || role?.data['enabled'] != true) {
      throw const DriveFailure('manager_required');
    }
    final value = await token();
    if (value == null) throw const DriveFailure('authentication_required');
    final result = await transport.ping(endpoint, value, site);
    if (result['version'] != 5 ||
        result['projectId'] != 'portfolio-14d15' ||
        result['maxBytes'] != MediaPolicy.maxTestBytes) {
      throw const DriveFailure('incompatible_bridge');
    }
    await store.commit([
      DocumentWrite.set('sites/$site/settings/drive', {
        'webAppUrl': endpoint,
        'rootFolderId': result['rootFolderId'],
        'rootFolderName': result['rootFolderName'],
        'administrativeEmail': administrativeEmail,
        'lastTestedAt': serverTime,
        'updatedAt': serverTime,
        'updatedBy': actor,
      }),
      DocumentWrite.set('sites/$site/mediaRouting/current', {
        'endpoint': endpoint,
        'version': 5,
        'updatedAt': serverTime,
        'updatedBy': actor,
      }),
    ]);
    return result;
  }

  Future<StoredDocument?> get() => store.get('sites/$site/settings/drive');
  static Future<String> endpoint(DocumentStore store, String site) async =>
      (await store.get('sites/$site/mediaRouting/current'))?.data['endpoint']
          as String? ??
      const String.fromEnvironment('DRIVE_WEB_APP_URL');
}
