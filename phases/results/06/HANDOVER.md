# استكمال YOGEN بعد المرحلة 6

نطاق هذا الدليل: تشغيل المخرجات واستكمالها لاحقًا. وجود خطوات للمرحلة 7 لا يعني بدء تنفيذها.

## التشغيل

من `D:\Projects\Portfolio`، لبناء النسخة الأساسية:

```powershell
flutter build web --release --dart-define-from-file=config/firebase.web.json --dart-define-from-file=config/drive.phase05.json
python tool/serve_verification.py --gzip --port 8773
```

افتح [الرئيسية](http://127.0.0.1:8773/#/?lang=ar)، [الأعمال](http://127.0.0.1:8773/#/work?lang=ar)، أو [دخول الفريق](http://127.0.0.1:8773/#/admin/login). صور Drive تعرض داخل الموقع؛ إعداد البروتوكول ما زال ملف 5، وقواعد البيانات الحالية ملف 6.

بناء Web الأساسي محفوظ أيضًا في `.runtime/phase06-release-web`. إذا تغير `build/web` لاحقًا يمكن معاينة البناء المحفوظ بـ`python tool/serve_verification.py --gzip --port 8773 --root .runtime/phase06-release-web` بعد إيقاف خادم المنفذ نفسه. لا يعيد هذا بيانات Firestore أو ملفات Drive إلى حالة سابقة.

نسخة مراجعة معزولة:

```powershell
flutter build web --release --dart-define-from-file=config/firebase.web.json --dart-define-from-file=config/drive.phase05.json --dart-define=YOGEN_SITE=phase04-test
```

احفظها في مجلد مستقل ثم شغل الخادم عليه. النسخة التي أعدت للتسليم في `.runtime/phase06-test-web` عبر [معاينة العينات](http://127.0.0.1:8774/#/?lang=ar). يعاد تشغيل الخادم بعد نسخ بناء جديد لأن الملفات المضغوطة تقرأ عند بدايته. لا تفتح ملفات Flutter Web مباشرة عبر `file://`.

Android:

```powershell
flutter build apk --debug --dart-define-from-file=config/firebase.android.json --dart-define-from-file=config/drive.phase05.json
```

بيئة الجهاز الحالية تحتاج خيارات Gradle المذكورة في README عند نقص الذاكرة. نسخة Debug لا تعني اختبار هاتف أو إصدار متجر. لا تبن Windows حاليًا؛ أجله المستخدم.

## المسارات والسياق

`/`، `/work`، `/projects/:id` (يقبل معرف الوثيقة أو slug منشورًا)، `/services`، `/about`، `/contact`. معلمة `lang=ar/en` محفوظة. فلاتر الأعمال قائمة JSON في `filters` والبحث في `q`؛ الفلاتر المتعددة تربط بـOR وتعرض المشروع مرة واحدة.

فتح البطاقة يحمل `return` للمسار السابق بترميز Base64URL لنص URI بصيغة UTF-8، لحماية البحث وJSON الفلاتر من فك الترميز المزدوج أثناء تحديث Flutter Web. زر الرجوع بعد التحديث يقبل مساري `/` و`/work` المحليين فقط ويستعيد البحث والفلاتر. روابط خارجية لا تدخل في هذا الرجوع. زر الحل المشابه يحمل `project` و`nameAr` و`nameEn`؛ مسودة حقول التواصل في الذاكرة وتبقى أثناء تغيير اللغة والتنقل، وتفقد عند إعادة تحميل التطبيق. حفظها الدائم والإرسال لم ينفذا.

المسارات الإدارية والتحقق السابقة محفوظة. الفحص التقني القديم للأساس أصبح `/validation/foundation`؛ أي صفحة تحقق قديمة تخص مرحلة سابقة لا تمثل محتوى الموقع العام.

## عقد المحتوى الموسع

| الحقل | الشكل المخزن | الحدود |
| --- | --- | --- |
| problem / solution | خريطة ar/en | نصان اختياريان ثنائيا اللغة؛ حد 30000 حرف لكل لغة |
| tags / features | خريطة ar/en، كل عنصر سطر مستقل | ستة عناصر، 600 حرف للعنصر في كل لغة؛ عدد العناصر في اللغتين متطابق؛ لا سطر جديد داخل العنصر |
| technologies | نص، تقنية لكل سطر | ستة عناصر؛ 80 حرفًا للعنصر؛ لا أسطر داخل اسم التقنية |

القوائم تبقى `List<LocalizedText>` و`List<String>` داخل Dart؛ التحويل إلى الأسطر في `toMap/fromMap` فقط. لا يمرر المحرر المستقبل النص الخام إلى العرض، بل يستخدم النموذج والتحقق. الوسوم الإنجليزية والتقنيات لا تتكرر في تحقق التطبيق. حدود العقد السابقة للعنوان والوصف والروابط والملفات باقية. الحقول الاختيارية الفارغة تحذف من الكتابة؛ البيانات القديمة دونها صالحة.

الدلالات العامة مقيدة بنسخ المنشور، لا بترشيح المسودات بعد تحميلها. لا تغير `publicRepositoryProvider` ليستخدم رمز الأدمن، ولا تعرض `internalNote` أو حقول التدقيق الخاصة في نسخة عامة.

## ملفات التنفيذ الأساسية

- [قارئ المنشور والمؤشرات والتحديث](D:/Projects/Portfolio/lib/data/public_content_repository.dart).
- [الهيكل والمسارات المشتركة](D:/Projects/Portfolio/lib/features/public/public_shell.dart) و[الرئيسية والتمرير](D:/Projects/Portfolio/lib/features/public/home_page.dart).
- [الصفحات العامة](D:/Projects/Portfolio/lib/features/public/public_pages.dart)، [البطاقات والمعرض](D:/Projects/Portfolio/lib/features/public/project_widgets.dart)، [مشهد العمق](D:/Projects/Portfolio/lib/features/public/depth_scene.dart).
- [عقد المشروع](D:/Projects/Portfolio/lib/domain/project.dart)، [قواعد 6](D:/Projects/Portfolio/firebase/firestore.phase06.rules)، [إعداد نشرها](D:/Projects/Portfolio/firebase.phase06.json).

## فحوص يعاد تشغيلها عند تغيير هذه المكونات

```powershell
flutter analyze
flutter test --concurrency=1
$env:YOGEN_BROWSER_FUNCTIONAL_ONLY='1'
node tool/check_phase06_browser.cjs
Remove-Item Env:YOGEN_BROWSER_FUNCTIONAL_ONLY
node tool/check_phase06_matrix.cjs
node tool/check_phase06_final_browser.cjs
node tool/check_phase06_deployed_rules.cjs
```

فحص المتصفح يحتاج نسخة العينات على 8774، واختبارات السحابة Opt-in وتحتاج خزنة المالك المحلية الموجودة بالفعل. لا تشغل تجارب تعديل الشركة/الفريق بالتزامن مع تجهيز العينات؛ تستخدم المساحة نفسها. `tool/check_phase06_live_company.cjs` يضيف بيانات أمثلة مؤقتة ثم يخفيها ويشاهد ظهورها في صفحات مفتوحة بلا إعادة تحميل.

المصفوفة تسجل كل لقطة فورًا في `checks/browser-matrix.json`؛ لا تعتبر مكتملة دون `complete: true` و72 حالة بلا أخطاء. فحص المسارات الستة مع إعادة تحميل مستقل يستخدم `YOGEN_BROWSER_ROUTES_ONLY=1` مع أداة المصفوفة، ويسجل في `browser-routes.json`. فحص النسخة الأساسية يحتاج بناء `yogen` على 8773. فحص لوحة المفاتيح في `tool/check_phase06_keyboard.cjs` يستخدم Tab وEnter الحقيقيين.

القارئ العام يعرض فشل القراءة الأولى مباشرة بدل انتظار محاولات Riverpod التلقائية؛ زر Retry والتحديث كل 30 ثانية يعيدان القراءة. يحتفظ بجميع بيانات المشاريع المنشورة الخفيفة في الذاكرة لأجل البحث والفلاتر ومعرض الرئيسية، مع جلبها في صفحات خادمية من 24 وثيقة. الصور تحمل عند الحاجة، وذاكرة الوسائط حتى 12 MiB؛ نمو البيانات الكبير يحتاج قياسًا في 9 قبل ادعاء تحمل حجم غير مختبر.

فحص القواعد: `node tool/rules/phase06.test.mjs` داخل Firebase Emulator وفق `firebase.phase06.json`، باستخدام Java 21 وضبط PATH. قراءة القواعد المنشورة والتحقق من بصمتها لا يعيدان نشرها. النشر عند الحاجة يستخدم `--config firebase.phase06.json --only firestore:rules --project portfolio-14d15` بعد نجاح الفحوص.

الأسرار وكلمات المرور تبقى في `.runtime` المستبعدة؛ لا تضعها في config أو Markdown أو الكود أو مخرجات الأدوات. المدير `admin@gmail.com` اسم دخول فقط؛ أداة اختيار كلمته ودليل المرحلة 4 باقيان.

## عند الإذن بالمرحلة 7

اقرأ ملفها وسجل الحالة ثم هذا الدليل وعقود 4 ودليل وسائط 5. استعمل حقول الحالة الدراسية الجديدة في المحرر الكامل، والرفع الموثق الموجود، وإدارة الفريق والشركة. لا تنشئ بيانات عامة تجريبية في `sites/yogen` ولا تعد إلى قواعد قديمة. اختبر النشر ثم ظهور تغييره في الصفحات العامة وتعارض التعديل والصلاحيات. المحتوى الحقيقي والإرسال في 8، وفحوص الأجهزة والأداء في 9.
