# نتائج فحوص المرحلة 6

التاريخ: 10 أكتوبر 2026. الحالة: **P06-T01–T11 ناجحة ضمن نطاقها؛ المرحلة 6 مكتملة**. لا تحتسب المحاولات غير المكتملة نجاحًا.

## التشغيل الآلي والخدمات

- Flutter: **75 اختبارًا ناجحًا**، وستة اختبارات Opt-in متخطاة في التشغيل الافتراضي؛ تشغيل السحابة منفصل. تشمل المجموعة 19 اختبارًا للموقع ومصفوفة Widget من 72 حالة. [السجل](D:/Projects/Portfolio/phases/results/06/checks/flutter-all-final.txt).
- تحليل Dart: **لا مشكلات**. [السجل](D:/Projects/Portfolio/phases/results/06/checks/analyze-final.txt).
- قواعد Firestore: 12 فحصًا في Emulator فعلي، بينها ستة ملفات ونشر ذري ورفض إيصال مزور وحقول غير صالحة وتعديل تفاصيل نسخة منشورة. [النتيجة](D:/Projects/Portfolio/phases/results/06/checks/rules-emulator.json).
- القواعد المنشورة تقرأ وتقارن بالبصمة المحلية: [القراءة](D:/Projects/Portfolio/phases/results/06/checks/deployed-rules.json).
- سحابة Firebase: **6 فحوص ناجحة**؛ 29 مشروعًا منشورًا، مؤشرات تتجاوز 24 وثيقة بترتيب ثابت بلا تكرار، وعينة بستة ملفات؛ المسودة الخاصة ممنوعة ومساحة YOGEN خالية من العينات. [النتيجة](D:/Projects/Portfolio/phases/results/06/checks/cloud-initial.json).
- ظهور ملف فريق وقناة تواصل ونزعهما في صفحات متصفح مفتوحة بلا reload: 3 فحوص ناجحة؛ أعيدت مساحة الاختبار إلى البيانات الناقصة. [النتيجة](D:/Projects/Portfolio/phases/results/06/checks/browser-live-company.json).
- سلوك Chrome/Edge: **28/28 ناجحة**؛ الصفحة المباشرة، العودة، اللغة والحقول، صور أصلية، فيديو فعلي، PDF، التمرير، انقطاع القراءة واستعادتها. [النتيجة](D:/Projects/Portfolio/phases/results/06/checks/browser-public.json).

## جدول اختبارات المرحلة

| المعرف | النتيجة المتحققة | الأدلة |
| --- | --- | --- |
| P06-T01 | المسارات الستة تستعيد المسار واللغة عند التحديث؛ فتح البطاقة ينعكس في URL والرجوع يحفظ البحث | [المسارات](D:/Projects/Portfolio/phases/results/06/checks/browser-routes.json)، [سلوك المتصفح](D:/Projects/Portfolio/phases/results/06/checks/browser-public.json)، اختبارات Flutter |
| P06-T02 | أول زيارة تتبع الجهاز؛ الاختيار اليدوي واللغة محفوظان عند التحديث، الوضعان ظاهران في المصفوفة | [النسخة الأساسية](D:/Projects/Portfolio/phases/results/06/checks/final-browser.json)، [المصفوفة](D:/Projects/Portfolio/phases/results/06/checks/browser-matrix.json) |
| P06-T03 | المشروع وسياق الفلاتر لا يتغيران مع اللغة، والاتجاه والنصوص مناسبـان | سلوك المتصفح واختبارات Flutter |
| P06-T04 | OR للوسوم دون تكرار؛ الرجوع من التفاصيل بعد reload أو زر المتصفح يستعيد q وfilters | سلوك المتصفح، فحص المؤشرات السحابي، اختبارات Flutter |
| P06-T05 | فارغ وغير منشور لا يكشفان مسودة؛ بدء التطبيق بانقطاع الاتصال يظهر الخطأ ثم Retry يستعيد 29 مشروعًا | النسخة الأساسية، اختبارات Flutter، سلوك المتصفح |
| P06-T06 | صور Drive من زائر بلا Google داخل Flutter؛ تكبير وتنقل وإغلاق بلا iframe لواجهة Drive | Chrome/Edge، [صورة أصلية مكبرة](D:/Projects/Portfolio/phases/results/06/screenshots/anonymous-next-image.png) |
| P06-T07 | الأعمال لا تطلب بايتات الفيديو؛ تحميل صريح ثم تشغيل فعلي؛ PDF باسمه العربي وبصمة الملف | سجل الطلبات وسلوك المتصفح؛ بروتوكول 5 لم يتغير |
| P06-T08 | اسم ومعرف المشروع إلى التواصل؛ اسم العميل والملخص يبقيان مع اللغة | سلوك المتصفح واختبارات Flutter |
| P06-T09 | 72 حالة Chrome: ست صفحات × 360/768/1440 × عربي/إنجليزي × Light/Dark، دون تجاوز أفقي أو أخطاء؛ 72 حالة Widget دون overflow | [المصفوفة](D:/Projects/Portfolio/phases/results/06/checks/browser-matrix.json)، [الصور](D:/Projects/Portfolio/phases/results/06/screenshots)، اختبارات Flutter |
| P06-T10 | Tab يصل لإجراء البطاقة وEnter يفتحه؛ Escape يغلق التكبير ويعود التركيز لزر الصورة | [لوحة المفاتيح الحقيقية](D:/Projects/Portfolio/phases/results/06/checks/browser-keyboard.json)، المتصفح، فحص تركيز Widget |
| P06-T11 | الفريق والقنوات الناقصة مخفية؛ إضافة بيانات صالحة ونزعها عبر CompanyRepository يظهران بلا reload أو بناء | [الفحص الحي: 3/3](D:/Projects/Portfolio/phases/results/06/checks/browser-live-company.json)، [إضافة](D:/Projects/Portfolio/phases/results/06/checks/cloud-on.json)، [إخفاء](D:/Projects/Portfolio/phases/results/06/checks/cloud-off.json) |

