import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/yogen_app.dart';
import '../../core/backend.dart';
import '../../core/firebase_config.dart';

class BackendPage extends ConsumerStatefulWidget {
  const BackendPage({super.key});
  @override
  ConsumerState<BackendPage> createState() => _BackendPageState();
}

class _BackendPageState extends ConsumerState<BackendPage> {
  final config = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  String result = '';
  bool busy = false;
  @override
  void dispose() {
    config.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(Future<String> Function() action) async {
    setState(() {
      busy = true;
      result = '';
    });
    try {
      final value = await action();
      if (mounted) setState(() => result = value);
    } catch (e) {
      if (mounted) {
        setState(() => result = e is FirebaseException ? e.code : e.toString());
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final state = ref.watch(backendProvider),
        backend = ref.read(backendProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Firebase · portfolio-14d15',
          style: Theme.of(c).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Text(
          state.ready
              ? tr(c, 'الإعداد جاهز', 'Configuration ready')
              : state.busy
              ? tr(c, 'جارٍ الربط', 'Connecting')
              : state.error ??
                    tr(
                      c,
                      'لم يتم الربط. استخدم إعدادات التطبيق العامة.',
                      'Not configured. Use public app configuration.',
                    ),
        ),
        if (!state.ready) ...[
          const SizedBox(height: 16),
          TextField(
            controller: config,
            minLines: 3,
            maxLines: 8,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'Firebase configuration JSON',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: state.busy
                ? null
                : () => run(() async {
                    await backend.configure(
                      FirebaseConfig.fromMap(
                        jsonDecode(config.text) as Map<String, dynamic>,
                      ),
                    );
                    return ref.read(backendProvider).error ??
                        'configuration_ready';
                  }),
            child: Text(tr(c, 'ربط الإعدادات', 'Configure')),
          ),
        ],
        if (state.ready)
          StreamBuilder<User?>(
            stream: backend.auth.authStateChanges(),
            builder: (c, snapshot) {
              final user = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    user == null
                        ? tr(c, 'غير مسجل', 'Signed out')
                        : 'UID: ${user.uid}',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                await backend.auth.signInWithEmailAndPassword(
                                  email: email.text.trim(),
                                  password: password.text,
                                );
                                password.clear();
                                return 'signed_in';
                              }),
                        child: Text(tr(c, 'دخول', 'Sign in')),
                      ),
                      OutlinedButton(
                        onPressed: busy || user == null
                            ? null
                            : () => run(() async {
                                await backend.auth.signOut();
                                password.clear();
                                return 'signed_out';
                              }),
                        child: Text(tr(c, 'خروج', 'Sign out')),
                      ),
                      OutlinedButton(
                        onPressed: busy || user == null
                            ? null
                            : () => run(backend.roundTrip),
                        child: Text(tr(c, 'فحص Firestore', 'Check Firestore')),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 16),
        if (busy) const LinearProgressIndicator(),
        Text(result, key: const ValueKey('backend-result')),
      ],
    );
  }
}
