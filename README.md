# 🎓 Campus Mart v2 — Enhanced Marketplace

## 🆕 What's New in v2

### ✅ Bugs Fixed
- **Infinite recursion fixed** — `@JsonIgnoreProperties` on bidirectional relations
- **Login proper validation** — checks real email format, verifies account exists
- **Proxy fixed** — frontend points to correct port `8081`

### ✨ New Features Added

| Feature | Where |
|---|---|
| Password strength meter | Register page |
| Password confirmation field | Register page |
| Show/hide password toggle | Login + Register |
| Email format validation (frontend + backend) | Both |
| Proper error messages ("Email not found", "Wrong password") | Login |
| **Multiple images per item** (up to 5) | AddItem + EditItem |
| **Image carousel** (prev/next arrows, thumbnail strip) | ItemDetail |
| **Click to zoom** (modal + keyboard ESC) | ItemDetail |
| **Item condition** (New/Like New/Good/Fair/Poor) | All item pages |
| **Negotiable price** flag | Item cards + detail |
| **View count** per item | ItemCard + detail |
| **College ID** shown on item cards | ItemCard |
| **Profile page** — update photo, bio, password | /profile |
| Edit existing item | /edit-item/:id |
| Filter listings by status | MyItems |
| Mark as Reserved (not just Sold) | ItemDetail + MyItems |
| Stats on profile (total/active/sold) | Profile |
| WhatsApp contact message with item details | ItemDetail |
| Keyboard arrow navigation in carousel | ItemDetail |
| Scroll-based navbar transparency | Navbar |

---

## 🛠️ How to Apply Changes to Existing Project

### Option A — Replace files (Recommended)

Copy the changed files from this v2 folder into your existing project:

```
backend/src/main/java/com/campusmart/model/     → replace Item.java, Student.java
backend/src/main/java/com/campusmart/service/   → replace StudentService.java, ItemService.java
backend/src/main/java/com/campusmart/repository/→ replace ItemRepository.java
backend/src/main/java/com/campusmart/controller/→ replace all controllers
frontend/src/pages/                             → replace all pages + add EditItem.js
frontend/src/components/                        → replace ItemCard.js, Navbar.js
frontend/src/api/api.js                         → replace
frontend/src/App.js, App.css                    → replace
frontend/package.json                           → replace (proxy changed to 8081)
```

Then run **one SQL command** to add new columns to existing tables:
```sql
USE campus_mart;
ALTER TABLE items ADD COLUMN IF NOT EXISTS `condition` ENUM('NEW','LIKE_NEW','GOOD','FAIR','POOR') DEFAULT 'GOOD';
ALTER TABLE items ADD COLUMN IF NOT EXISTS negotiable BOOLEAN DEFAULT FALSE;
ALTER TABLE items ADD COLUMN IF NOT EXISTS view_count INT DEFAULT 0;
ALTER TABLE items DROP COLUMN IF EXISTS photo_url;
ALTER TABLE students ADD COLUMN IF NOT EXISTS bio TEXT;
CREATE TABLE IF NOT EXISTS item_images (
    item_id BIGINT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);
```

### Option B — Fresh start

```sql
DROP DATABASE campus_mart;
-- Run campus_mart_v2.sql from scratch
```

---

## 🚀 Run the Project

```bash
# Backend (port 8081)
cd backend
mvn spring-boot:run

# Frontend (port 3000)
cd frontend
npm install
npm start
```

---

## 📱 Pages

| Page | URL | Auth |
|---|---|---|
| Home / Browse | / | No |
| Login | /login | No |
| Register | /register | No |
| Item Detail | /item/:id | No |
| Add Item | /add-item | ✅ Yes |
| Edit Item | /edit-item/:id | ✅ Yes |
| My Listings | /my-items | ✅ Yes |
| Profile | /profile | ✅ Yes |

---

## 🧩 API Endpoints (v2 additions)

| Method | Endpoint | New? |
|---|---|---|
| GET | /api/items/recent | ✅ New |
| PATCH | /api/items/:id/reserved | ✅ New |
| GET | /api/students/:id/stats | ✅ New |
