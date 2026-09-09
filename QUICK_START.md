# ⚡ QUICK START - RAZORPAY PAYMENT (15 MINUTE SETUP)

**Objective**: Get payment system working in 15 minutes  
**Prerequisite**: Have Razorpay test account already

---

## 🏃 STEP 1: GET RAZORPAY TEST KEYS (2 min)

1. Go to [Razorpay Dashboard](https://dashboard.razorpay.com/settings/api-keys)
2. Click "Generate Test Key"
3. Copy these two values:
   ```
   Key ID:     rzp_test_XXXXXXXXXX
   Key Secret: XXXXXXXXXXXXXXXXXX
   ```

---

## 🔧 STEP 2: UPDATE BACKEND KEYS (1 min)

Edit: `backend/src/main/resources/application.properties`

```properties
# Add these two lines (or replace if exists)
razorpay.key.id=rzp_test_YOUR_KEY_ID_HERE
razorpay.key.secret=YOUR_SECRET_HERE
```

Save the file ✅

---

## 🗄️ STEP 3: CREATE MYSQL TABLES (3 min)

Open MySQL client and run:

```bash
mysql -u root -p < backend/payment_schema.sql
```

Or in MySQL CLI:
```sql
USE campus_mart;
SHOW TABLES LIKE 'payment%';  -- Should show payment_orders and escrow_events
```

✅ Tables created

---

## 🚀 STEP 4: START BACKEND (3 min)

```bash
cd backend
mvn clean compile -DskipTests
mvn spring-boot:run
```

Wait for: `Started CampusMartApplication in X seconds`

✅ Backend running on http://localhost:8081

---

## 🌐 STEP 5: START FRONTEND (2 min)

```bash
cd frontend
npm start
```

Wait for: `Compiled successfully` and browser opens

✅ Frontend running on http://localhost:3000

---

## 🧪 STEP 6: TEST PAYMENT (4 min)

### A. Add Item as Seller
1. Login with Seller account
2. Add any item (e.g., ₹500)
3. Keep tab open

### B. Switch to Buyer
1. New browser / Incognito
2. Login as Buyer
3. Find the item you just added

### C. Click Pay Button
1. Click "💳 Pay ₹500 Securely"
2. Razorpay modal opens

### D. Simulate Payment
1. Select **UPI**
2. Enter: `success@razorpay`
3. Click Pay
4. Success! ✅

### E. Confirm Receipt
1. Click "✅ I Received the Item"
2. Payment released to seller ✅

### F. View Order History
1. Navbar → 💳 Orders
2. See payment with timeline ✅

---

## 📱 BONUS: FLUTTER SETUP (5 min)

```bash
cd campus_mart_app
flutter pub get
flutter run
```

Same payment flow works on mobile! ✅

---

## ✅ QUICK VERIFICATION

| Component | Status | Command |
|-----------|--------|---------|
| Backend | ✅ | `curl http://localhost:8081/api/payments/config` |
| Frontend | ✅ | Open http://localhost:3000 |
| Database | ✅ | `mysql -e "USE campus_mart; SHOW TABLES LIKE 'payment%';"` |
| Payment | ✅ | Test with success@razorpay |

---

## 🎯 WHAT'S WORKING NOW

### Buyer Features
- ✅ See "Pay" button on items
- ✅ Complete Razorpay payment
- ✅ Money held in escrow (safe)
- ✅ Confirm delivery
- ✅ View order history
- ✅ Raise disputes if needed

### Seller Features
- ✅ Receive payment after buyer confirms
- ✅ See orders in history
- ✅ Automatic payment release after 48h

### Admin (Backend)
- ✅ Hourly auto-release of expired escrows
- ✅ Payment verification with HMAC
- ✅ Complete audit trail in database

---

## 🔴 IF SOMETHING BREAKS

### Error: "Razorpay key not found"
```
→ Check application.properties has correct key ID and secret
→ Restart backend: mvn spring-boot:run
```

### Error: "Cannot find PaymentController"
```
→ Make sure PaymentController.java was copied to correct location
→ Correct path: backend/src/main/java/com/campusmart/controller/
```

### Error: "payment_orders table not found"
```
→ Run: mysql -u root -p < backend/payment_schema.sql
→ Verify: SELECT * FROM payment_orders;
```

### Error: "Razorpay checkout not opening"
```
→ Check: public/index.html has Razorpay script
→ Check browser console for errors (F12)
```

### Error: "Flutter app crashes"
```
→ Run: flutter pub get
→ Run: flutter clean && flutter run
```

---

## 📊 TEST DATA

### Test UPI IDs
| Type | ID |
|------|-----|
| Success | `success@razorpay` |
| Failure | `failure@razorpay` |

### Test Card
| Field | Value |
|-------|-------|
| Number | 4111 1111 1111 1111 |
| MM/YY | 12/25 (any future) |
| CVV | 123 |
| OTP | 1234 |

---

## 🎯 NEXT CHECKPOINT

After 15 minutes, you should have:
- ✅ Backend running on 8081
- ✅ Frontend running on 3000
- ✅ Database with payment tables
- ✅ Successfully made test payment
- ✅ Payment showing in order history

If all above are working → **PAYMENT SYSTEM IS LIVE** 🎉

---

## 📞 COMMON ISSUES & SOLUTIONS

| Issue | Solution |
|-------|----------|
| "Port 8081 already in use" | Kill existing Java: `taskkill /F /IM java.exe` |
| "npm: command not found" | Install Node.js from nodejs.org |
| "mvn: command not found" | Install Maven or add to PATH |
| "mysql: command not found" | Add MySQL to PATH or use MySQL Workbench |
| "Payment verification failed" | Check keys match exactly (no spaces) |
| "Item not updating to RESERVED" | Restart backend server |

---

## 📈 AFTER INITIAL SETUP

### Test More Scenarios
1. Test card payment
2. Test failed payment
3. Test dispute raising
4. Wait 48h or check logs for auto-release
5. Test with multiple items

### Production Checklist (Later)
- [ ] Get Razorpay live keys
- [ ] Buy SSL certificate
- [ ] Update to https://
- [ ] Set up webhook notifications
- [ ] Complete KYC on Razorpay
- [ ] Set up refund workflow

---

## 🎉 YOU'RE DONE!

**Time taken**: 15 minutes  
**Files needed**: 18 files (all generated already)  
**Status**: ✅ Payment system LIVE

Next level: Customize payment methods, add wallet integration, set up notifications.

Good luck! 🚀
