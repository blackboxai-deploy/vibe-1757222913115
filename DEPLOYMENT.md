# 🚀 Production Deployment Guide

This guide covers deploying the Flutter Bluetooth Student Attendance System to production environments.

## 📋 Pre-Deployment Checklist

### Security Requirements
- [ ] All environment variables configured with production values
- [ ] Default passwords and secrets changed
- [ ] Firebase security rules reviewed and tested
- [ ] API rate limiting configured
- [ ] HTTPS certificates ready
- [ ] Database backups configured

### Performance Requirements
- [ ] Redis cache properly configured
- [ ] Database indexes created
- [ ] Image optimization completed
- [ ] Bundle size optimized
- [ ] CDN configured for static assets

### Testing Requirements
- [ ] Unit tests passing
- [ ] Integration tests completed
- [ ] BLE functionality tested on multiple devices
- [ ] Security penetration testing completed
- [ ] Load testing performed

## 🌐 Infrastructure Architecture

### Recommended Production Stack

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Mobile Apps   │    │  Admin Dashboard│    │   Load Balancer │
│   (App Store)   │    │    (Vercel)     │    │   (CloudFlare)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Backend API    │
                    │ (Cloud Run)     │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Firebase      │    │   Redis Cloud   │    │   Monitoring    │
│ (Auth + DB)     │    │   (Caching)     │    │  (DataDog)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📱 Mobile App Deployment

### Android Deployment (Google Play Store)

#### 1. Build Configuration

**`android/app/build.gradle`:**
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.yourcompany.attendance_system"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        
        // Enable ProGuard
        minifyEnabled true
        useProguard true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            useProguard true
        }
    }
}
```

#### 2. Generate Signing Key

```bash
# Create keystore
keytool -genkey -v -keystore ~/attendance-system-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias attendance

# Create key.properties
echo "storePassword=your_store_password" > android/key.properties
echo "keyPassword=your_key_password" >> android/key.properties
echo "keyAlias=attendance" >> android/key.properties
echo "storeFile=../attendance-system-key.jks" >> android/key.properties
```

#### 3. Build Release APK/Bundle

```bash
# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Build APK
flutter build apk --release --split-per-abi
```

#### 4. Play Store Submission

1. **Create Play Console Account**
2. **Upload App Bundle** to Play Console
3. **Configure Store Listing**:
   - App name: "Smart Attendance System"
   - Description: Include BLE requirements and features
   - Screenshots: Include both instructor and student app views
   - Privacy Policy: Link to your privacy policy

4. **Content Rating**:
   - Educational category
   - No sensitive content

5. **App Permissions**:
   - Bluetooth: "Required for attendance detection"
   - Location: "Used to verify classroom presence"
   - Camera: "Optional face verification"

### iOS Deployment (App Store)

#### 1. Xcode Configuration

```bash
# Open iOS project
cd flutter_attendance_system
open ios/Runner.xcworkspace
```

#### 2. Configure Signing & Capabilities

1. **Team & Bundle Identifier**:
   - Select development team
   - Set unique bundle ID: `com.yourcompany.attendance-system`

2. **Capabilities**:
   - Background App Refresh
   - Bluetooth (Central & Peripheral)
   - Location Services

#### 3. Build for Release

```bash
# Build iOS release
flutter build ios --release

# Archive in Xcode
# Product → Archive → Upload to App Store Connect
```

#### 4. App Store Submission

1. **App Store Connect Setup**
2. **App Information**:
   - Primary Language: English
   - Category: Education
   - Content Rights: Use bluetooth for proximity detection

3. **Privacy Information**:
   - Data Collection: Bluetooth identifiers, location data
   - Usage: Educational attendance tracking only

## 🖥️ Backend API Deployment

### Google Cloud Run Deployment

#### 1. Prepare Docker Configuration

**`backend/Dockerfile`:**
```dockerfile
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy built application
COPY dist ./dist

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S backend -u 1001
USER backend

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

# Start application
CMD ["npm", "start"]
```

#### 2. Build and Deploy

```bash
cd backend

# Build TypeScript
npm run build

# Deploy to Cloud Run
gcloud run deploy attendance-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --port 5000 \
  --memory 1Gi \
  --cpu 1 \
  --max-instances 10 \
  --allow-unauthenticated \
  --set-env-vars NODE_ENV=production

