# تسليم المرحلة 9 الحالي

12 أكتوبر 2026. هذا تسليم العمل المنفذ والقيود الحالية؛ **ليس إغلاقًا للمرحلة 9 ولا بدءًا للمرحلة 10**. طلب المستخدم إيقاف الاختبارات حاليًا؛ آخر توزيع لمعاينات الهوية على ستة مواضع لم يختبر.

## المخرجات

مصدر Flutter في [home_page.dart](D:/Projects/Portfolio/lib/features/public/home_page.dart) و[depth_scene.dart](D:/Projects/Portfolio/lib/features/public/depth_scene.dart)، مع بوابة رؤية [viewport_visibility.dart](D:/Projects/Portfolio/lib/core/viewport_visibility.dart) وتحميل Drive المؤجل في [media_preview.dart](D:/Projects/Portfolio/lib/features/media/media_preview.dart). تحميل الويب المباشر في [flutter_bootstrap.js](D:/Projects/Portfolio/web/flutter_bootstrap.js).

التعديل الأخير يغير موضع المعاينة بعد اختفائها بالتتابع بين ستة أماكن. لا ينقلها فجأة أثناء ظهورها، ولا يغير ترتيب المشاريع المنشورة. المصدر المشترك يطبق السلوك على Web وAndroid؛ لا تشغيل APK أصليًا موثق حتى الآن.

## ملفات النسخة

جهزت النسخ بالتعديل الأخير بنجاح. تجهيز ملفات التسليم لم يتضمن تشغيل tests/analyze أو مراجعة جديدة للمتصفح والهاتف. استخدم بناء الويب --no-wasm-dry-run لتجهيز نسخة JavaScript المعتادة دون فحص Wasm الإضافي؛ لا تغيير لمحرك العرض المعتمد.

| النسخة | مكان الملفات | نتيجة التجهيز |
| --- | --- | --- |
| Web / yogen | D:/Projects/Portfolio/.runtime/phase09-release-web وbuild/web | جهز Release بنجاح؛ الخادم 8781 أعيد تشغيله؛ لم يجرب العرض بعد التعديل |
| Web / phase04-test | D:/Projects/Portfolio/.runtime/phase09-test-web | جهز Release بنجاح؛ الخادم 8780 أعيد تشغيله؛ لم يجرب العرض بعد التعديل |
| Android Debug / yogen | D:/Projects/Portfolio/build/app/outputs/flutter-apk/app-debug.apk | جهز بنجاح؛ لم يثبت أو يشغل على الهاتف |

سجلات التجهيز تحفظ في checks/package-web-orbit-position.txt وpackage-web-test-orbit-position.txt وpackage-android-orbit-position.txt. سجلات بناء النسخة السابقة المختبرة محفوظة بأسماء build-*-before-orbit-position.txt. لا تقارن النتيجتين باعتبارهما نفس المصدر.

أزمنة التجميع المسجلة: Web الأساسي 251.5 ثانية، Web المعزول 188.7 ثانية، Android Debug 189.8 ثانية. هذه أزمنة أدوات البناء، وليست أزمنة تحميل الموقع أو تشغيله. [ملف Android](D:/Projects/Portfolio/build/app/outputs/flutter-apk/app-debug.apk) جاهز للتسليم، ولا يعتبر إصدار متجر.

## المعاينة المحلية

[YOGEN الأساسية](http://127.0.0.1:8781/?revision=p09-orbit-positions#/?lang=ar)، و[لوحة الإدارة](http://127.0.0.1:8781/#/admin/login)، و[بيانات العرض المعزولة](http://127.0.0.1:8780/?revision=p09-orbit-positions#/?lang=ar). الروابط محلية وتحتاج بقاء الخادم على الكمبيوتر. نسخة yogen لا تعرض أعمالًا غير منشورة؛ مسوداتها الـ15 تنتظر بيانات حقيقية. المعاينات الصغيرة تظهر عندما توجد مشاريع منشورة. مساحة phase04-test تعرض بيانات موسومة للاختبار ولا تعتبر أعمال YOGEN.

جهزت نسختا Web وأعيد تشغيل الخادمين لقراءة الأصول المضغوطة الجديدة، دون طلب HTTP للتحقق أو فتح/اختبار الواجهات. لا يحتاج ذلك نشر Firebase أو Apps Script. لا تفتح index.html مباشرة من نظام الملفات.

عند الحاجة لتشغيل المعاينة لاحقًا، من D:/Projects/Portfolio:

```powershell
python tool/serve_verification.py --root .runtime/phase09-release-web --gzip --port 8781
python tool/serve_verification.py --root .runtime/phase09-test-web --gzip --port 8780
```

كل خادم يحتاج طرفية مستقلة. ربط الهاتف المحلي يستخدم اتصال USB وتحويل adb reverse tcp:8780 tcp:8780؛ ليس استضافة عامة. لا يلزم المستخدم تجربة الهاتف الآن. بيانات دخول المدير محفوظة محليًا؛ لا تدرج كلمات المرور أو ملفها في التسليم العام.

## الاستكمال

التقرير الرئيسي في [REPORT.md](D:/Projects/Portfolio/phases/results/09/REPORT.md)، والفحوص المتبقية في [REMAINING.md](D:/Projects/Portfolio/phases/results/09/REMAINING.md). لا تستأنف الاختبارات تلقائيًا؛ عند طلب المستخدم استكمالها تراجع آخر توزيع أولًا، ثم العرض المستقر ولوحة المفاتيح والأداء والمتصفحات. نقص محتوى 8 يبقى شرطًا منفصلًا للإطلاق. المرحلة 10 تنتظر أمرًا مستقلًا.
