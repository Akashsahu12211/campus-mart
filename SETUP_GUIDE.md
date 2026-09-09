# Campus Mart - Environment Setup Guide

## First Time Setup

### Frontend Setup
```bash
cd frontend
npm install
cp .env.example .env
# Edit .env with your local values
npm start
```

### Backend Setup
```bash
cd backend
# Create application-local.properties if needed
mvn clean package
java -jar target/campus-mart-backend-2.0.0.jar
```

## Environment Variables

### Frontend (.env)
- `REACT_APP_API_URL`: Backend API URL (default: http://localhost:8081/api)
- `REACT_APP_WS_URL`: WebSocket URL (default: http://localhost:8081/ws)
- `REACT_APP_FIREBASE_*`: Firebase configuration from Firebase Console

### Backend (application.properties)
- Database credentials: Check src/main/resources/application.properties
- Firebase credentials: Place firebase-key.json in src/main/resources/
- JWT Secret: Auto-generated (insecure for dev, use for production only)

## Important Security Notes

⚠️ **NEVER commit .env files**
- .env files are in .gitignore - keep them local only
- Use .env.example as template for new developers
- Share secrets through secure channel (1Password, LastPass, etc.)

⚠️ **Firebase Credentials**
- firebase-key.json should NOT be committed
- Use environment variables in production
- Keep firebase-key.json in .gitignore

## Running the Full Stack

```bash
# Terminal 1: Backend
cd backend
java -jar target/campus-mart-backend-2.0.0.jar

# Terminal 2: Frontend
cd frontend
npm start

# Terminal 3: Flutter (if needed)
cd flutter_app
flutter run
```

Backend: http://localhost:8081
Frontend: http://localhost:3000

## Database

- Host: localhost
- Port: 3306
- Database: campus_mart
- User: root
- Password: Use your local MySQL password

## Troubleshooting

### Frontend 401 Errors
- Ensure backend is running on port 8081
- Check REACT_APP_API_URL is correct
- Clear browser cache and localStorage

### Backend Connection Errors
- Verify MySQL is running
- Check database credentials in application.properties
- Ensure port 8081 is not in use

### WebSocket Issues
- Check WS_SOCKET_HOST and WS_SOCKET_PORT in frontend
- Verify WebSocket is not blocked by firewall
- Check browser console for connection errors