# Set environment variables
gcloud run services update attendance-backend \
  --set-env-vars FIREBASE_PROJECT_ID=your-project-id \
  --set-env-vars REDIS_URL=your-redis-url \
  --set-env-vars JWT_SECRET=your-production-secret
```

#### 3. Custom Domain Setup

```bash
# Map custom domain
gcloud run domain-mappings create \
  --service attendance-backend \
  --domain api.your-domain.com \
  --region us-central1
```

### Alternative: Railway Deployment

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway link
railway up

# Set environment variables
railway variables set NODE_ENV=production
railway variables set FIREBASE_PROJECT_ID=your-project-id
```

## 🌐 Admin Dashboard Deployment

### Vercel Deployment

#### 1. Prepare Build Configuration

**`admin-dashboard/next.config.js`:**
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
  },
  images: {
    domains: ['firebasestorage.googleapis.com'],
  },
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL,
  },
  output: 'standalone',
}

module.exports = nextConfig
```

#### 2. Deploy to Vercel

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
cd admin-dashboard
vercel --prod

# Set environment variables in Vercel dashboard
# or via CLI:
vercel env add NEXT_PUBLIC_FIREBASE_API_KEY production
vercel env add NEXT_PUBLIC_API_URL production
```

#### 3. Custom Domain

```bash
# Add custom domain
vercel domains add dashboard.your-domain.com
vercel alias dashboard.your-domain.com
```

### Alternative: Netlify Deployment

```bash
# Build and deploy
npm run build
netlify deploy --prod --dir=out

# Or continuous deployment
# Connect GitHub repository in Netlify dashboard
```

## 🗄️ Database & Storage Setup

### Firebase Production Configuration

#### 1. Upgrade Firebase Plan

```bash
# Upgrade to Blaze plan for production
firebase projects:list
firebase use your-project-id
```

#### 2. Configure Production Security Rules

**Enhanced Firestore Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Rate limiting
    function rateLimited() {
      return request.time > resource.data.lastRequest + duration.value(1, 's');
    }
    
    // Enhanced user validation
    function isValidUser() {
      return request.auth != null && 
             request.auth.token.email_verified == true &&
             exists(/databases/$(database)/documents/users/$(request.auth.uid));
    }
    
    // Users collection
    match /users/{userId} {
      allow read, write: if isValidUser() && 
                          request.auth.uid == userId &&
                          rateLimited();
    }
    
    // Attendance sessions with enhanced security
    match /attendance_sessions/{sessionId} {
      allow read: if isValidUser();
      allow create: if isValidUser() && 
                    getUserRole(request.auth.uid) in ['instructor', 'admin'] &&
                    rateLimited();
      allow update: if isValidUser() && 
                    (request.auth.uid == resource.data.instructorId || 
                     getUserRole(request.auth.uid) == 'admin') &&
                    rateLimited();
    }
  }
}
```

#### 3. Set Up Backup Strategy

```bash
# Enable automatic backups
gcloud firestore databases create --location=us-central1
gcloud alpha firestore backups schedules create --location=us-central1
```

### Redis Production Setup

#### Redis Cloud Configuration

1. **Create Redis Cloud Account**
2. **Create Production Database**:
   - Memory: 1GB minimum
   - Replication: Enabled
   - Persistence: AOF enabled
   - Security: SSL/TLS enabled

3. **Configure Connection**:
```bash
# Set production Redis URL
REDIS_URL=rediss://default:password@redis-endpoint:port
```

## 🔒 Security Hardening

### SSL/TLS Configuration

#### 1. CloudFlare Setup

```bash
# Add domain to CloudFlare
# Enable SSL/TLS Full (strict)
# Enable HTTP Strict Transport Security (HSTS)
# Configure Web Application Firewall (WAF)
```

#### 2. API Security Headers

```javascript
// Add to backend server.js
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://api.your-domain.com"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
```

### Firebase Security

#### 1. Enable App Check

```bash
# Enable App Check for production
firebase projects:list
firebase use your-project-id
firebase appcheck:apps:add android com.yourcompany.attendance_system
firebase appcheck:apps:add ios com.yourcompany.attendance-system
```

#### 2. Configure API Keys Restrictions

1. **Android API Key**:
   - Restrict to Android apps
   - Add package name restriction
   - Add SHA-1 certificate fingerprints

2. **iOS API Key**:
   - Restrict to iOS apps
   - Add bundle ID restriction

3. **Web API Key**:
   - Restrict to specific domains
   - Add HTTP referrer restrictions

## 📊 Monitoring & Analytics

### Application Monitoring

#### 1. Google Cloud Monitoring

```bash
# Enable monitoring
gcloud services enable monitoring.googleapis.com
gcloud alpha monitoring dashboards create --config-from-file=dashboard.json
```

#### 2. Error Tracking

**Sentry Integration:**
```javascript
// Add to backend
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
});
```

### Performance Monitoring

#### 1. Firebase Performance

```dart
// Add to Flutter app
import 'package:firebase_performance/firebase_performance.dart';

