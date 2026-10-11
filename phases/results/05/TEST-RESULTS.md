# فحوص المرحلة 5

استدراك 12 أكتوبر 2026: استكمل شق الهاتف الفعلي المؤجل من P05-T10 في المرحلة 9، مع الأرشفة والاستعادة والنشر وثبات مراجع Drive والترتيب. [دليل الجهاز](D:/Projects/Portfolio/phases/results/09/DEVICE-TEST.md). النتائج المؤرخة أدناه تصف حالة تسليم 5 في 10 أكتوبر ولا تمحى.

10 أكتوبر 2026. **فحوص Web والسحابة والبناء ناجحة؛ شق هاتف/جهاز ثانٍ فعلي من P05-T10 غير منفذ ومؤجل إلى 9 بأمر المستخدم، وأغلقت 5 بالحدود الموضحة.** لا تختلط المحاكاة بالخدمة الفعلية أو ببناء Android فقط.

| الفحص | النتيجة المثبتة | الدليل |
| --- | --- | --- |
| P05-T01 | اتصال مدير وحفظ/استعادة إعدادات فعليًا؛ المحرر يرفض في الخدمة والقواعد، وإخفاء الإعدادات عنه مثبت في المتصفح | [السحابة](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json)، [ربط المالك](D:/Projects/Portfolio/phases/results/05/checks/owner-connection.json)، [القواعد](D:/Projects/Portfolio/phases/results/05/checks/rules-emulator.json)، [اللوحة](D:/Projects/Portfolio/phases/results/05/checks/browser-admin.json) |
| P05-T02 | PNG أفقية وJPEG رأسية بأسماء عربية ومصغرات، وتغيير عنوان المشروع لا يغير معرف المجلد/الملف؛ File Picker في Web نجح للأنواع الثلاثة ومصغراته سليمة | [السحابة](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json)، [بيانات Drive](D:/Projects/Portfolio/phases/results/05/checks/drive-metadata.json)، [قراءة ملفات الواجهة](D:/Projects/Portfolio/phases/results/05/checks/browser-upload-readback.json) |
| P05-T03 | MP4 عند 5 MiB فعليًا؛ الحجم الأكبر والنوع المرفوض يرفضان قبل النقل، والتحقق الخادمي مثبت أيضًا | [السحابة](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json)، [السكريبت المحاكى](D:/Projects/Portfolio/phases/results/05/checks/script-contract.json) |
| P05-T04 | طلب رفع مباشر بلا جلسة ومن هوية بلا دور يرفض؛ تغيير دور جلسة موجودة يمنع الخدمة | [الرفع المباشر](D:/Projects/Portfolio/phases/results/05/checks/upload-access.json)، [السحابة](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json) |
| P05-T05 | Drive فعلي ثم فشل محقون قبل commit المرجع؛ استعلام الحالة يسجل نفس الملف دون رفع جديد | [السحابة](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json) |
| P05-T06 | فقد رد محقون بعد نجاح الطلب الفعلي؛ حالة محفوظة واستعادة دون إعادة إرسال ملف | [السحابة](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json) |
| P05-T07 | ملف فعلي مشترك بين مشروعين، إزالة ارتباط مسودة تحافظ على النسخة المنشورة والعمل الآخر | [السحابة](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json) |
| P05-T08 | صور طبيعية وتكبير داخل الموقع في Chrome/Edge خاصين، قبل وبعد reload، مع لقطة فعلية لكل صورة | [32 فحصًا عامًا](D:/Projects/Portfolio/phases/results/05/checks/browser-public.json) |
| P05-T09 | غلاف قبل الطلب، المشغل متوقف بعد التحميل، تقدم currentTime لفيديو MP4 5 MiB وWebM، وPDF مطابق باسمه العربي | [فحص المتصفح](D:/Projects/Portfolio/phases/results/05/checks/browser-public.json) |
| P05-T10 | أرشفة/استعادة/نشر وقراءة الملف والمرجع من جلسة REST جديدة مستقلة ناجحة؛ **جهاز فعلي ثانٍ غير منفذ ومؤجل إلى 9 بأمر المستخدم** | [السحابة](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json)، [خطة فحص الأجهزة اللاحقة](D:/Projects/Portfolio/phases/09-MOTION-PERFORMANCE-QA.md) |
| P05-T11 | غلاف وترتيب محفوظان فعليًا، ورفض تعارض النسخة؛ فشل صورة ثم إعادة طلب وفكها وعرضها في الحوار | [السحابة](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json)، [المتصفح](D:/Projects/Portfolio/phases/results/05/checks/browser-public.json)، [Widgets](D:/Projects/Portfolio/phases/results/05/checks/widget-tests.txt) |

## التحقق الإضافي

