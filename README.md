# YOGEN Portfolio

[مستودع المصدر على GitHub](https://github.com/bavlybasemhelal-dotcom/portfolio). يشمل كود Flutter، وأصول التصميم، وخطة المراحل وتقاريرها، وقواعد Firestore وسكريبت Google Drive. ملفات البناء وكلمات المرور ومفتاح توقيع Android والنسخ الخاصة لا تدرج في المستودع.

الإصدار الحالي YOGEN 1.0.1+11: تطبيق Flutter بالعربية والإنجليزية وLight/Dark و3D، وموقع عام ولوحة إدارة مرتبطة بـFirebase وGoogle Drive. تحديث 12 أكتوبر أضاف دخول الأدمن بسحب المجسم إلى مربع، ونقل أزرار الحركة إلى الأدمن، وسرع دوران السكون إلى 60 ثانية، وأوضح تغيير كلمة المرور مع تأكيدها. نشر Web وبني APK Release بنفس مفتاح النسخة السابقة، دون اختبارات بطلب المستخدم. [تقرير التحديث](D:/Projects/Portfolio/updates/1.0.1/REPORT.md) و[الروابط والملفات](D:/Projects/Portfolio/updates/1.0.1/LINKS-AND-ACCESS.md). تقرير إطلاق 1.0.0 الأصلي محفوظ في نتائج المرحلة 10. بيانات الأعمال تدخل من الأدمن؛ فحوص 9 المؤجلة لم تعاد. Windows مؤجل ولا مرحلة 11؛ رقم بناء Android 11 ليس مرحلة جديدة.

راجع [تقرير المرحلة 8](D:/Projects/Portfolio/phases/results/08/REPORT.md)، و[دليل الطلبات](D:/Projects/Portfolio/phases/results/08/CONTACT-GUIDE.md)، و[سجل محتوى الأعمال](D:/Projects/Portfolio/phases/results/08/CONTENT-REGISTER.md)، و[الفحوص الحالية](D:/Projects/Portfolio/phases/results/08/TEST-RESULTS.md)، و[سجل الحالة](D:/Projects/Portfolio/phases/STATUS.md). [دليل اللوحة](D:/Projects/Portfolio/phases/results/07/ADMIN-GUIDE.md) مرجع إدارة المحتوى. القواعد 8 منشورة ومطابقة للمصدر بعد إعادة تسجيل الدخول، ونجح فحص التواصل السحابي. خدمة الوسائط باقية على بروتوكول 5.

[الموقع المنشور](https://portfolio-14d15.web.app/#/?lang=ar)، و[دخول الأدمن المباشر](https://portfolio-14d15.web.app/#/admin/login)، و[تنزيل أندرويد الحالي](https://portfolio-14d15.web.app/downloads/yogen-latest.apk). التنزيل يحول إلى ملف Drive متاح لأي شخص معه الرابط للقراءة؛ Spark يمنع استضافة APK. APK المحلي في releases/1.0.1/android/yogen-1.0.1.apk. لا يحتاج الموقع أو التطبيق خادم كمبيوتر أو USB؛ التطبيق يحتاج إنترنت للخدمات. في Web وAndroid اضغط قليلًا على مجسم الشعار الكبير في الرئيسية واسحبه إلى المربع، أو حدده بنقرة ثم اضغط المربع. زر «دخول الفريق» العام أزيل. كلمة المرور تتغير من «حسابي» أو قائمة إعدادات الحساب أعلى الأدمن.

استدراك 12 أكتوبر: المعاينات الصغيرة تتوزع على ستة مواضع حول المجسم في مصدر Flutter المشترك. الاختبارات متوقفة بطلب المستخدم؛ آخر تعديل لم يختبر، والمرحلة 9 غير مغلقة. الفحوص السابقة وحدود البناء والمعاينة في [دليل التسليم الحالي](D:/Projects/Portfolio/phases/results/09/HANDOVER.md).

سجلات 9 تصف ما سبق الإطلاق. تسليم 10 ونطاقه المعدل في تقريره، ولا يعيد الاختبارات أو يجعل نتيجة الأداء معتمدة. النسخ الخاصة والمفتاح في .runtime خارج الرفع؛ لا تنشرها. تحديث الكود والرجوع والنسخ موثقة في نتائج 10.

اسم المدير `admin@gmail.com` اسم دخول فقط. لتعيين كلمة مرور خاصة من طرفية محلية داخل المشروع:

```powershell
& .\tool\Set-YogenAccess.ps1
```

تحتاج الأداة جلسة Firebase CLI لصاحب المشروع؛ تطلب الكلمة مرتين بشكل مخفي، ولا ترسل بريدًا. [دخول الفريق المنشور](https://portfolio-14d15.web.app/#/admin/login) متاح دون خادم محلي. بعد الدخول اختر «المشاريع» لاستكمال المسودات أو «طلبات العملاء» لفتح `/admin/requests`. النموذج يحفظ طلبات الزوار بشكل خاص للفريق، مع إيصال استلام ومنع التكرار عند إعادة المحاولة.

لإعادة تجهيز إصدار التسليم دون اختبارات أو نشر تلقائي: شغل tool/Build-YogenRelease.ps1. النسخ الاحتياطي في tool/Backup-Yogen.ps1؛ ملفات Drive المستقبلية تنزل منفصلًا كما يوضح دليل الاسترجاع. أوامر الفحص التالية مراجع تطوير محلي فقط، ولا تشغّل تلقائيًا مع توجيه المستخدم الحالي بإيقاف الاختبارات.

من `D:\Projects\Portfolio`:

```powershell
flutter pub get
flutter analyze
flutter test --concurrency=1
flutter run -d chrome --dart-define-from-file=config/firebase.web.json --dart-define-from-file=config/drive.phase05.json
flutter build web --release --dart-define-from-file=config/firebase.web.json --dart-define-from-file=config/drive.phase05.json
flutter build apk --debug --dart-define-from-file=config/firebase.android.json --dart-define-from-file=config/drive.phase05.json
python tool/serve_verification.py --gzip --port 8781
```

Apple يستخدم `config/firebase.apple.json` على macOS/Xcode. الجهاز الأصلي يختار من `flutter devices`. Windows/Linux يستخدمان طبقة Auth/Firestore REST التي اختبرت محليًا وسحابيًا؛ مخزن النظام والتشغيل الأصلي لم يختبرا. بناء Windows للمرحلة 4 يحتاج C++ ATL وقد أجل بطلب المستخدم؛ نسخة المرحلة 3 القديمة لا تثبت بناء 4. Android بني Debug دون تشغيل على هاتف، وApple/Linux لم يبنيا.

معرفات Drive ورابط `/exec` في [إعدادات Drive الحالية](D:/Projects/Portfolio/config/drive.phase05.json)؛ المفتاح `DRIVE_WEB_APP_URL` يمرر الرابط للبناء. إعدادات الاتصال يحفظها المدير من صفحة الوسائط. الملف الواحد حتى 5 MiB، ومصغرة PNG حتى 200 KiB؛ فيديو MP4/WebM يحمل كاملًا قبل التشغيل. النشر محدود بستة مراجع للمشروع، وأولها غلاف صورة. القواعد الحالية في [firestore.phase08.rules](D:/Projects/Portfolio/firebase/firestore.phase08.rules)؛ لا تعاد قواعد أقدم وحدها مع عقد المرحلة 7؛ القراءة تقبل شكل الروابط القديم والجديد. البيانات العامة في `config`؛ أسرار الاختبار في `.runtime` مستبعدة من Git والرفع. المجلد الحالي لم يهيأ كمستودع Git.

الفحوص: `/admin/login`, `/admin/recovery`, `/admin/verification`, `/admin/media`، ومعاينة وسائط منشورة معزولة: `/validation/media-gallery?site=phase04-test&project=phase05-1791602768901`. مسارات المرحلة 3 باقية للتحقق القديم: `/validation/backend`, `/validation/media`, `/validation/scene`, `/projects/phase03-fixture`. المسار الإداري محمي بدور فعال. `YOGEN_SITE` افتراضيًا `yogen`؛ التجارب السحابية معزولة في `phase04-test`. معاينة Flutter عبر HTTP؛ لا تفتح `build/web/index.html` مباشرة. خادم الضغط يقرأ ملفات البناء عند تشغيله؛ يعاد تشغيله بعد بناء جديد. مسارات validation للتحقق القديم؛ الإدارة المعتادة تبدأ من /admin وتستخدم المحرر الكامل في /admin/projects.

البناء على الجهاز الحالي احتاج حد ذاكرة Gradle 1536 MiB وعاملين: استخدم `GRADLE_OPTS=-Dorg.gradle.jvmargs=-Xmx1536m -Dorg.gradle.workers.max=2 -Dorg.gradle.daemon=false` و`JAVA_TOOL_OPTIONS=-XX:ActiveProcessorCount=2` داخل جلسة البناء فقط إذا تكرر نقص الموارد. ملف [Android Debug](D:/Projects/Portfolio/build/app/outputs/flutter-apk/app-debug.apk) ناتج اختبار؛ لا يعني تشغيله على هاتف أو إصدار متجر.

بناء Android يستخدم JDK الكامل الموجود في `C:\Program Files\Java\jdk-17`، مع NDK `28.2.13676358`. اختر JDK يحتوي `javac`؛ JRE وحده لا يكفي لتجميع إضافة اختيار الملفات. سجل البناء الحالي في نتائج 09، والـAPK لم يشغل على هاتف. فحص Android Chrome الفعلي موثق بشكل مستقل ولا يعتبر تشغيلًا للـAPK.
