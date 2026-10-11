import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart';
import '../../auth/account_auth.dart';
import '../../auth/admin_session.dart';
import '../../core/firebase_config.dart';
import '../../data/accounts_repository.dart';
import '../../data/document_store.dart';

String accessError(BuildContext c, Object e) {
  final code = e is AuthFailure
      ? e.code
      : e is DataFailure
      ? e.code
      : e.toString();
  if (code.contains('INVALID_LOGIN_CREDENTIALS') ||
      code.contains('INVALID_PASSWORD') ||
      code.contains('wrong-password') ||
      code.contains('invalid-credential')) {
    return tr(
      c,
      'اسم الدخول أو كلمة المرور غير صحيحة.',
      'The username or password is incorrect.',
    );
  }
  if (code.contains('weak-password') || code.contains('WEAK_PASSWORD')) {
    return tr(
      c,
      'كلمة المرور ضعيفة؛ اختر كلمة أطول وأكثر تنوعًا.',
      'This password is too weak. Choose a longer, more varied password.',
    );
  }
  if (code.contains('too-many-requests') ||
      code.contains('TOO_MANY_ATTEMPTS')) {
    return tr(
      c,
      'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.',
      'Too many attempts. Wait a little and try again.',
    );
  }
  if (code.contains('requires-recent-login') ||
      code.contains('sign_in_required')) {
    return tr(
      c,
      'سجّل الدخول مجددًا ثم غيّر كلمة المرور.',
      'Sign in again before changing your password.',
    );
  }
  if (code.contains('EMAIL_EXISTS')) {
    return tr(
      c,
      'اسم الدخول مستخدم بالفعل.',
      'This username is already in use.',
    );
  }
  if (code.contains('password_minimum_12')) {
    return tr(
      c,
      'استخدم كلمة مرور من 12 إلى 128 حرفًا.',
      'Use a password of 12 to 128 characters.',
    );
  }
  if (code.contains('invalid_login_name')) {
    return tr(
      c,
      'استخدم اسم دخول من 3 إلى 200 حرف إنجليزي أو رقم، ويمكن إضافة @ . _ + -.',
      'Use a username of 3 to 200 English letters or digits; @ . _ + - are also allowed.',
    );
  }
  if (code.contains('PERMISSION_DENIED') || code.contains('manager_required')) {
    return tr(
      c,
      'الحساب غير مخوّل لهذا الإجراء.',
      'This account cannot perform this action.',
    );
  }
  return tr(
    c,
    'تعذر إكمال الطلب. تحقق من الاتصال وحاول مجددًا.',
    'The request could not finish. Check your connection and retry.',
  );
}

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});
  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final login = TextEditingController(), password = TextEditingController();
  bool busy = false, visible = false;
  String? error;
  @override
  void dispose() {
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(adminSessionProvider.notifier)
          .signIn(login.text, password.text);
      if (!mounted) return;
      final access = ref.read(adminSessionProvider).value;
      if (access?.allowed == true) {
        password.clear();
        context.go('/admin');
      } else {
        setState(
          () => error = tr(
            context,
            'الحساب ليس له صلاحية إدارة فعالة.',
            'This account has no active admin access.',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = accessError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final access = ref.watch(adminSessionProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(c, 'أهلًا بك في YOGEN', 'Welcome to YOGEN'),
                    style: Theme.of(c).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      c,
                      'سجّل الدخول لإدارة محتوى الشركة.',
                      'Sign in to manage company content.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: login,
                    enabled: !busy,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: tr(c, 'اسم الدخول', 'Username'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    enabled: !busy,
                    obscureText: !visible,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: tr(c, 'كلمة المرور', 'Password'),
                      suffixIcon: IconButton(
                        tooltip: tr(
                          c,
                          visible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
                          visible ? 'Hide password' : 'Show password',
                        ),
                        onPressed: () => setState(() => visible = !visible),
                        icon: Icon(
                          visible ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(color: Theme.of(c).colorScheme.error),
                      ),
                    ),
                  ],
                  if (access.hasError && error == null) ...[
                    const SizedBox(height: 12),
                    Text(accessError(c, access.error!)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(tr(c, 'تسجيل الدخول', 'Sign in')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => c.go('/admin/recovery'),
                    child: Text(tr(c, 'استعادة الوصول', 'Recover access')),
                  ),
                  if (access.value?.uid != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => ref
                                .read(adminSessionProvider.notifier)
                                .signOut(),
                      child: Text(
                        tr(
                          c,
                          'الخروج من الحساب الحالي',
                          'Sign out current account',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecoveryPage extends StatelessWidget {
  const RecoveryPage({super.key});
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(c, 'استعادة الوصول', 'Recover access'),
            style: Theme.of(c).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              c,
              'الحساب يستخدم اسم دخول مستقلًا عن البريد. تواصل مع صاحب مشروع YOGEN لاستعادة الوصول.',
              'This account uses a username independent of email. Contact the YOGEN project owner to recover access.',
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => c.go('/admin/login'),
            child: Text(tr(c, 'العودة لتسجيل الدخول', 'Back to sign in')),
          ),
        ],
      ),
    ),
  );
}

class AdminAccessPage extends ConsumerStatefulWidget {
  const AdminAccessPage({super.key});
  @override
  ConsumerState<AdminAccessPage> createState() => _AdminAccessPageState();
}

class _AdminAccessPageState extends ConsumerState<AdminAccessPage> {
  final login = TextEditingController(), password = TextEditingController();
  List<StoredDocument> users = [];
  bool busy = false;
  String message = '';
  PendingAccount? pending;
  @override
  void initState() {
    super.initState();
    Future.microtask(loadUsers);
  }

  @override
  void dispose() {
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<AccountsRepository> repository() async => AccountsRepository(
    await ref.read(documentStoreProvider.future),
    FirebaseAuthApi(FirebaseConfig.environment.apiKey),
    actor: ref.read(adminSessionProvider).value!.uid!,
    site: activeSite,
  );
  Future<void> loadUsers() async {
    if (ref.read(adminSessionProvider).value?.manager != true) return;
    try {
      final repo = await repository();
      try {
        final value = await repo.list();
        if (mounted) setState(() => users = value);
      } finally {
        repo.api.close();
      }
    } catch (e) {
      if (mounted) setState(() => message = accessError(context, e));
    }
  }

  Future<void> operation(
    Future<void> Function(AccountsRepository repo) body,
  ) async {
    setState(() {
      busy = true;
      message = '';
    });
    AccountsRepository? repo;
    try {
      repo = await repository();
      await body(repo);
      await loadUsers();
    } on PendingAccount catch (e) {
      pending = e;
      if (mounted) {
        setState(
          () => message = tr(
            context,
            'تم إنشاء الحساب، لكن صلاحية الدخول لم تحفظ. أعد حفظ الصلاحية.',
            'The account was created but its role was not saved. Retry saving the role.',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = accessError(context, e));
    } finally {
      repo?.api.close();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final access = ref.watch(adminSessionProvider).value;
    if (access?.allowed != true) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(c, 'مساحة الفريق', 'Team workspace'),
          style: Theme.of(c).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          '${access!.loginName} · ${access.manager ? tr(c, 'مدير', 'Manager') : tr(c, 'محرر مع صلاحية النشر', 'Editor with publishing access')}',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: () => c.go('/admin/media'),
              child: Text(tr(c, 'التخزين والوسائط', 'Storage and media')),
            ),
            OutlinedButton(
              onPressed: () => _changePassword(c),
              child: Text(tr(c, 'تغيير كلمة المرور', 'Change password')),
            ),
            OutlinedButton(
              onPressed: () =>
                  ref.read(adminSessionProvider.notifier).signOut(),
              child: Text(tr(c, 'تسجيل الخروج', 'Sign out')),
            ),
          ],
        ),
        if (access.manager) ...[
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(c, 'إضافة حساب محرر', 'Add an editor account'),
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: login,
                    enabled: !busy,
                    decoration: InputDecoration(
                      labelText: tr(c, 'اسم دخول العضو', 'Member username'),
                      helperText: tr(
                        c,
                        'اسم الدخول لا يرسل رسائل بريد.',
                        'The username does not send email.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: tr(c, 'كلمة مرور العضو', 'Member password'),
                      helperText: tr(
                        c,
                        '12 حرفًا على الأقل',
                        'At least 12 characters',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => operation((repo) async {
                            await repo.createEditor(login.text, password.text);
                            password.clear();
                            login.clear();
                            pending = null;
                            if (mounted) {
                              setState(
                                () => message = tr(
                                  c,
                                  'تمت إضافة المحرر. جلسة المدير مستمرة.',
                                  'Editor added. The manager session is unchanged.',
                                ),
                              );
                            }
                          }),
                    child: Text(tr(c, 'إضافة المحرر', 'Add editor')),
                  ),
                  if (pending != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => operation((repo) async {
                              await repo.grantEditor(
                                pending!.account,
                                pending!.login,
                              );
                              pending = null;
                              password.clear();
                            }),
                      child: Text(
                        tr(c, 'إعادة حفظ الصلاحية', 'Retry role save'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(c, 'الحسابات والصلاحيات', 'Accounts and access'),
            style: Theme.of(c).textTheme.titleLarge,
          ),
          for (final user in users)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(user.data['loginName'] as String),
                    Text(
                      user.data['enabled'] == true
                          ? tr(c, 'فعال', 'Active')
                          : tr(c, 'معطل', 'Disabled'),
                    ),
                    if (user.data['role'] == 'editor')
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => operation(
                                (repo) => repo.setEnabled(
                                  user.data['uid'] as String,
                                  user.data['enabled'] != true,
                                ),
                              ),
                        child: Text(
                          user.data['enabled'] == true
                              ? tr(c, 'تعطيل الوصول', 'Disable access')
                              : tr(c, 'إعادة التفعيل', 'Enable access'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
        if (message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: Text(message)),
        ],
      ],
    );
  }

  Future<void> _changePassword(BuildContext c) async {
    await showChangePasswordDialog(c);
  }
}

Future<void> showChangePasswordDialog(BuildContext c) async {
  final changed = await showDialog<bool>(
    context: c,
    barrierDismissible: false,
    builder: (_) => const _PasswordDialog(),
  );
  if (changed == true && c.mounted) {
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            c,
            'تم تغيير كلمة المرور. استخدم الجديدة عند الدخول من أي جهاز.',
            'Password changed. Use the new password when signing in on any device.',
          ),
        ),
      ),
    );
  }
}

class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();
  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final old = TextEditingController(),
      next = TextEditingController(),
      confirmation = TextEditingController();
  final form = GlobalKey<FormState>();
  String? failure;
  bool saving = false, visible = false;
  @override
  void dispose() {
    old.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      final access = ref.read(adminSessionProvider).value;
      if (access?.allowed != true) throw const AuthFailure('sign_in_required');
      await (await ref.read(
        accountAuthProvider.future,
      )).changePassword(old.text, next.text);
      old.clear();
      next.clear();
      confirmation.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => failure = accessError(context, e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext c) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(tr(c, 'تغيير كلمة المرور', 'Change password')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: AutofillGroup(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('password-current'),
                    controller: old,
                    enabled: !saving,
                    obscureText: !visible,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    validator: (s) => s == null || s.isEmpty
                        ? tr(
                            c,
                            'أدخل كلمة المرور الحالية.',
                            'Enter your current password.',
                          )
                        : null,
                    decoration: InputDecoration(
                      labelText: tr(
                        c,
                        'كلمة المرور الحالية',
                        'Current password',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('password-new'),
                    controller: next,
                    enabled: !saving,
                    obscureText: !visible,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.newPassword],
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    validator: (s) {
                      if (s == null || s.length < 12 || s.length > 128) {
                        return tr(
                          c,
                          'استخدم من 12 إلى 128 حرفًا.',
                          'Use 12 to 128 characters.',
                        );
                      }
                      if (s == old.text) {
                        return tr(
                          c,
                          'اختر كلمة مختلفة عن الحالية.',
                          'Choose a different password.',
                        );
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: tr(c, 'كلمة المرور الجديدة', 'New password'),
                      helperText: tr(
                        c,
                        '12 إلى 128 حرفًا',
                        '12 to 128 characters',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('password-confirmation'),
                    controller: confirmation,
                    enabled: !saving,
                    obscureText: !visible,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.newPassword],
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => save(),
                    validator: (s) => s != next.text || (s?.isEmpty ?? true)
                        ? tr(
                            c,
                            'تأكيد كلمة المرور غير مطابق.',
                            'Passwords do not match.',
                          )
                        : null,
                    decoration: InputDecoration(
                      labelText: tr(
                        c,
                        'تأكيد كلمة المرور الجديدة',
                        'Confirm new password',
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: visible,
                    onChanged: saving
                        ? null
                        : (v) => setState(() => visible = v!),
                    title: Text(tr(c, 'إظهار كلمات المرور', 'Show passwords')),
                  ),
                  if (failure != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        failure!,
                        style: TextStyle(color: Theme.of(c).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(c),
          child: Text(tr(c, 'إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr(c, 'حفظ كلمة المرور', 'Save password')),
        ),
      ],
    ),
  );
}
