import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_config.dart';
import 'firebase_bootstrap.dart';

final backendProvider = NotifierProvider<Backend, BackendState>(Backend.new);

class BackendState {
  final FirebaseApp? app;
  final bool busy;
  final String? error;
  const BackendState({this.app, this.busy = false, this.error});
  bool get ready => app != null;
}

class Backend extends Notifier<BackendState> {
  @override
  BackendState build() => const BackendState();

  Future<void> configure(FirebaseConfig config) async {
    state = const BackendState(busy: true);
    try {
      config.validatePlatform(defaultTargetPlatform);
      final current = Firebase.apps.isEmpty ? null : Firebase.app();
      if (current != null && current.options.appId != config.appId) {
        throw StateError(
          'Restart the verification app to change Firebase app.',
        );
      }
      final app = current ?? await FirebaseBootstrap.initialize(config);
      state = BackendState(app: app);
    } catch (error) {
      state = BackendState(
        error: error is FirebaseException ? error.code : error.toString(),
      );
    }
  }

  FirebaseAuth get auth => FirebaseAuth.instanceFor(app: state.app!);
  FirebaseFirestore get firestore =>
      FirebaseFirestore.instanceFor(app: state.app!);

  Future<String> roundTrip() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before the Firestore check.');
    final runId = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final doc = firestore
        .collection('phase03_checks')
        .doc(uid)
        .collection('runs')
        .doc(runId);
    final value = {
      'projectId': FirebaseConfig.projectId,
      'testOnly': true,
      'runId': runId,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await doc.set(value).timeout(const Duration(seconds: 20));
    final saved = await doc
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    if (saved.data()?['runId'] != runId || saved.data()?['testOnly'] != true) {
      throw StateError('Server read did not return the test record.');
    }
    return doc.path;
  }

  Future<void> recordMedia(String runId, Map<String, Object?> metadata) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before saving media metadata.');
    await firestore
        .collection('phase03_checks')
        .doc(uid)
        .collection('media')
        .doc(runId)
        .set({
          ...metadata,
          'testOnly': true,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 20));
  }
}
