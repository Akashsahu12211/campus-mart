# CampusMart Launch Deployment Guide

**Status**: ✅ Ready for Cloud Deployment  
**Last Updated**: 2024

---

## 🎯 Deployment Overview

This guide covers deploying CampusMart across three platforms:
- **Backend**: Render.com or Railway.app (Java Spring Boot)
- **Frontend**: Vercel or Netlify (React)
- **Mobile**: Firebase App Distribution (Flutter)

---

## 📦 Part 1: Backend Deployment (Render or Railway)

### Prerequisites
- Backend code pushed to GitHub
- Database ready (MySQL 8.0+)
- Razorpay credentials
- Firebase credentials

### Option A: Deploy to Render.com

#### Step 1: Prepare Repository
```bash
cd backend
git add Dockerfile
git commit -m "Add Dockerfile for production deployment"
git push origin main
```

#### Step 2: Create New Service on Render
1. Visit [render.com](https://render.com)
2. Click "New +" → "Web Service"
3. Connect GitHub account
4. Select `campus-mart-v2` repository
5. Configure:
   - **Name**: `campus-mart-api`
   - **Environment**: `Docker`
   - **Region**: Choose closest to users
   - **Plan**: Standard ($7/month) or higher

#### Step 3: Set Environment Variables
In Render dashboard → Environment:
```
APP_ENV=production
JWT_SECRET=your-secret-key-here
JWT_EXPIRATION=86400000

SPRING_DATASOURCE_URL=jdbc:mysql://your-db-host:3306/campusmart?serverTimezone=UTC&allowPublicKeyRetrieval=true&useSSL=false
SPRING_DATASOURCE_USERNAME=root
SPRING_DATASOURCE_PASSWORD=your-db-password

FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email

RAZORPAY_KEY_ID=your-razorpay-key
RAZORPAY_SECRET=your-razorpay-secret

MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password

S3_BUCKET=your-s3-bucket
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=ap-south-1

FRONTEND_URL=https://campusmart.vercel.app
CORS_ALLOWED_ORIGINS=https://campusmart.vercel.app,https://www.campusmart.com
```

#### Step 4: Deploy
1. Click "Create Web Service"
2. Render will build from Dockerfile automatically
3. Wait for deployment (5-10 minutes)
4. Access at `https://campus-mart-api.onrender.com`

#### Step 5: Verify Deployment
```bash
curl https://campus-mart-api.onrender.com/api/public/health
# Expected response: {"status":"UP"}
```

### Option B: Deploy to Railway.app

#### Step 1: Install Railway CLI
```bash
npm install -g @railway/cli
railway login
```

#### Step 2: Initialize Project
```bash
cd backend
railway init
# Select: Docker
```

#### Step 3: Set Environment Variables
```bash
railway env
# Add all variables from Step 3 above
```

#### Step 4: Deploy
```bash
railway up
```

#### Step 5: Check Status
```bash
railway status
railway logs
```

---

## 🎨 Part 2: Frontend Deployment (Vercel or Netlify)

### Prerequisites
- Frontend code pushed to GitHub
- Vercel/Netlify account created

### Option A: Deploy to Vercel

#### Step 1: Connect Repository
1. Visit [vercel.com](https://vercel.com)
2. Click "Add New" → "Project"
3. Import GitHub repository: `campus-mart-v2`
4. Select root directory: `frontend`

#### Step 2: Configure Build
Vercel will auto-detect from `vercel.json`:
- Build Command: `npm run build`
- Output Directory: `build`
- Install Command: `npm ci`

#### Step 3: Set Environment Variables
In Vercel dashboard → Settings → Environment Variables:
```
REACT_APP_API_BASE_URL=https://campus-mart-api.onrender.com
REACT_APP_FIREBASE_API_KEY=AIzaSyD...
REACT_APP_FIREBASE_PROJECT_ID=campus-mart-prod
REACT_APP_RAZORPAY_KEY=rzp_live_...
```

#### Step 4: Deploy
1. Click "Deploy"
2. Vercel builds and deploys automatically
3. Access at `https://campus-mart.vercel.app`

#### Step 5: Set Custom Domain
1. Go to Settings → Domains
2. Add `www.campusmart.com`
3. Update DNS records at your registrar

### Option B: Deploy to Netlify

#### Step 1: Connect Repository
1. Visit [netlify.com](https://netlify.com)
2. Click "Add new site" → "Import an existing project"
3. Select GitHub
4. Choose `campus-mart-v2` repository

#### Step 2: Configure Build
Netlify will auto-detect from `netlify.toml`:
- Build command: `npm run build`
- Publish directory: `build`

#### Step 3: Set Environment Variables
In Netlify → Site settings → Build & deploy → Environment:
```
REACT_APP_API_BASE_URL=https://campus-mart-api.onrender.com
REACT_APP_FIREBASE_API_KEY=AIzaSyD...
REACT_APP_FIREBASE_PROJECT_ID=campus-mart-prod
REACT_APP_RAZORPAY_KEY=rzp_live_...
NODE_VERSION=18
```

#### Step 4: Deploy
1. Click "Deploy"
2. Netlify builds automatically
3. Access at `https://campus-mart.netlify.app`

#### Step 5: Set Custom Domain
1. Domain management → Add domain
2. Configure DNS records

---

## 📱 Part 3: Mobile Deployment (Flutter)

### Prerequisites
- Flutter fixes applied (see FLUTTER_FIXES_TODO.md)
- Google Play Developer account ($25 one-time)
- Apple Developer account ($99/year)
- Firebase App Distribution setup

### Android Release Build

#### Step 1: Build Release APK
```bash
cd mobile
flutter clean
flutter pub get

flutter build apk --release \
  --dart-define=API_BASE_URL=https://campus-mart-api.onrender.com
```

#### Step 2: Sign APK
APK is auto-signed if keystore exists. For first release:
```bash
# Generate keystore
keytool -genkey -v -keystore ~/key.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

#### Step 3: Upload to Firebase App Distribution
```bash
firebase app:distribute lib/build/app/outputs/flutter-app.apk \
  --app-id=<APP_ID> \
  --release-notes='v1.0.0 - Launch Release' \
  --testers='qa@campusmart.com,marketing@campusmart.com'
```

#### Step 4: Upload to Play Store
```bash
# Generate app bundle
flutter build appbundle --release

# Upload to Play Store using Google Play Console
# Or use bundletool for testing
```

---

## 🔄 Post-Deployment Checklist

### Immediate (Within 24 hours)
- [ ] Verify backend health check: `/api/public/health`
- [ ] Test frontend homepage load
- [ ] Test user login/registration
- [ ] Test payment flow (test credentials)
- [ ] Check error logs (no exceptions)
- [ ] Verify database migrations ran (V5_add_missing_indexes)
- [ ] Test rate limiting (5 auth requests, then 429 response)

### First Week
- [ ] Monitor error tracking (Sentry/LogRocket)
- [ ] Check performance metrics
- [ ] Verify email notifications working
- [ ] Test push notifications
- [ ] Load test with mock users
- [ ] Review user feedback

### Before Full Launch
- [ ] Security audit of deployment
- [ ] Performance optimization
- [ ] Backup and recovery testing
- [ ] Incident response plan
- [ ] On-call rotation setup

---

## 🚨 Troubleshooting

### Backend Build Fails
```bash
# Check logs
railway logs

# Verify Dockerfile
docker build -f Dockerfile -t test .

# Check Java version
java -version  # Should be 17+
```

### Frontend Build Fails
```bash
# Clear cache
rm -rf node_modules package-lock.json
npm install
npm run build

# Check build output
npm run build -- --verbose
```

### Database Connection Error
```bash
# Verify connection string
SPRING_DATASOURCE_URL=jdbc:mysql://host:3306/db?serverTimezone=UTC

# Check firewall rules
# Ensure MySQL allows remote connections
```

### Rate Limiting Too Strict
Adjust in `RateLimitFilter.java`:
```java
int limitPerMinute = path.contains("/auth") ? 10 : 200; // Increase limits
```

---

## 📊 Monitoring Setup

### Backend Monitoring (Render)
- Built-in logs: Dashboard → Logs
- Health checks: Automatic every 5 minutes
- Resource usage: CPU, memory, disk

### Frontend Monitoring (Vercel)
- Build logs: Dashboard → Deployments
- Analytics: Dashboard → Analytics
- Error tracking: Dashboard → Errors

### Database Monitoring
```bash
# Check indexes applied
SELECT * FROM information_schema.STATISTICS 
WHERE TABLE_SCHEMA = 'campusmart' 
AND TABLE_NAME = 'notification_entry';

# Monitor slow queries
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
```

---

## 🔐 Security Post-Deployment

- [ ] Enable HTTPS everywhere (automatic on Vercel/Render)
- [ ] Set CORS headers correctly
- [ ] Enable rate limiting (done ✅)
- [ ] Rotate JWT secret (monthly)
- [ ] Review database access logs
- [ ] Enable 2FA on all admin accounts
- [ ] Set up security headers

---

## 💰 Cost Estimation (Monthly)

| Service | Plan | Cost |
|---------|------|------|
| Render (Backend) | Standard | $7 |
| Vercel (Frontend) | Free/Pro | $0-20 |
| AWS S3 (Storage) | Standard | $5-50 |
| Firebase | Spark | $0 |
| **Total** | | **$12-77** |

---

## ✅ Deployment Complete!

Your CampusMart application is now deployed and ready for users.

**Live URLs**:
- Frontend: `https://campusmart.vercel.app`
- Backend API: `https://campus-mart-api.onrender.com`
- Mobile: Available on Play Store (after approval)

**Support**: For deployment issues, refer to platform documentation or contact support teams.