final Trace customTrace = FirebasePerformance.instance.newTrace('attendance_session');
customTrace.start();
// ... attendance logic
customTrace.stop();
```

#### 2. Real User Monitoring

```javascript
// Add to admin dashboard
import { getAnalytics, logEvent } from 'firebase/analytics';

const analytics = getAnalytics();
logEvent(analytics, 'session_created', {
  session_type: 'bluetooth_attendance'
});
```

## 🔄 CI/CD Pipeline

### GitHub Actions

**`.github/workflows/deploy.yml`:**
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter test
      
  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build appbundle --release
      - uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.yourcompany.attendance_system
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          
  deploy-backend:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: google-github-actions/setup-gcloud@v0
      - run: gcloud run deploy attendance-backend --source .
```

## 📈 Performance Optimization

### Mobile App Optimization

1. **Bundle Size Reduction**:
```bash
flutter build appbundle --release --analyze-size
```

2. **Image Optimization**:
   - Use WebP format for images
   - Implement lazy loading
   - Compress assets

3. **Code Splitting**:
   - Use deferred imports
   - Lazy load features
   - Implement route-based splitting

### Backend Optimization

1. **Caching Strategy**:
   - Redis for session data
   - CDN for static assets
   - Database query caching

2. **Connection Pooling**:
   - Firebase connection optimization
   - Redis connection pooling

3. **Horizontal Scaling**:
   - Cloud Run auto-scaling
   - Load balancer configuration

## 🚦 Health Checks & Alerts

### Health Check Endpoints

```javascript
// Backend health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    services: {
      firebase: 'connected',
      redis: redisClient.connected ? 'connected' : 'disconnected'
    }
  });
});
```

### Alert Configuration

1. **CloudFlare Alerts**:
   - SSL certificate expiration
   - High error rates
   - DDoS attacks

2. **Firebase Alerts**:
   - Database usage thresholds
   - Authentication failures
   - Performance degradation

3. **Application Alerts**:
   - High anti-proxy flag rates
   - System downtime
   - Security incidents

## ✅ Post-Deployment Checklist

- [ ] All services are running and accessible
- [ ] SSL certificates are properly configured
- [ ] Monitoring and alerts are active
- [ ] Backup systems are working
- [ ] Performance metrics are within acceptable ranges
- [ ] Security scans show no critical vulnerabilities
- [ ] Load testing completed successfully
- [ ] Disaster recovery plan is documented
- [ ] Team is trained on production systems

## 🆘 Troubleshooting Production Issues

### Common Issues

1. **High Memory Usage**:
   - Check for memory leaks
   - Optimize database queries
   - Review caching strategy

2. **Slow Response Times**:
   - Add database indexes
   - Implement query optimization
   - Scale infrastructure

3. **Authentication Failures**:
   - Verify Firebase configuration
   - Check API key restrictions
   - Review security rules

4. **BLE Connectivity Issues**:
   - Check device permissions
   - Verify Bluetooth capabilities
   - Review proximity settings

### Emergency Response

1. **Service Outage**:
   - Check health endpoints
   - Review error logs
   - Activate backup systems

2. **Security Incident**:
   - Isolate affected systems
   - Review access logs
   - Notify security team

3. **Data Loss**:
   - Activate backup restoration
   - Assess data integrity
   - Communicate with users

---

**Production deployment complete! 🎉 Your Flutter Bluetooth Attendance System is now live and ready to serve users securely and efficiently.**