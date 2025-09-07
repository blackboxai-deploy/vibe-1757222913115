# 🚀 Setup Guide: Flutter Bluetooth Attendance System

This comprehensive guide will help you set up the complete Flutter Bluetooth Student Attendance System with anti-proxy features.

## 📋 Prerequisites

### Required Software

1. **Flutter SDK** (version ≥3.16.0)
   ```bash
   # Install Flutter
   git clone https://github.com/flutter/flutter.git -b stable
   export PATH="$PATH:`pwd`/flutter/bin"
   flutter doctor
   ```

2. **Node.js** (version ≥16.0.0)
   ```bash
   # Using nvm (recommended)
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
   nvm install 18
   nvm use 18
   ```

3. **Firebase CLI**
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

4. **Development Tools**
   - **Android Studio** (for Android development)
   - **Xcode** (for iOS development, macOS only)
   - **VS Code** with Flutter and Dart extensions
   - **Redis Server** (for backend caching)

### Hardware Requirements

- **For BLE Testing**: Physical Android/iOS devices (BLE doesn't work in emulators)
- **Minimum Android**: API Level 21 (Android 5.0)
- **Minimum iOS**: iOS 10.0
- **Development Machine**: 8GB RAM, 50GB storage

## 🔥 Firebase Setup

### 1. Create Firebase Project

```bash
# Create new Firebase project
firebase projects:create attendance-system-2024

# Or use existing project
firebase use your-existing-project-id
```

### 2. Enable Required Services

1. **Authentication**
   - Go to Firebase Console → Authentication
   - Enable Email/Password provider
   - (Optional) Enable Google Sign-In

2. **Firestore Database**
   - Go to Firebase Console → Firestore Database
   - Create database in production mode
   - Choose your preferred region

3. **Firebase Storage** (Optional)
   - For user profile images and reports
   - Enable in Firebase Console

### 3. Configure Security Rules

**Firestore Rules** (`firestore.rules`):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to get user role
    function getUserRole(uid) {
      return get(/databases/$(database)/documents/users/$(uid)).data.role;
    }
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(uid) {
      return request.auth.uid == uid;
    }
    
    function isInstructor() {
      return isAuthenticated() && getUserRole(request.auth.uid) == 'instructor';
    }
    
    function isAdmin() {
      return isAuthenticated() && getUserRole(request.auth.uid) == 'admin';
    }

    // Users collection
    match /users/{userId} {
      allow read: if isOwner(userId) || isAdmin();
      allow write: if isOwner(userId) || isAdmin();
      allow create: if isAuthenticated();
    }
    
    // Attendance sessions
    match /attendance_sessions/{sessionId} {
      allow read: if isAuthenticated();
      allow create: if isInstructor() || isAdmin();
      allow update: if isInstructor() || isAdmin() || 
        (isAuthenticated() && request.auth.uid == resource.data.instructorId);
      allow delete: if isAdmin();
    }
    
    // Attendance records
    match /attendance_records/{recordId} {
      allow read: if isAuthenticated() && 
        (isOwner(resource.data.studentId) || 
         isInstructor() || 
         isAdmin());
      allow create: if isAuthenticated() && 
        isOwner(request.resource.data.studentId);
      allow update: if isInstructor() || isAdmin();
      allow delete: if isAdmin();
    }
    
    // Device information
    match /devices/{deviceId} {
      allow read: if isAuthenticated() && 
        (isOwner(resource.data.userId) || isAdmin());
      allow create, update: if isAuthenticated() && 
        isOwner(request.resource.data.userId);
      allow delete: if isAdmin();
    }
    
    // Challenge data (temporary)
    match /challenges/{sessionId} {
      allow read, write: if isInstructor() || isAdmin();
    }
  }
}
```

### 4. Create Firestore Indexes

```json
{
  "indexes": [
    {
      "collectionGroup": "attendance_sessions",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "instructorId", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "attendance_records", 
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "sessionId", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "attendance_records",
      "queryScope": "COLLECTION", 
      "fields": [
        {"fieldPath": "studentId", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    }
  ]
}
```

## 📱 Flutter App Setup

### 1. Configure Firebase for Flutter

```bash
cd flutter_attendance_system

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

This will create `lib/firebase_options.dart` with your project configuration.

### 2. Install Dependencies

```bash
# Get Flutter dependencies
flutter pub get

# Generate code for models
dart run build_runner build --delete-conflicting-outputs
```

### 3. Configure Platform-Specific Settings

#### Android Configuration (`android/app/build.gradle`):
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21  // Required for BLE
        targetSdkVersion 34
        
        // Add these permissions in AndroidManifest.xml
    }
}
```

#### Android Permissions (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />

<!-- BLE feature requirement -->
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

#### iOS Configuration (`ios/Runner/Info.plist`):
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to detect nearby students for attendance tracking</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to broadcast student presence for attendance</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses location to verify student presence in classroom</string>
<key>NSCameraUsageDescription</key>
<string>This app uses camera for optional face verification</string>
```

### 4. Test Flutter Installation

```bash
# Check for any issues
flutter doctor -v

# Run on connected device
flutter run
```

## 🖥️ Backend API Setup

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Environment Configuration

