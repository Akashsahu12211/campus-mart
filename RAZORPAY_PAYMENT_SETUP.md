# 🚀 PHASE 4: RAZORPAY PAYMENT INTEGRATION - COMPLETE SETUP GUIDE

**Status**: ✅ ALL CODE GENERATED & READY FOR IMPLEMENTATION

---

## 📋 TABLE OF CONTENTS
1. [Razorpay Account Setup](#razorpay-account-setup)
2. [Implementation Checklist](#implementation-checklist)
3. [Backend Setup](#backend-setup)
4. [Frontend (React) Setup](#frontend-react-setup)
5. [Mobile (Flutter) Setup](#mobile-flutter-setup)
6. [Testing Instructions](#testing-instructions)
7. [Production Deployment](#production-deployment)

---

## 🔑 RAZORPAY ACCOUNT SETUP (5 MINUTES)

### Step 1: Create Account
1. Go to [https://dashboard.razorpay.com/signup](https://dashboard.razorpay.com/signup)
2. Register with email
3. Complete basic verification

### Step 2: Generate Test Keys
1. Dashboard → Settings → API Keys
2. Click "Generate Test Key"
3. Copy **Key ID** and **Key Secret**

```
✅ TEST MODE (No real money)
Key ID:      rzp_test_XXXXXXXXXX
Key Secret:  XXXXXXXXXXXXXXXXXX
```

---

## ✅ IMPLEMENTATION CHECKLIST

### **BACKEND (45 min)**
- [ ] `pom.xml` - Added Razorpay dependencies ✅
- [ ] `PaymentOrder.java` - Model entity created ✅
- [ ] `EscrowEvent.java` - Event logging entity created ✅
- [ ] `PaymentOrderRepository.java` - JPA repository created ✅
- [ ] `EscrowEventRepository.java` - Event repository created ✅
- [ ] `PaymentService.java` - Core service logic created ✅
- [ ] `PaymentController.java` - REST API endpoints created ✅
- [ ] `application.properties` - Added Razorpay keys
- [ ] MySQL schema created (payment_orders + escrow_events tables)
- [ ] `CampusMartApplication.java` - @EnableScheduling verified
- [ ] Backend compiled successfully (`mvn compile -DskipTests`)

### **FRONTEND REACT (30 min)**
- [ ] `public/index.html` - Razorpay script added ✅
- [ ] `src/api/api.js` - Payment API methods added ✅
- [ ] `src/components/PayButton.js` - Button component created ✅
- [ ] `src/pages/MyOrders.js` - Order history page created ✅
- [ ] `src/pages/ItemDetail.js` - Payment UI integrated ✅
- [ ] `src/App.js` - MyOrders route added ✅
- [ ] `src/components/Navbar.js` - Orders link added ✅
- [ ] Frontend tested (no console errors)

### **FLUTTER MOBILE (30 min)**
- [ ] `pubspec.yaml` - razorpay_flutter + webview_flutter added ✅
- [ ] `flutter pub get` - Dependencies installed
- [ ] `lib/services/api_service.dart` - Payment methods added ✅
- [ ] `lib/screens/payment_screen.dart` - Payment screen created ✅
- [ ] `lib/screens/item_detail_screen.dart` - Pay button integrated ✅
- [ ] Android permissions configured
- [ ] Flutter app compiled successfully

---

## 🔧 BACKEND SETUP

### Step 1: Razorpay Keys
Edit `src/main/resources/application.properties`:

```properties
# Get from: https://dashboard.razorpay.com/settings/api-keys
razorpay.key.id=rzp_test_XXXXXXXXXX
razorpay.key.secret=XXXXXXXXXXXXXXXXXX
razorpay.escrow.auto.release.hours=48
razorpay.platform.fee.percent=0
```

### Step 2: Create MySQL Tables
Run this SQL in MySQL:

```sql
USE campus_mart;

-- Payment orders table
CREATE TABLE IF NOT EXISTS payment_orders (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    razorpay_order_id VARCHAR(100) NOT NULL UNIQUE,
    razorpay_payment_id VARCHAR(100) DEFAULT NULL,
    razorpay_signature VARCHAR(300) DEFAULT NULL,
    buyer_id BIGINT NOT NULL,
    seller_id BIGINT NOT NULL,
    item_id BIGINT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'INR',
    status ENUM('CREATED','PAID','FAILED','REFUNDED','ESCROW_HOLD','RELEASED','DISPUTED') DEFAULT 'CREATED',
    payment_method VARCHAR(50) DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    escrow_released BOOLEAN DEFAULT FALSE,
    release_deadline TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id) REFERENCES students(id),
    FOREIGN KEY (seller_id) REFERENCES students(id),
    FOREIGN KEY (item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Escrow timeline
CREATE TABLE IF NOT EXISTS escrow_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT NOT NULL,
    event_type ENUM('ORDER_CREATED','PAYMENT_RECEIVED','DELIVERY_CONFIRMED','ESCROW_RELEASED','DISPUTE_RAISED','DISPUTE_RESOLVED','REFUND_INITIATED','REFUND_DONE') NOT NULL,
    triggered_by BIGINT DEFAULT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES payment_orders(id) ON DELETE CASCADE,
    FOREIGN KEY (triggered_by) REFERENCES students(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Indexes
CREATE INDEX idx_orders_buyer ON payment_orders(buyer_id);
CREATE INDEX idx_orders_seller ON payment_orders(seller_id);
CREATE INDEX idx_orders_status ON payment_orders(status);
CREATE INDEX idx_events_order ON escrow_events(order_id);

SHOW TABLES LIKE 'payment%';
```

### Step 3: Compile & Run
```bash
cd backend
mvn clean compile -DskipTests
mvn spring-boot:run
# Backend should start on http://localhost:8081
```

---

## 🌐 FRONTEND (REACT) SETUP

### Step 1: Verify Files Created
```
✅ public/index.html - Razorpay script added
✅ src/api/api.js - Payment endpoints added
✅ src/components/PayButton.js - Created
✅ src/pages/MyOrders.js - Created
✅ src/pages/ItemDetail.js - Modified
✅ src/App.js - Route added
✅ src/components/Navbar.js - Orders link added
```

### Step 2: Test Frontend
```bash
cd frontend
npm start
# Should start on http://localhost:3000
```

### Step 3: Check Routes
- ✅ Item Detail Page: Has "Pay ₹XXX Securely" button
- ✅ Click pay button → Opens Razorpay checkout
- ✅ Navbar has "💳 Orders" link
- ✅ Orders page shows payment history

---

## 📱 FLUTTER SETUP

### Step 1: Update Dependencies
```bash
cd campus_mart_app
flutter pub get  # Downloads razorpay_flutter + webview_flutter
```

### Step 2: Verify Android Permissions
Check `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

### Step 3: Build & Test
```bash
flutter pub get
flutter run  # For emulator
flutter build apk --release  # For APK
```

---

## 🧪 TESTING INSTRUCTIONS

### **TEST CREDENTIALS**

#### UPI (Recommended)
```
Success UPI ID:  success@razorpay
Failure UPI ID:  failure@razorpay
```

#### Card
```
Card Number:  4111 1111 1111 1111
Expiry:       Any future date (MM/YY)
CVV:          Any 3 digits (e.g., 123)
OTP:          1234
```

#### Cash on Delivery (CoD)
```
Just select CoD and order will be created
```

### **TEST FLOW - COMPLETE TRANSACTION**

#### **Step 1: List an Item**
1. Login as Seller
2. Add Item (₹500 or any amount)
3. Copy item link

#### **Step 2: Purchase as Buyer**
1. Login as different user (Buyer)
2. Open item detail
3. Click "💳 Pay ₹500 Securely"
4. Razorpay checkout opens
5. Select UPI → success@razorpay (or card details above)
6. Complete payment

#### **Step 3: Verify Order Created**
- Payment status shows **🔒 Payment in Escrow**
- Amount held: ₹500
- Escrow deadline: 48 hours

#### **Step 4: Confirm Delivery**
1. As Buyer, click "✅ Received Item — Release Payment"
2. Status changes to **✅ Payment Released**
3. Payment goes to Seller

#### **Step 5: Check MyOrders Page**
1. Buyer → Navbar → 💳 Orders
2. See all purchases with timeline
3. Expand order to see:
   - ORDER_CREATED
   - PAYMENT_RECEIVED
   - DELIVERY_CONFIRMED
   - ESCROW_RELEASED

#### **Step 6: Test Dispute**
1. Create new order
2. Click "⚠️ Dispute" button
3. Enter reason: "Item damaged"
4. Status changes to **DISPUTED**
5. Admin reviews (manually)

### **TEST SCENARIO: AUTO-RELEASE**
```
1. Create order (payment in escrow)
2. Wait 48 hours OR
3. Backend scheduler runs hourly → auto-releases expired orders
4. Check: Status changes from ESCROW_HOLD → RELEASED
```

---

## 🌐 PRODUCTION DEPLOYMENT

### **CRITICAL: HTTPS Required**
Razorpay live payments ONLY work with HTTPS (SSL certificate)

### **Step 1: Get Live Keys**
1. Complete KYC on Razorpay dashboard
2. Go to Settings → API Keys → Generate Live Key
3. Copy live keys: `rzp_live_XXXXXXXXXX`

### **Step 2: Update Configuration**
```properties
razorpay.key.id=rzp_live_XXXXXXXXXX
razorpay.key.secret=XXXXXXXXXXXXXXXXXX
```

### **Step 3: Enable HTTPS**
- Get SSL certificate (Let's Encrypt, AWS, GoDaddy)
- Configure in backend: `server.ssl.key-store=...`
- Frontend: Use `https://yourdomain.com`

### **Step 4: Database Backup**
```bash
mysqldump campus_mart > backup.sql
```

### **Step 5: Deploy**
```bash
# Backend
mvn clean package -DskipTests
java -jar target/campus-mart-backend-2.0.0.jar

# Frontend
npm run build
# Deploy build/ folder to static hosting

# Flutter
flutter build apk --release
# Upload to Play Store / TestFlight
```

### **Step 6: Monitor**
- Check payment success logs
- Monitor escrow auto-releases
- Handle disputes in admin panel

---

## 📊 PAYMENT FLOW DIAGRAM

```
┌─────────────────────────────────────────┐
│ Buyer clicks "Pay" button               │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ Frontend creates order on backend       │
│ POST /api/payments/create-order         │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ Backend generates Razorpay order        │
│ Saves to DB with status: CREATED        │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ Razorpay checkout opens                 │
│ Buyer enters payment details            │
└────────────┬────────────────────────────┘
             │
             ▼
┌──────────────────────┬──────────────────┐
│ Payment Success      │ Payment Failed   │
├──────────────────────┼──────────────────┤
│ Frontend verifies    │ Show error       │
│ signature            │ Status: FAILED   │
└──────────┬───────────┴──────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Backend stores payment data             │
│ Status: ESCROW_HOLD (48 hours)          │
│ Item: RESERVED                          │
└────────────┬────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
    ▼                 ▼
┌────────────┐  ┌────────────────┐
│ Buyer      │  │ 48 hour timer  │
│ confirms   │  │ expires        │
│ delivery   │  │                │
└──────┬─────┘  └────────┬───────┘
       │                 │
       └────────┬────────┘
                │
                ▼
       ┌────────────────────┐
       │ Status: RELEASED   │
       │ Payment → Seller   │
       │ Item: SOLD         │
       └────────────────────┘
```

---

## 🐛 TROUBLESHOOTING

### **Issue: "Razorpay key not found"**
```
❌ Solution: Check application.properties
✅ Verify: razorpay.key.id and razorpay.key.secret set
```

### **Issue: "Payment verification failed"**
```
❌ Possible cause: Invalid HMAC signature
✅ Check: Both keys match exactly (no spaces)
```

### **Issue: "Item status not updating after payment"**
```
❌ Check: PaymentService.verifyPayment() setting item.status
✅ Verify: Item entity has getStatus()/setStatus() methods
```

### **Issue: "Flutter app crashes on payment"**
```
❌ Check: razorpay_flutter dependency installed
✅ Solution: flutter pub get && flutter clean && flutter run
```

### **Issue: "Orders page shows empty"**
```
❌ Check: User logged in
✅ Verify: getBuyerOrders API returns correct data
```

---

## 📞 SUPPORT

### Common Questions:

**Q: How long does escrow hold payment?**
A: 48 hours (configurable in `razorpay.escrow.auto.release.hours`)

**Q: Can buyer cancel after payment?**
A: Yes, raise a dispute → admin reviews

**Q: What payment methods are supported?**
A: UPI, Card, Net Banking, Cash on Delivery

**Q: Is test mode safe?**
A: Yes! Test mode doesn't charge real money

**Q: When to switch to live keys?**
A: After complete testing + HTTPS setup + KYC approval

---

## ✅ VERIFICATION CHECKLIST

Before going live:
- [ ] Backend API responds at `/api/payments/config`
- [ ] Frontend displays PayButton on item detail
- [ ] Can create test payment without errors
- [ ] Order appears in MyOrders page
- [ ] Confirm delivery button works
- [ ] Dispute flow tested
- [ ] Auto-release scheduler verified (hourly)
- [ ] All three platforms compile without errors
- [ ] Test payment history in database
- [ ] HTTPS configured (for production)

---

## 🎉 YOU'RE READY!

**All code is generated and ready for implementation.**

### Next Steps:
1. ✅ Copy code into your projects
2. ✅ Update Razorpay keys (application.properties)
3. ✅ Create MySQL tables
4. ✅ Run backend, frontend, flutter
5. ✅ Test with test credentials
6. ✅ Deploy to production

**Total Implementation Time**: ~2 hours

Good luck! 🚀
