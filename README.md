# Firestore App Control (حزمة التحكم بالتطبيق عن بُعد)

حزمة فلاتر قابلة لإعادة الاستخدام في أي مشروع للتحكم بحالة التطبيق (وضع الصيانة، التحديث الإجباري، التحديث الاختياري) عبر **Firebase Firestore** مع التحديث اللحظي (Realtime) ودعم العمل بدون إنترنت (Offline Cache).

A plug-and-play Flutter package for remote application control (Maintenance Mode, Force Update, Optional Update) via **Firebase Firestore** with realtime updates and offline cache support.

---

## الميزات (Features)

- 🛠 **Maintenance Mode**: إيقاف التطبيق وشاشة صيانة كاملة قابلة للتخصيص.
- 🚀 **Force Update**: حجب التطبيق وإجبار المستخدم على التحديث لمتجر التطبيقات عند وجود إصدار أدنى.
- 💡 **Optional Update**: حوار تحديث اختياري مع حماية الجلسة (Session-Level Protection) لعدم الإزعاج.
- ⚡ **Realtime Updates**: استقبال التغييرات لحظياً أثناء استخدام التطبيق عبر Firestore `snapshots()`.
- 📴 **Offline Resilience**: دعم الكاش والتخلف الآمن (Safe Defaults)، انقطاع النت لا يعطل التطبيق.
- 🎨 **Fully Customizable UI**: واجهات افتراضية جميلة مع إمكانية استبدالها بـ Custom Widgets بالكامل.
- 🌐 **Bilingual**: دعم مدمج للعربية والإنجليزية مع دعم RTL و LTR.

---

## التثبيت (Installation)

```yaml
dependencies:
  firestore_app_control:
    git:
      url: https://github.com/ibrahim14ibs/firestore_app_control.git
      ref: main
```

---

## الاستخدام السريع (Quick Start)

### الاستخدام الافتراضي (Default Plug & Play)
```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firestore_app_control/firestore_app_control.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return FirestoreAppControl(
          documentPath: 'app_config/global', // مسار الوثيقة في Firestore
          child: child!,
        );
      },
      home: const MyHomePage(),
    );
  }
}
```

---

## التخصيص الكامل للواجهات (Custom UI Builders)

يمكنك استبدال أي شاشة بتصميمك الخاص من خلال تمرير الـ Builders:

```dart
FirestoreAppControl(
  documentPath: 'app_config/global',
  
  // شاشة صيانة مخصصة
  maintenanceBuilder: (context, maintenance, onRetry) {
    return MyCustomMaintenanceScreen(
      title: maintenance.titleAr,
      message: maintenance.messageAr,
      onRefresh: onRetry,
    );
  },

  // شاشة تحديث إجباري مخصصة
  forceUpdateBuilder: (context, platformConfig, currentVersion, isOffline, onRetry) {
    return MyCustomForceUpdateScreen(
      storeUrl: platformConfig.storeUrl,
      onRetry: onRetry,
    );
  },

  // واجهة تحديث اختياري مخصصة
  optionalUpdateBuilder: (context, platformConfig, currentVersion, onDismiss) {
    return MyCustomOptionalUpdateDialog(
      platformConfig: platformConfig,
      onDismiss: onDismiss,
    );
  },

  child: child!,
)
```

---

## جميع المعاملات والخيارات (Parameters Reference)

