# Phase 9 QA Runbook

Phase 9 ka focus release confidence par hai: automated tests, health checks, build verification, aur pre-launch smoke coverage.

## Backend

```powershell
cd C:\Users\HP\All_Projects\campus-mart-v2\backend
mvn test -q
mvn -q -DskipTests package
```

Expected:
- security tests green
- auth/session regression tests green
- `target/campus-mart-backend-2.0.0.jar` build ho

## Frontend

```powershell
cd C:\Users\HP\All_Projects\campus-mart-v2\frontend
npm test
npm run build
```

Expected:
- auth API regression tests green
- production build `frontend/build` me generate ho

## Flutter

```powershell
cd C:\Users\HP\All_Projects\campus_mart_flutter\campus_mart_app
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build apk --debug
```

Expected:
- test suite green
- analyze me hard blockers na ho
- APK `build/app/outputs/flutter-apk/app-debug.apk` me generate ho

## Runtime Smoke Check

Backend aur web run hone ke baad:

```powershell
cd C:\Users\HP\All_Projects\campus-mart-v2
.\PHASE_9_SMOKE_CHECK.ps1
```

Ye checks run honge:
- `/api/public/health`
- `/api/public/ready`
- `/api/items/paginated`
- web root `http://localhost:3000`
- Flutter debug APK presence

## Health Endpoints

- `GET /api/public/health`
  Returns app status, environment, uptime, and token TTL summary.
- `GET /api/public/ready`
  Returns readiness state with database check.

## Launch Gate

Phase 9 ko pass tab maana ja sakta hai jab:
- backend tests pass
- frontend tests/build pass
- Flutter tests/analyze/build pass
- smoke script pass
- backend health and readiness both `UP` return karein