- [10 قواعد](D:/Projects/Portfolio/phases/results/05/checks/rules-emulator.json): منع إيصال العميل، منع المرجع المزور، حفظ المراجع الموثقة، استقلال البريد الخاص، الأدوار، عمليات معلقة بلا Base64، وميزانية نشر ستة وسائط ذرية.
- [8 عقد سكريبت محاكى](D:/Projects/Portfolio/phases/results/05/checks/script-contract.json): الرفض والتوقيعات، المجلدات والمصغرات، تكرار الطلب والتعارض، فشل إيصال بعد Drive، القراءة المقيدة بالإيصال، ملف تجريبي محذوف واسترجاعه في المحاكاة. هذا ليس اختبار حذف Drive حقيقي.
- [55 Flutter](D:/Projects/Portfolio/phases/results/05/checks/flutter-tests-sequential.txt): بينها 7 خدمة مكتبة/تعافي/ذاكرة، و[6 مصغرات](D:/Projects/Portfolio/phases/results/05/checks/thumbnail-tests.txt)، و[13 Widgets](D:/Projects/Portfolio/phases/results/05/checks/widget-tests.txt) (12 لغة×مظهر×360/768/1440، وبديل صورة وإعادة محاولة). 5 حالات تهيئة/تكامل اختيارية متجاوزة عمدًا. Widgets أعيدت بعد تغيير عرض لغة الرسائل.
- [14 تحققًا سحابيًا](D:/Projects/Portfolio/phases/results/05/checks/dart-rest-cloud.json)، واختبار واحد اختياري شغل منفصلًا: [السجل](D:/Projects/Portfolio/phases/results/05/checks/cloud-test-run.txt).
- [التحليل](D:/Projects/Portfolio/phases/results/05/checks/analyze.txt) بلا ملاحظات؛ [Web Release](D:/Projects/Portfolio/phases/results/05/checks/build-web.txt) و[Android Debug](D:/Projects/Portfolio/phases/results/05/checks/build-android.txt) ناجحان.
- [مصدر القواعد المنشورة](D:/Projects/Portfolio/phases/results/05/checks/deployed-rules.json) مطابق، و[مصدر نسخة السكريبت المنشورة](D:/Projects/Portfolio/phases/results/05/checks/script-deployment.json) أعيدت قراءته وطابق الملفات والنطاقات.
- [7 فحوص لوحة](D:/Projects/Portfolio/phases/results/05/checks/browser-admin.json) و[3 قراءة مصغرات الواجهة](D:/Projects/Portfolio/phases/results/05/checks/browser-upload-readback.json) ناجحة؛ [4 فحوص بناء yogen النهائي](D:/Projects/Portfolio/phases/results/05/checks/final-browser.json) نجحت بعد [تنظيف هويتي الفحص](D:/Projects/Portfolio/phases/results/05/checks/fixtures-cleanup.json). فحص نجاح رسالة الرفع بعد تغيير اللغة إلى العربية ضمن الجولة النهائية.
- [تحقق التسليم](D:/Projects/Portfolio/phases/results/05/checks/delivery-validation.json) يجمع الأدلة وروابط Markdown وبصمات البناء وفحص أنماط الأسرار في الملفات العامة؛ لا يشمل أسرار `.runtime` ولا يطبعها.

## حدود الإثبات والمحاولات السابقة

تقرير المتصفح العام مستخرج من الاختبارات الـ32 المكتملة في `browser-attempt-08.json` قبل توقف خطوة إدارة الحقول؛ مصدره مسجل داخله. خطوة اللوحة اختبرت منفصلة ثم أعيدت بعد الإصلاح؛ لا يحتسب توقف أداة الحقول نجاحًا للإدارة. محاولات 01–08 ومحاولات اللوحة محفوظة، ومنها توقيت/انتقاء خاطئ في الفحص؛ لا تستبدل بنتائج ناجحة مختلقة. محاولة اللوحة 03 كشفت عطل المصغرة الفعلي على Web؛ ومحاولة 04 توقفت بعد تعبئة لم تصل إلى حقل المعرف في Flutter، فرفضت الواجهة المعرف قبل الرفع. صححت الأداة للنقر والتركيز قبل ملء الحقول.

فحص الصورة يعتمد على لقطة حوار الصورة الفنية بعد فكها وعرضها، وفحص ألوان الصورة بدلًا من افتراض عناصر HTML لرسام Flutter. تطابق كل بايتات الملفات ثبت بشكل مستقل في REST الحقيقي. لم يُحتسب جسم رد مفقود في Chrome CDP كفشل قراءة الملف في التطبيق.

Android بني ولم يشغل على هاتف. الأرشفة والاستعادة والجلسات المستقلة تثبت بقاء البيانات السحابية؛ لا تدعي عتاد جهاز ثانٍ. اختبار Android الحقيقي وأنظمة Apple/Linux وتشغيل الفيديو الأصلي والتطبيق المتكامل في مرحلة فحص الأجهزة اللاحقة. Windows مؤجل بأمر المستخدم. ملفات التجربة موسومة؛ لا تمثل أعمال YOGEN أو فريقها الحقيقي.