| المعامل (Parameter) | النوع (Type) | القيمة الافتراضية (Default) | الوصف والشرح |
| :--- | :--- | :--- | :--- |
| `child` | `Widget` | **مطلوب (Required)** | الودجت الأساسي لتطبيقك (يُعرض في الوضع الطبيعي وتحت نافذة التحديث الاختياري). |
| `documentPath` | `String` | `'app_config/global'` | مسار وثيقة الإعدادات داخل Firestore. |
| `firestore` | `FirebaseFirestore?` | `FirebaseFirestore.instance` | مثيل فايرستور مخصص (مفيد عند تعدد المشاريع أو بيئات الاختبار). |
| `primaryColor` | `Color?` | `Theme primaryColor` | اللون الأساسي للواجهات الافتراضية (شاشة الصيانة، شاشة التحديث الإجباري، وحوار التحديث الاختياري). |
| `optionalUpdateDelay` | `Duration?` | `null` | مدة تأخير اختيارية قبل عرض الـ Overlay (افتراضياً يظهر فوراً وبثبات دون الحاجة لأي تأخير). |
| `autoShowOptionalUpdate` | `bool` | `true` | عرض نافذة التحديث الاختياري تلقائياً. عند ضبطها بـ `false` يمكنك استدعاؤها يدوياً بدالة `FirestoreAppControl.showOptionalUpdateDialog(context)`. |
| `overrideVersion` | `String?` | `null` | إصدار مخصص لتجاوز قراءة إصدار التطبيق من النظام (مفيد جداً للتجربة والاختبار السريع). |
| `navigatorKey` | `GlobalKey<NavigatorState>?` | `null` | مفتاح التنقل الخاص بالتطبيق لضمان فتح الـ Dialog في أي هيكل ملاحة متقدم. |
| `maintenanceDisplayMode` | `AppControlDisplayMode` | `AppControlDisplayMode.fullScreen` | نمط عرض الصيانة (سواءً الافتراضي أو المخصص): `fullScreen` (شاشة كاملة) أو `dialog` (نافذة منبثقة فوق المحتوى). كلاهما يمنع الرجوع أو الخروج عبر `PopScope`. |
| `forceUpdateDisplayMode` | `AppControlDisplayMode` | `AppControlDisplayMode.fullScreen` | نمط عرض التحديث الإجباري (سواءً الافتراضي أو المخصص): `fullScreen` أو `dialog`. كلاهما يمنع الرجوع أو الخروج عبر `PopScope`. |
| `optionalUpdateDisplayMode` | `OptionalUpdateDisplayMode` | `OptionalUpdateDisplayMode.dialog` | نمط عرض التحديث الاختياري (سواءً الافتراضي أو المخصص): `dialog` (نافذة منبثقة)، أو `snackBar` (شريط عائم غير مزعج بأسفل الشاشة)، أو `fullScreen`. |
| `maintenanceBuilder` | `MaintenanceWidgetBuilder?` | `null` | دالة لبناء واجهة صيانة مخصصة بالكامل بدلاً من الواجهة الافتراضية (تعمل مع نمطي `fullScreen` و `dialog`). |
| `forceUpdateBuilder` | `ForceUpdateWidgetBuilder?` | `null` | دالة لبناء واجهة تحديث إجباري مخصصة بالكامل بدلاً من الواجهة الافتراضية (تعمل مع نمطي `fullScreen` و `dialog`). |
| `optionalUpdateBuilder` | `OptionalUpdateWidgetBuilder?` | `null` | دالة لبناء واجهة تحديث اختياري مخصصة بالكامل تُعرض في الـ Overlay وتدعم جميع أنماط العرض (`dialog`, `snackBar`, `fullScreen`). |
| `cubit` | `AppControlCubit?` | `null` | تمرير كائن `AppControlCubit` مسبق التجهيز (لـ Dependency Injection مثل `get_it` أو الـ Mocking). |
| `enableLogging` | `bool?` | `null` | تفعيل سجلات التشخيص البرمجية (Diagnostic Runtime Logs) في الـ Console. إذا كانت `null` تعتمد على `AppControlLogger.enableLogging`. |
| `logHandler` | `AppControlLogHandler?` | `null` | معالج مخصص اختياري لتوجيه السجلات لمنصات المراقبة مثل Sentry أو Firebase Crashlytics. |

---

## سجلات التشخيص البرمجية (Diagnostic Logging)

توفر الحزمة نظام تسجيل تشخيصي شامل لتتبع جلب الإعدادات من Firestore، مقارنة الإصدارات، حالات الانتقال، وأخطاء الروابط:

```dart
// 1. تفعيل السجلات عبر الودجت
FirestoreAppControl(
  enableLogging: true,
  child: child!,
)

// 2. أو تفعيلها عاماً في التطبيق
AppControlLogger.enableLogging = true;

// 3. توجيه السجلات لمعالج مخصص (مثل Sentry أو Firebase Crashlytics)
AppControlLogger.customHandler = (message, {level, error, stackTrace}) {
  debugPrint('[AppControl][${level.label}]: $message');
  if (error != null) {
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }
};
```

---

## أنماط العرض المدمجة (Display Modes)

تتيح لك الحزمة التبديل بين الشاشة الكاملة أو الـ Dialog أو الـ SnackBar دون كتابة أي Custom Widgets:

```dart
FirestoreAppControl(
  // عرض الصيانة كنافذة منبثقة تمنع الإغلاق أو الرجوع
  maintenanceDisplayMode: AppControlDisplayMode.dialog,

  // عرض التحديث الإجباري كنافذة منبثقة تمنع الإغلاق أو الرجوع
  forceUpdateDisplayMode: AppControlDisplayMode.dialog,

  // عرض التحديث الاختياري كـ SnackBar عائم أنيق أسفل الشاشة
  optionalUpdateDisplayMode: OptionalUpdateDisplayMode.snackBar,

  child: child!,
)
```

> **ملاحظة الأمان (PopScope Security):** في كل من وضع الصيانة والتحديث الإجباري (سواءً كشاشة كاملة أو كـ Dialog أو عبر custom builder)، يتم تفعيل `PopScope(canPop: false)` تلقائياً لمنع زر الرجوع في أندرويد وإيماءات السحب للخلف من تجاوز الحجب.

---

## هيكل وثيقة Firestore (Document Schema)

المسار الافتراضي: `app_config/global`

```json
{
  "maintenance": {
    "enabled": false,
    "title_ar": "التطبيق قيد الصيانة",
    "title_en": "App Under Maintenance",
    "message_ar": "نقوم حاليًا ببعض التحسينات، يرجى المحاولة لاحقًا.",
    "message_en": "We are currently performing improvements. Please try again later."
  },
  "android": {
    "minimum_version": "1.0.0",
    "latest_version": "1.0.0",
    "store_url": "https://play.google.com/store/apps/details?id=your.package.id"
  },
  "ios": {
    "minimum_version": "1.0.0",
    "latest_version": "1.0.0",
    "store_url": "https://apps.apple.com/app/id123456789"
  }
}
```

---

## تطبيق المعاينة التفاعلي (Interactive Example App)

تحتوي الحزمة على تطبيق تجريبي متكامل وعملي داخل مجلد [`example/`](file:///Users/ebrahim/Desktop/flutter_packages/firestore_app_control/example) متصل بمشروع فايربيس **Firebase App Control** (`fir-app-control-ff3e2`):

- **لوحة تحكم مباشرة (Live Firestore Presets)**: إرسال حالات الصيانة والتحديث الإجباري والاختياري مباشرة إلى Firestore بنقرة زر لمشاهدة الاستجابة اللحظية (Real-time).
- **محاكي الإصدارات (App Version Simulator)**: اختبار سلوك مقارنة الإصدارات (`1.0.0`, `1.5.0`, `2.0.0`) فوراً.
- **التبديل بين أنماط العرض**: تجربة الشاشة الكاملة مقابل الـ Dialog والـ SnackBar.
- **التبديل بين الواجهات الافتراضية والمخصصة (Custom Builders)**: معاينة التصاميم المخصصة مقابل واجهات الحزمة الافتراضية.
- **نافذة السجلات اللحظية (Live Diagnostics Console)**: عرض سجلات `AppControlLogger` التشخيصية وتتبع الأحداث فور وقوعها.
- **اختبار ثبات الـ Overlay أثناء التنقل**: التحقق من بقاء شاشة الحجب/التحديث نشطة حتى مع التنقل بين المسارات والصفحات (`Navigator.push`).

### تشغيل المثال:
```bash
cd example
flutter run
```
