# 📱 Firebase Push Notifications Setup Guide

## Phase 3 Complete! ✅

All Firebase dependencies and services have been added to your Campus Mart backend.

---

## 🚀 Step-by-Step Setup (Local Testing)

### Step 1: Create Firebase Project
1. Go to: https://console.firebase.google.com/
2. Click: **Create a new project**
3. Name: `Campus-Mart` (or any name)
4. Click: **Create project**
5. Wait 30 seconds for initialization

### Step 2: Get Service Account Key
1. In Firebase Console, click: **Settings** ⚙️ (top-left gear)
2. Go to: **Service Accounts** tab
3. Click: **Generate New Private Key**
4. A JSON file will download automatically

### Step 3: Add Key to Backend
1. Open the downloaded JSON file
2. Copy entire contents
3. Create file: `backend/src/main/resources/firebase-key.json`
4. Paste the contents
5. Save file

⚠️ **Important**: Add `firebase-key.json` to `.gitignore` (never commit secrets!)

```bash
echo "firebase-key.json" >> backend/.gitignore
```

### Step 4: Update application.properties (Optional)
Add to `backend/src/main/resources/application.properties`:

```properties
# Firebase Configuration
firebase.enabled=true
firebase.project-id=${FIREBASE_PROJECT_ID}
firebase.private-key=${FIREBASE_PRIVATE_KEY}
firebase.client-email=${FIREBASE_CLIENT_EMAIL}
```

### Step 5: Build Backend
```bash
cd backend
mvn clean compile -DskipTests
mvn package -DskipTests
```

### Step 6: Run Backend
```bash
java -jar target/campus-mart-backend-2.0.0.jar
```

Expected output:
```
✅ Firebase initialized successfully
```

---

## 📱 Client-Side Setup (React Frontend)

### Step 1: Install Firebase Package
```bash
cd frontend
npm install firebase
```

### Step 2: Create Firebase Config File
Create: `frontend/src/config/firebase.js`

```javascript
import { initializeApp } from 'firebase/app';
import { getMessaging, getToken, onMessage } from 'firebase/messaging';

const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "campus-mart-xxxxx.firebaseapp.com",
  projectId: "campus-mart-xxxxx",
  storageBucket: "campus-mart-xxxxx.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef123456"
};

const app = initializeApp(firebaseConfig);
const messaging = getMessaging(app);

export { messaging };
```

### Step 3: Add Service Worker
Create: `frontend/public/firebase-messaging-sw.js`

```javascript
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "YOUR_API_KEY",
  projectId: "campus-mart-xxxxx",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef123456"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Received background message:', payload);
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/logo.png'
  });
});
```

### Step 4: Request Permission & Save Token
Add to `frontend/src/pages/Home.js` or `App.js`:

```javascript
import { messaging } from '../config/firebase';
import { getToken } from 'firebase/messaging';

async function requestNotificationPermission() {
  try {
    const permission = await Notification.requestPermission();
    if (permission === 'granted') {
      const token = await getToken(messaging, {
        vapidKey: 'YOUR_VAPID_KEY_HERE'
      });
      console.log('Device token:', token);
      
      // Send to backend
      await fetch(`/api/students/${userId}/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ deviceToken: token })
      });
    }
  } catch (error) {
    console.error('Notification permission denied:', error);
  }
}

// Call on app startup
useEffect(() => {
  requestNotificationPermission();
}, []);
```

### Step 5: Handle Incoming Notifications
```javascript
import { onMessage } from 'firebase/messaging';
import { messaging } from '../config/firebase';

onMessage(messaging, (payload) => {
  console.log('Received foreground notification:', payload);
  
  // Show in-app notification
  if (payload.notification) {
    showInAppNotification(
      payload.notification.title,
      payload.notification.body
    );
  }
});
```

---

## 📱 Mobile (Flutter) Setup

### Step 1: Add Firebase Plugin
```bash
cd campus_mart_app
flutter pub add firebase_messaging
flutter pub get
```

### Step 2: Configure for Android
Edit: `android/app/build.gradle`

```gradle
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.0.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

### Step 3: Configure for iOS
```bash
cd ios
pod install
cd ..
```

