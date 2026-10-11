# YOGEN — أساس المرحلة 03

Flutter للويب والموبايل والديسكتوب، مع نموذج تحقق محدود. الموقع النهائي والأدمن وأدوار الفريق لم تنفذ. المرحلة 4 لم تبدأ.

## التنظيم والمسارات

| المسار | المسؤولية |
| --- | --- |
| `lib/main.dart`, `lib/app` | بدء التطبيق، Theme، RTL/LTR، المسارات وقالب الفحص |
| `lib/core` | إعداد Firebase، الاتصال، Riverpod وتفضيلات اللغة والمظهر والحركة |
| `lib/features/media` | عقد Base64 وHTTP والمهلة والحدود ومعاينة الفيديو |
| `lib/features/validation` | صفحات فحص Firebase والوسائط و3D |
| `google_drive_script` | مستقبل الرفع وطبقة صور التجارب |
| `config` | إعدادات عميل عامة ومعرفات موارد |
| `.runtime` | حساب الاختبار والرموز والمواد المحلية الخاصة؛ مستبعدة من Git والرفع |

المسارات: `/`, `/validation/backend`, `/validation/media`, `/validation/scene`, `/projects/phase03-fixture`, `/admin/verification`. مسار admin فحص تقني وليس إدارة مشاريع. Web يستخدم hash، وفتح الرابط وتحديثه ثبتا. fixture تجربة لا يقدم كعمل للشركة.

## الربط والبيانات

المشروع `portfolio-14d15`، الاسم Portfolio، وEmail/Password مثبت فعليًا. سجلت تطبيقات Web وAndroid وApple، ومعرف النسخ الأصلية `com.yogen.portfolio`. الإعدادات العامة في `config/firebase.web.json`, `firebase.android.json`, `firebase.apple.json`؛ تمرر بـ`--dart-define-from-file`. لا Service Account في العميل.

التجارب تحت `phase03_checks/{uid}/runs/{id}` و`.../media/{id}`. القواعد الأصلية رفض للجميع؛ محفوظة في `firebase/firestore.before-phase03.rules`. نشرنا قاعدة مؤقتة لحساب تجربة واحد وهذين المسارين فقط، مع `testOnly` وقائمة مفاتيح محدودة. مسارات الإنتاج ما زالت مرفوضة. هذه ليست قواعد أعضاء YOGEN. استبدالها بالأدوار الحقيقية وإدارة الجلسات والبيانات عمل 4.

## المنصات

| المنصة | الدليل الحالي | الحد |
| --- | --- | --- |
| Web | release + Chrome/Edge + Firebase وDrive فعليان | تشغيل محلي؛ الموقع العام لم ينشر |
| Android | APK debug نهائي ناجح | لم يشغل على جهاز/محاكي؛ لا توقيع متجر |
| Windows | EXE release نهائي ناجح | لم يختبر اتصال EXE؛ FlutterFire Windows موصوف رسميًا للتطوير المحلي |
| iOS/macOS | scaffold وإعداد Apple ومعرفه | البناء والتوقيع يحتاجان macOS/Xcode |
| Linux | scaffold وحراسة تمنع استدعاء Firebase غير المدعوم | لا حزم FlutterFire Linux في هذه المجموعة؛ لم يبن على Linux |

قرار النسخ الأصلية: يبقى Flutter للواجهات، وتنفيذ طبقة Firebase REST لـWindows/Linux والتحقق من تجديد الجلسة وحفظها الآمن يدخل في 4 قبل اعتماد الإنتاج. نجاح REST للسحابة هنا دليل قابلية المسار، لا دليل تطبيق Linux مكتمل. [Firebase الرسمي](https://firebase.google.com/docs/flutter/setup).

## البيئة والحزم

Flutter 3.41.2 stable، Dart 3.11.0؛ Riverpod 3.3.2، go_router 17.5.0، Core 4.15.0، Auth 6.7.0، Firestore 6.10.0، HTTP 1.6.0، file_picker 13.1.0، shared_preferences 2.5.6. `pubspec.lock` مثبت. بعض أحدث الحزم تحتاج SDK أحدث؛ لم نغير SDK العام. اختيار الملفات يستخدم API 13 الساكن وlength/readAsBytes.

Windows 11 Pro 10.0.26300، i7-9850H، RAM نحو 16 GiB، Chrome 154.0.8037.98 وEdge 154.0.4258.62، VS 2026 18.9.2، Android SDK 36.1.0، Java 17.0.12. أول Windows build نزل Firebase C++ نحو 963 MB؛ اعتماد تطوير وليس حجم موقع الزائر. APK debug يشمل تجهيزات التطوير والمعماريات؛ ليس حجم إصدار المتجر. تعارض Kotlin cache بين C: وD: عولج بتعطيل incremental في المشروع فقط، والبناء النهائي ناجح. [Kotlin](https://kotlinlang.org/docs/gradle-compilation-and-caches.html).

## الرسم المجسم

CustomPainter أصلي في Dart: وجوه ذات عمق، فرز عمق، إسقاط منظور وإضاءة، مدار AnimationController وعزل RepaintBoundary. ليس نقل HTML إلى WebView. اللوجو الأصلي لم يتغير. التمرير/Slider يديران 360°؛ pause/reduced/static مثبتة. الحقول مستقيمة.

في 6 ينقل معرض كل الـ15 مشروعًا وتكيف ارتفاع النافذة وفق تصميم 2: LayoutBuilder، مسار تمرير واحد، أدوات متزامنة وتخطي وخروج طبيعي؛ لا تثبيت معرض أطول من المساحة. تجربة الرمز لا تعني تنفيذ كامل المعرض أو 3D كل صفحات المنتج. أداؤها مجتمعة يتحقق في 6 و9.
