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

### 1. عبر المجلد المحلي (Local Path)
```yaml
dependencies:
  firestore_app_control:
    path: ./packages/firestore_app_control
```

### 2. عبر مستودع Git خاص (Private Git Repository)
```yaml
dependencies:
  firestore_app_control:
    git:
      url: https://github.com/your-org/firestore_app_control.git
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

  // حوار تحديث اختياري مخصص
  optionalUpdateBuilder: (context, platformConfig, currentVersion, onDismiss) {
    showMyCustomDialog(
      context: context,
      onLater: onDismiss,
    );
  },

  child: child!,
)
```

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
