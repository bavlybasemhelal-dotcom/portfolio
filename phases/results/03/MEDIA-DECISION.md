# YOGEN — قرار الوسائط

## الموارد

[جذر YOGEN الخاص](https://drive.google.com/drive/folders/1f-aPcfkLaWly5JZGtcq-6RuSW3xsrck_) ومجلدات Projects/Brand/Team/[التجارب](https://drive.google.com/drive/folders/176LcK_ck8Eerzs3PvUgk7eJwSXLOyNFz) أنشئت بالفعل. معرفاتها في `config/drive.phase03.json`. الجذر لم يشارك للعامة.

[Apps Script](https://script.google.com/d/1lHvWFz6bmDMusHkTQa0UXJT83p_pM_f-nKt7JGJcq9QQuIG-wW3b28VV/edit) منشور بإصدار 4. المستخدم فعّل API وأكمل موافقة Google. إعداد النشر العام وexecuteAs تحقق عبر API؛ فقط ملفات التجربة تحصل على `anyone: reader`، وتم تأكيد الحجم والمجلد والمشاركة من موصل Drive. [إعداد النشر الفعلي](D:/Projects/Portfolio/phases/results/03/checks/script-metadata.json).

## العقد والعرض

اختيار ملف → حارس حجم قبل قراءة البيانات → Base64/JSON داخل POST نصي → Google Auth يتحقق من Firebase ID token → فحص مشروعه وUID الخادم → ملف Drive → مرجع Firestore. الرد: `fileId`, `fileName`, `fileSize`, `mimeType`, `directUrl`, `viewUrl`, `downloadUrl`.

نجاح Drive منفصل عن حفظ Firestore. إعادة حفظ المرجع لا تعيد الرفع. الخادم يعيد نفس الملف لنفس requestId، ويرفض اختلاف المحتوى بالمعرف نفسه.

الصور تعتمد طبقة Apps Script: تقرأ صورة اختبار عامة من Drive وتعيد JSON/Base64؛ Flutter يعرض `Image.memory` داخل بطاقة ومعرض. PNG عربي ظهر فعليًا في Chrome وEdge بلا Google وبعد التحديث وفي Light/Dark. الرفع من file picker داخل Flutter إلى Drive ثم Firestore نجح أيضًا. [الدليل](D:/Projects/Portfolio/phases/results/03/checks/media-browser.json).

لم نعتمد رابط uc مباشرًا لرسم CanvasKit؛ رابط Drive وحده لا يثبت CORS. [ContentService](https://developers.google.com/apps-script/guides/content) نصي ويعيد توجيه Google؛ ليس هنا بثًا ثنائيًا. في 5: cache محدود، نسخ صور مصغرة، إلغاء الطلبات ومعالجة الحصص، دون تخزين Base64 في Firestore.

## الحدود والتجارب

| العينة | الفحص | النتيجة |
| --- | --- | --- |
| PNG عربي 36,009 B | رفع، حفظ، قراءة وعرض Flutter | ناجح؛ أول رفع 6.609 s، إعادة الملف الموجود 3.125 s |
| MP4 5 MiB | فيديو Flutter الرسمي مع free atom لإكمال الحجم؛ Base64 6,990,508 B | رفع حقيقي 39.890 s وحفظ المرجع ناجحان |
| 20/50/100 MiB | حارس حجم قبل القراءة/التحويل | رفض محلي؛ لم ترفع إلى Google، ولا دليل دعم سحابي |

الحد الحالي للإصدار الأول المقترح **5 MiB للملف**، وليس الحد الرسمي الأقصى لـDrive/Apps Script. PNG/MP4 مثبتان بالسحابة؛ JPEG/WebP/WebM/PDF مسموحة مع توقيع خادم لكنها تحتاج عينات فعلية في 5. صور البطاقات المستهدفة ≤200 KiB والغلاف ≤1 MiB. لم تختبر صورة 5 MiB أو فيديو حقيقي طويل؛ الـ5 MiB اختبار نقل صالح مع padding غير مؤثر، لا قياس تحويل فيديو طويل.

مهلة HTTP 60 ثانية لكل طلب/مرحلة استجابة، وFirestore 20 ثانية. timeout محلي يخرج خطأ دون إعادة رفع تلقائية. انقطاع رفع سحابي وذاكرة هاتف/خادم لم يقاسا؛ Base64 يزيد الحجم نحو الثلث وتوجد نسخ ذاكرة متعددة. لا ندعي دعمًا غير محدود أو رفعًا قابلًا للاستكمال. رفع أكبر يحتاج تجارب جديدة أو تغيير آلية موثق. حصص UrlFetch ليست حد استقبال doPost. [حصص Google](https://developers.google.com/apps-script/guides/services/quotas).

فشل 5 MiB أولًا كان call-stack في regex Base64 المتداخل. أصلح بفحص خطي وتوقيع أول 16 بايت؛ ثم نجح نفس الملف. الفشل محفوظ في checks، وregression بحجم 5 MiB ضمن [9 اختبارات سكريبت](D:/Projects/Portfolio/phases/results/03/checks/script-contract.json).

## الفيديو والصلاحية

Drive preview أظهر الغلاف لكن التشغيل انتهى بمهلة وreadyState=0؛ [الفشل محفوظ](D:/Projects/Portfolio/phases/results/03/checks/video-drive-preview-failure.json). أضفنا بديلًا محدودًا: Apps Script يقرأ MP4 التجربة العامة من Drive ويرجع JSON/Base64، ثم Flutter Web ينشئ Blob وvideo داخل HtmlElementView. [فحص الفيديو](D:/Projects/Portfolio/phases/results/03/checks/video-browser.json) يثبت تقدم currentTime وreadyState من جلسة بلا Google؛ ظهور الغلاف وحده لا يعد نجاحًا.

تحميل الفيديو عند الطلب وبحد 5 MiB؛ لا autoplay، ولا بث أو استكمال تنزيل. عند تغيير الوسيط/إغلاق المشغل توقف النسخة ويزال src وتحرر Object URL. الرابط iframe متاح كخيار آخر، لكن نجاح تشغيله لم يثبت. النسخ الأصلية الحالية تعرض رابطًا؛ مشغلات Windows/Linux/Android/iOS تجهز وتختبر في 5. لقطات JS heap في دليل الفيديو لا تقيس كامل Wasm/native/الذاكرة الإعلامية ولا تعتبر أقصى استهلاك.

فحص النسخة النهائية: مدة 4.037 s، currentTime بلغ 1.012 s وreadyState=4 بلا خطأ. JS heap قبل الطلب 29,925,428 B، بعد التخزين 29,077,124 B، وأثناء التشغيل 30,590,296 B؛ تغير الجمع التلقائي يجعل الفرق بين اللقطات غير صالح لقياس تكلفة الرفع أو ذروة الذاكرة. لم يختبر استهلاك مشغل أصلي أو هاتف فعلي.

Google يتحقق من الرمز أولًا، وبعده aud/iss/exp/sub والمشروع وحالة الحساب وقائمة UID على الخادم. الرفع بلا رمز/برمز غير صالح مرفوض. القراءة المجهولة لصورة أو فيديو موسوم عام داخل مجلد التجارب فقط؛ لا قراءة أي ملف خاص. حساب Firebase صحيح خارج قائمة الخادم رفض حتى مع role:admin من العميل، وFirestore رفض كتابته 403؛ حذف الحساب المؤقت بعد الفحص. [الدليل السحابي](D:/Projects/Portfolio/phases/results/03/checks/permissions-cloud.json). ملفات الاختبار ليست مشاريع YOGEN. أدوار الفريق الحقيقي ومنشور/مسودة ومكافحة الإساءة عمل 4 و5.