Create `.env` file:
```env
# Environment
NODE_ENV=development
PORT=5000

# Client URL (for CORS)
CLIENT_URL=http://localhost:3000

# Firebase Admin SDK
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nyour-private-key\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com

# Redis Configuration
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=
REDIS_DB=0

# Security Keys
JWT_SECRET=your-super-secret-jwt-key-change-in-production
CHALLENGE_SECRET=your-challenge-response-secret-key

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000  # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100
CHALLENGE_RATE_LIMIT_MAX=10

# Logging
LOG_LEVEL=info
LOG_FILE=logs/app.log

# WebSocket
WS_PORT=5001
```

### 3. Firebase Service Account

1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate new private key
3. Download JSON file
4. Extract the required values for `.env`

### 4. Redis Setup

#### Local Redis:
```bash
# Install Redis (macOS)
brew install redis
brew services start redis

# Install Redis (Ubuntu)
sudo apt update
sudo apt install redis-server
sudo systemctl start redis-server

# Test Redis connection
redis-cli ping
```

#### Redis Cloud (Recommended for production):
1. Sign up at [Redis Cloud](https://redis.com/try-free/)
2. Create new database
3. Copy connection URL to `REDIS_URL`

### 5. Start Backend Server

```bash
# Development mode
npm run dev

# Production mode
npm run build
npm start

# Test API health
curl http://localhost:5000/health
```

## 🌐 Admin Dashboard Setup

### 1. Install Dependencies

```bash
cd admin-dashboard
npm install
```

### 2. Environment Configuration

Create `.env.local`:
```env
# Firebase Configuration
NEXT_PUBLIC_FIREBASE_API_KEY=your-web-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-project-id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your-project.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123456789:web:abcdef

# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:5000/api
NEXT_PUBLIC_WS_URL=ws://localhost:5001

# App Configuration
NEXT_PUBLIC_APP_NAME=Attendance Admin Dashboard
NEXT_PUBLIC_APP_VERSION=1.0.0
```

### 3. Start Development Server

```bash
# Development mode
npm run dev

# Production build
npm run build
npm start

# Open browser
open http://localhost:3000
```

## 🔧 Testing Setup

### 1. Unit Tests

```bash
# Flutter tests
cd flutter_attendance_system
flutter test

# Backend tests
cd backend
npm test

# Frontend tests
cd admin-dashboard
npm test
```

### 2. BLE Testing Requirements

**Important**: BLE functionality requires physical devices. Emulators don't support Bluetooth.

1. **Two Physical Devices**: One for instructor app, one for student app
2. **Same Network**: Both devices should be on same WiFi for testing
3. **Proximity**: Keep devices within 10-30 meters for testing
4. **Permissions**: Ensure all Bluetooth permissions are granted

### 3. Test User Creation

Create test users in Firebase Console:

```javascript
// Instructor account
{
  email: "instructor@test.com",
  password: "test123456",
  role: "instructor"
}

// Student account  
{
  email: "student@test.com",
  password: "test123456", 
  role: "student"
}

// Admin account
{
  email: "admin@test.com",
  password: "test123456",
  role: "admin" 
}
```

## 🚀 Production Deployment

### 1. Mobile App Deployment

#### Android:
```bash
cd flutter_attendance_system

# Build release APK
flutter build apk --release

# Build app bundle for Play Store
flutter build appbundle --release
```

#### iOS:
```bash
# Build for iOS
flutter build ios --release

# Open in Xcode for App Store submission
open ios/Runner.xcworkspace
```

### 2. Backend Deployment

#### Google Cloud Run:
```bash
# Create Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production
COPY dist ./dist
EXPOSE 5000
CMD ["npm", "start"]

# Deploy to Cloud Run
gcloud run deploy attendance-backend \
  --source . \
  --port 5000 \
  --allow-unauthenticated
```

#### Railway/Heroku:
```bash
# Add Procfile
echo "web: npm start" > Procfile

# Deploy
railway login
railway link
railway up
```

### 3. Admin Dashboard Deployment

#### Vercel:
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel --prod
```

#### Netlify:
```bash
# Build and deploy
npm run build
netlify deploy --prod --dir=.next
```

## 🔒 Security Checklist

- [ ] Change all default passwords and secrets
- [ ] Enable Firebase App Check (recommended)
- [ ] Set up proper CORS policies
- [ ] Enable rate limiting in production
- [ ] Use HTTPS in production
- [ ] Set up monitoring and alerting
- [ ] Regular security updates
- [ ] Backup database regularly

## 🐛 Troubleshooting

### Common Issues

1. **BLE Not Working**
   - Ensure physical devices (not emulators)
   - Check Bluetooth permissions
   - Verify Android API level ≥21

2. **Firebase Connection Issues**
   - Verify `firebase_options.dart` configuration
   - Check internet connectivity
   - Ensure Firebase project is active

3. **Backend API Errors**
   - Check Redis connection
   - Verify environment variables
   - Review server logs

4. **Build Failures**
   - Clean and rebuild: `flutter clean && flutter pub get`
   - Update dependencies: `flutter pub upgrade`
   - Check platform-specific configurations

## 📞 Support

For additional help:

1. **Documentation**: Check project README and documentation
2. **Issues**: Report bugs on GitHub Issues
3. **Community**: Join Discord/Slack for community support
4. **Email**: Contact support team

---

**Setup complete! 🎉 Your Flutter Bluetooth Attendance System is ready for development and testing.**