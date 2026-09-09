# 🎓 Campus Mart — Flutter App

College Student Marketplace ka Flutter mobile app.
Same Spring Boot backend use karta hai jo web project mein tha.

---

## ⚡ Quick Setup (Step by Step)

### Step 1 — Flutter Install Karo
```
https://docs.flutter.dev/get-started/install/windows
```
- Flutter SDK download karo
- Extract karo `C:\flutter`
- Environment PATH mein add karo: `C:\flutter\bin`
- CMD mein check karo: `flutter doctor`

### Step 2 — Android Studio Setup
1. Android Studio open karo
2. **File → Open** → `campus_mart_app` folder select karo
3. Wait karo — Gradle sync hoga automatically
4. SDK install karo agar puchhe

### Step 3 — IP Address Set Karo ⚠️ IMPORTANT
```
CMD mein type karo: ipconfig
IPv4 Address dekho — jaise 192.168.1.5
```

`lib/config/api_config.dart` kholо aur change karo:
```dart
static const String baseUrl = 'http://192.168.TUMHARA_IP:8081/api';
```

**Emulator use kar rahe ho?** Tab yeh use karo:
```dart
static const String baseUrl = 'http://10.0.2.2:8081/api';
```

### Step 4 — Backend Run Karo
```bash
cd backend
mvn spring-boot:run
```
Backend port 8081 pe chalna chahiye.

### Step 5 — App Run Karo
Android Studio mein:
- Device connect karo (USB Debugging ON karo) ya Emulator start karo
- **Run → Run 'main.dart'** ya green play button dabao

---

## 🗂️ Project Structure
```
lib/
├── main.dart              ← App entry point
├── config/
│   ├── api_config.dart    ← ⚠️ IP ADDRESS YAHAN CHANGE KARO
│   └── app_theme.dart     ← Colors, fonts
├── models/
│   ├── student_model.dart
│   ├── item_model.dart
│   └── category_model.dart
├── services/
│   ├── api_service.dart   ← All API calls
│   └── image_service.dart ← Camera + Gallery
├── providers/
│   └── auth_provider.dart ← Login state
├── screens/
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── item_detail_screen.dart
│   ├── add_item_screen.dart
│   ├── my_items_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── item_card.dart
│   └── custom_button.dart
└── utils/
    └── validators.dart
```

---

## 📱 App Features
| Feature | Status |
|---|---|
| Login with validation | ✅ |
| Register with password confirm | ✅ |
| Browse items (grid) | ✅ |
| Search + Category filter | ✅ |
| Item detail with image carousel | ✅ |
| Zoom image (pinch to zoom) | ✅ |
| Camera + Gallery upload | ✅ |
| Add item (5 photos) | ✅ |
| My listings | ✅ |
| Mark sold / reserved | ✅ |
| Profile update | ✅ |
| Profile photo from camera | ✅ |
| WhatsApp contact | ✅ |
| Dark theme | ✅ |

---

## ❗ Common Errors

### "Connection refused" / API not working
- Backend chal raha hai? `mvn spring-boot:run`
- IP sahi hai? `ipconfig` se check karo
- Phone aur laptop same WiFi pe hain?
- `api_config.dart` mein IP update kiya?

### "Cleartext HTTP not permitted"
- `AndroidManifest.xml` mein `android:usesCleartextTraffic="true"` hai ya nahi check karo

### Gradle sync fail
- **File → Invalidate Caches → Restart** try karo
- Internet connection check karo

### Camera permission denied
- Phone Settings → Apps → Campus Mart → Permissions → Camera ON karo

---

## 🔨 APK Build (Dosto ko bhejne ke liye)
```bash
flutter build apk --release
```
APK milega: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📋 Screens

| Screen | Route |
|---|---|
| Home | `/` |
| Login | `/login` |
| Register | `/register` |
| Item Detail | `/item` (args: int id) |
| Add Item | `/add-item` |
| My Listings | `/my-items` |
| Profile | `/profile` |

---

## 🎯 Same Backend — Zero Changes!
Flutter app same Spring Boot backend (port 8081) use karta hai.
Web app aur Flutter app dono ek hi backend share karte hain. 🚀
