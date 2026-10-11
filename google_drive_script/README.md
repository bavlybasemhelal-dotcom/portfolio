# YOGEN — تجربة وسائط المرحلة 03

هذا سكريبت مراجعة وتجارب معزولة، وليس خدمة إنتاج نهائية. تخزين الملفات يظل في Google Drive، وFirestore يحفظ المرجع. تنفيذ أدوار الفريق ونشر أعمال العملاء في المرحلتين 4 و5.

## الملفات والموارد الجاهزة

- المصدر: [yogen_phase03.js](D:/Projects/Portfolio/google_drive_script/yogen_phase03.js).
- البيان: [appsscript.json](D:/Projects/Portfolio/google_drive_script/appsscript.json).
- الخصائص: [properties.example.json](D:/Projects/Portfolio/google_drive_script/properties.example.json).
- مجلد الجذر: [YOGEN Portfolio](https://drive.google.com/drive/folders/1f-aPcfkLaWly5JZGtcq-6RuSW3xsrck_).
- مجلد التجارب: [90_Phase03_Tests](https://drive.google.com/drive/folders/176LcK_ck8Eerzs3PvUgk7eJwSXLOyNFz).

تم إنشاء السكريبت ونشر Web App فعليًا. الرابط والمعرفات في `config/drive.phase03.json`؛ مصدر الخادم في الإصدار 4 يشمل قراءة MP4 عامة محدودة. موافقة Google اكتملت بواسطة المستخدم. لا تعد إنشاء مشروع جديد عند متابعة العمل.

## الربط

1. يحتاج صاحب حساب Google إلى الموافقة على دخول Apps Script. يمكن استخدام `npx @google/clasp login` ثم تفعيل Apps Script API في [إعدادات Apps Script](https://script.google.com/home/usersettings) إن طلبت الخدمة ذلك. الموافقة على Google لا يمكن استنتاجها من اتصال Drive.
2. بعد الربط، ينشئ المنفذ مشروعًا مستقلًا باسم `YOGEN Phase03 Media` من هذا المجلد بواسطة `clasp create --type standalone --title "YOGEN Phase03 Media" --rootDir .` ثم يدفع المصدر والبيان باستخدام `clasp push`.
3. `phase03_config.js` يحمل الإعداد العام وقائمة UID على الخادم؛ Script properties يمكن أن تعدلها. القائمة تخص حساب التجربة فقط. لا تنسخ ملفات `.runtime` إلى Drive.
4. ينشر Web App لينفذ باسم حساب المالك ويسمح بالوصول للزائر. الوصول العام هنا لقراءة صور التجارب العامة؛ كل رفع يمر أولًا بفحص Firebase ID token وUID المسموح على الخادم. المجلدات تبقى خاصة، وملف التجربة الذي نجح رفعه فقط يحصل على عرض بالرابط.
5. يحفظ رابط `/exec` في `config/drive.phase03.json` ثم يختبر من `/validation/media`. إعداد هذا البيان لا يعني حدوث النشر أو الموافقة على الصلاحيات.

## عقد الطلب والرد

POST نصي `text/plain;charset=utf-8` يحتوي JSON. `ping` و`upload` يحتاجان `idToken`. الرفع يتضمن `fileData` Base64 و`fileName` و`mimeType` و`category: phase03` و`requestId`. الرد يحتفظ بـ`fileId`, `fileName`, `fileSize`, `mimeType`, `directUrl`, `viewUrl`, `downloadUrl`.

`image` يقرأ صورة اختبار عامة في مجلد التجارب ويعيد Base64 لـ`Image.memory`؛ CORS وعرض PNG في Chrome/Edge ثبتا فعليًا بلا Google. `video` يفعل الشيء نفسه لفيديو اختبار عام صغير؛ عميل Web يقبل MP4 حتى 5 MiB ويشغله من Blob عند الطلب. لا يتيح أي منهما قراءة ملفات خاصة. [ContentService](https://developers.google.com/apps-script/guides/content) نصي ويعيد توجيه Google؛ ليس استجابة صور ثنائية أو بث فيديو قابلًا للاستكمال.

حد التجربة 5 MiB للملف مع تحقق العميل والخادم. رفع MP4 بهذا الحجم ثبت في 39.890 ثانية؛ ليس الحد الرسمي الأقصى للخدمة، وبقية الأحجام والأنواع في تقرير الوسائط. Base64 يضيف نحو الثلث ونسخ ذاكرة متعددة. لا يستنتج حد doPost من حدود UrlFetch في [حصص Google](https://developers.google.com/apps-script/guides/services/quotas).

Google Auth يتحقق من الرمز أولًا، وبعده نتحقق من مشروع الرمز وصاحب الحساب وقائمة UID. إعادة الطلب بالمعرف نفسه تعيد الملف الموجود؛ اختلاف المحتوى بنفس المعرف مرفوض. فشل حفظ Firestore يمكن إعادة محاولته دون رفع نسخة ثانية.

## فحوص الإغلاق

رفع صورة باسم عربي؛ حفظ مرجعها واسترجاعه؛ عرضها داخل بطاقة ومعرض Flutter في جلسة بلا Google؛ التحديث وLight/Dark وChrome/Edge؛ تسجيل أحجام الفيديو والوقت والذاكرة والفشل. الفحوص المحلية لا تُحتسب بديلًا لهذه التجارب الفعلية.
