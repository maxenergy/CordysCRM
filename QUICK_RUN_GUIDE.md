# Quick Run Guide - CordysCRM

## 🚀 Quick Start (One Command)

```bash
# Start everything (databases, backend, flutter)
./scripts/start_backend_and_flutter.sh
```

## 📋 Step-by-Step Manual Start

### 1. Start Databases (Required First)

```bash
./scripts/start_databases.sh
```

**Verify:**
```bash
docker ps | grep cordys
# Should show: cordys-mysql and cordys-redis running
```

### 2. Compile and Start Backend

```bash
cd backend
../mvnw clean compile -DskipTests
../mvnw spring-boot:run -pl app -DskipTests
```

**Verify:**
```bash
curl http://localhost:8081/
# Should return HTTP 200
```

**Backend URL:** http://localhost:8081

### 3. Run Flutter App

#### Option A: Physical Android Device (Recommended)
```bash
cd mobile/cordyscrm_flutter
flutter pub get
flutter devices  # Find your device ID
flutter run -d <device_id>
```

#### Option B: Android Emulator
```bash
cd mobile/cordyscrm_flutter
flutter emulators  # List available emulators
flutter emulators --launch Fast_Phone_API36
# Wait 30 seconds for emulator to start
flutter run -d emulator-5554
```

#### Option C: Linux Desktop (May have issues)
```bash
cd mobile/cordyscrm_flutter
flutter run -d linux
```

## 🔥 Development Workflow

### Hot Reload (Flutter)
While Flutter app is running:
- Press `r` - Hot reload (fast, preserves state)
- Press `R` - Hot restart (full restart)
- Press `h` - Show all commands

### Backend Changes
Backend auto-reloads with Spring Boot DevTools (if configured).
Otherwise, restart:
```bash
# Stop with Ctrl+C, then:
cd backend
../mvnw spring-boot:run -pl app -DskipTests
```

## 🛠️ Useful Commands

### Check Running Services
```bash
# Backend
curl http://localhost:8081/

# Databases
docker ps | grep cordys

# Flutter processes
flutter devices
```

### View Logs
```bash
# Backend logs (if running in background)
tail -f logs/cordys-crm.log

# Flutter logs
flutter logs
```

### Clean Build
```bash
# Backend
cd backend
../mvnw clean

# Flutter
cd mobile/cordyscrm_flutter
flutter clean
flutter pub get
```

## 🐛 Troubleshooting

### Backend Won't Start
```bash
# Check if port 8081 is in use
lsof -i :8081
# Kill process if needed
kill -9 <PID>

# Check databases are running
docker ps | grep cordys
./scripts/start_databases.sh
```

### Flutter Build Fails
```bash
cd mobile/cordyscrm_flutter
flutter clean
flutter pub get
flutter doctor  # Check for issues
```

### Database Connection Issues
```bash
# Restart databases
docker restart cordys-mysql cordys-redis

# Check logs
docker logs cordys-mysql
docker logs cordys-redis
```

## 📱 Device-Specific Notes

### Physical Android Device
1. Enable USB debugging on device
2. Connect via USB
3. Accept debugging prompt on device
4. Run `flutter devices` to verify connection

### Android Emulator
- Requires Android Studio or Android SDK
- Emulator takes 30-60 seconds to start
- Use Fast_Phone_API36 for best performance

### Linux Desktop
- May have GLib issues on some systems
- Use Android device/emulator as alternative
- Check `flutter doctor` for missing dependencies

## 🔧 Configuration

### Backend Configuration
- **File:** `backend/app/src/main/resources/application.yml`
- **Port:** 8081 (default)
- **Database:** MySQL on localhost:3306
- **Redis:** localhost:6379

### Flutter Configuration
- **File:** `mobile/cordyscrm_flutter/lib/core/config/app_config.dart`
- **API Base URL:** Configure to point to backend

## 📊 Current Status

Run this to check current status:
```bash
# Backend
curl -s -o /dev/null -w "Backend: %{http_code}\n" http://localhost:8081/

# Databases
docker ps --format "{{.Names}}: {{.Status}}" | grep cordys

# Flutter
flutter devices
```

## 🛑 Stop All Services

```bash
# Stop Flutter (press 'q' in Flutter terminal)

# Stop Backend (Ctrl+C in backend terminal)

# Stop Databases (optional, can keep running)
docker stop cordys-mysql cordys-redis
```

## 📚 Additional Resources

- **Backend API Docs:** http://localhost:8081/swagger-ui.html (if configured)
- **Flutter DevTools:** Shown in Flutter terminal when app runs
- **Project Docs:** See README.md files in each directory

---

**Quick Health Check:**
```bash
# All in one
echo "=== Backend ===" && curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8081/ && \
echo "=== Databases ===" && docker ps --format "{{.Names}}: {{.Status}}" | grep cordys && \
echo "=== Flutter Devices ===" && cd mobile/cordyscrm_flutter && flutter devices
```