P06-T11 يختبر عقد النشر الإداري من 4 عبر المستودع الموثق؛ واجهة تحرير الشركة والفريق الكاملة في 7. عينات الفريق والقناة أعيدت مخفية في مساحة الاختبار فقط.

## الحركة والمراجعة البصرية

ثبت تبديل 1/29 إلى 2/29 بالتمرير، والعكس عند العودة، وأزرار الاختيار والتخطي. تغيير النافذة إلى 1366×657 احتفظ بالاختيار في التكوين المختصر. فحص هندسة Flutter يثبت دورة 360° وحدود التمرير وعددًا ديناميكيًا، مع فحوص الإيقاف وتقليل الحركة وتوقفها خارج الشاشة.

راجعت لقطات العربية والإنجليزية والوضعين ومقاسات الهاتف والتابلت والكمبيوتر، ومنها [الرئيسية Dark](D:/Projects/Portfolio/phases/results/06/screenshots/final-yogen-home-dark.png)، [Light](D:/Projects/Portfolio/phases/results/06/screenshots/final-yogen-home-light.png)، [المعرض المختصر](D:/Projects/Portfolio/phases/results/06/screenshots/compact-story.png). بعض لقطات المصفوفة تحمل صورًا أثناء التحميل؛ الصورة الأصلية المكبرة والتشغيل الفعلي فحصا منفصلين، وأماكن الصور ثابتة الارتفاع.

## البناء والنسخة الأساسية

بناء Web الأساسي ونسخة العينات وAndroid Debug **ناجح بعد إصلاح القراءة الأولى**. [Web الأساسي](D:/Projects/Portfolio/phases/results/06/checks/build-web-final.txt)، [Web العينات](D:/Projects/Portfolio/phases/results/06/checks/build-web-test-final.txt)، [Android](D:/Projects/Portfolio/phases/results/06/checks/build-android-final.txt)، [APK](D:/Projects/Portfolio/build/app/outputs/flutter-apk/app-debug.apk).

النسخة الأساسية: **11 فحصًا ناجحًا بعد البناء الأخير**؛ لا عينات أو فريق أو قناة وهمية، الإرسال معطل بوضوح، القراءة العامة بلا رمز الأدمن، رابط الأدمن محمي ودخول المدير ناجح. [النتيجة](D:/Projects/Portfolio/phases/results/06/checks/final-browser.json).

## حدود الأدلة والمحاولات السابقة

- المقاسات محاكاة نافذة Chrome، وليست هاتفًا فعليًا. Android Debug لم يشغل على جهاز. P05-T10 الفعلي في 9 وWindows مؤجل، بأمر المستخدم.
- Chrome وEdge اختبرا للصور والتفاصيل؛ المصفوفة الكاملة في Chrome. Safari/Firefox وApple/Linux لم تختبر هنا.
- لا نشر عام أو مجال أو نجاح SEO أو قياس أداء إنتاجي. المحتوى الحقيقي في 8، والأجهزة والتحسين النهائي في 9.
- المحاولات الفاشلة محفوظة. انتظار نص عنوان الدخول المطابق تمامًا أخطأ بسبب التجميع الدلالي في القالب الإداري القديم؛ تغير إلى حقل اسم الدخول. انقطاع أول قراءة كشف إعادة محاولة Riverpod وتم إصلاحه. التنفيذ المنقطع والملفات القديمة لا يعدان نجاحًا.
- العينات في `phase04-test` فقط؛ لا اختبار منشور في `yogen` ولا حذف لبيانات عميل أو ملف Drive بغرض الفحص.