### Step 4: Initialize Firebase Messaging in Flutter
Edit: `lib/main.dart`

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Get device token
  String? token = await FirebaseMessaging.instance.getToken();
  print('📱 Device token: $token');
  
  // Save to backend
  if (token != null) {
    await ApiService().post(
      '/students/${userId}/device-token',
      {'deviceToken': token}
    );
  }
  
  // Handle foreground notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📬 Notification received: ${message.notification?.title}');
    showNotificationDialog(message);
  });
  
  // Handle background notifications
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('✅ Notification tapped: ${message.notification?.title}');
    navigateToRelevantScreen(message);
  });
  
  runApp(const CampusMartApp());
}
```

---

## 🧪 Testing Notifications

### Test 1: Manual Test (Firebase Console)
1. Go to: https://console.firebase.google.com/
2. Select your project
3. Go to: **Cloud Messaging** tab
4. Click: **Send your first message**
5. Fill:
   - Title: "Test Notification"
   - Body: "This is a test"
   - Target: Select "Device tokens"
   - Paste user's device token
6. Click: **Publish**
7. Check: Backend logs should show "✅ Notification sent successfully"

### Test 2: Via API
```bash
curl -X POST http://localhost:8081/api/students/8/device-token \
  -H "Content-Type: application/json" \
  -d '{"deviceToken":"YOUR_TOKEN_HERE"}'
```

### Test 3: Send Test Message
```bash
curl -X POST http://localhost:8081/api/notifications/test \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 8,
    "title": "Test Message",
    "body": "This is a test notification"
  }'
```

---

## 🔑 Getting VAPID Key (For Web)

1. Firebase Console → Project Settings ⚙️
2. Go to: **Cloud Messaging** tab
3. Find: **Web Push certificates**
4. Click: **Generate Key Pair**
5. Copy the key and paste in frontend config

---

## 📊 API Endpoints (Now Available)

### Save Device Token
```
POST /api/students/{id}/device-token
Body: { "deviceToken": "token_string" }
```

### Get Device Token
```
GET /api/students/{id}/device-token
Response: { "deviceToken": "token_string" }
```

---

## 🐛 Troubleshooting

### ❌ "Firebase not initialized"
- Check if `firebase-key.json` exists in correct location
- Verify JSON content is valid
- Check logs for initialization errors

### ❌ "Notification not sent"
- Check if device token is valid
- Verify Firebase project is active
- Check quotas aren't exceeded

### ❌ "Notification permission denied"
- User needs to grant notification permission
- Different browsers handle this differently
- Check browser console for errors

### ❌ "Service worker not registered"
- Ensure HTTPS is enabled
- Check `firebase-messaging-sw.js` exists in public folder
- Verify file path is correct

---

## 📈 Notification Types Implemented

### 1. New Message Notification
- Sent when: User receives a chat message
- Shows: Sender name + message preview
- Example: "New message from Rahul: Hey, is this item..."

### 2. New Offer Notification  
- Sent when: Someone makes an offer on item
- Shows: Buyer name + offer price
- Example: "New offer on iPhone 13: Priya offered ₹25000"

### 3. Offer Response Notification
- Sent when: Offer accepted/rejected
- Shows: Item name + status
- Example: "Your offer has been accepted!"

### 4. System Notifications
- Admin announcements
- Item expiry reminders
- Account security alerts

---

## 🚀 Next Steps

1. **Get Firebase Credentials**: Follow Step 1-2 above
2. **Update Frontend**: Add Firebase config and service worker
3. **Update Flutter**: Add Firebase Messaging package
4. **Test**: Send test notification from Firebase console
5. **Deploy**: Push to production when working

---

## ✅ Phase 3: Complete!

### What's Done:
- [x] Firebase Admin SDK added to backend
- [x] NotificationService created
- [x] ChatService integrated with notifications
- [x] Device token endpoints added
- [x] Firebase Config class created
- [x] Documentation created

### What's Next:
- **Phase 4**: Monetization (Razorpay, Payment Gateway)

---

## 📞 Need Help?

- Firebase Docs: https://firebase.google.com/docs/messaging
- React Integration: https://firebase.google.com/docs/cloud-messaging/js/client
- Flutter Integration: https://firebase.flutter.dev/docs/messaging/overview

---

**Status: ✅ Phase 3 Part B - COMPLETE**

All Firebase infrastructure is in place. Just need to add your credentials and test!
