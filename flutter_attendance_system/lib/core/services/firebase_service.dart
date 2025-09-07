import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/user.dart';
import '../models/attendance_session.dart';
import '../models/device_info.dart';

class FirebaseService {
  FirebaseService() {
    _initialize();
  }

  final Logger _logger = Logger();
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<auth.User?>? _authStateSubscription;
  
  // Collections
  static const String usersCollection = 'users';
  static const String sessionsCollection = 'attendance_sessions';
  static const String recordsCollection = 'attendance_records';
  static const String devicesCollection = 'devices';
  static const String challengesCollection = 'challenges';

  void _initialize() {
    // Enable offline persistence
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Authentication Methods
  Stream<auth.User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        return await getUserProfile(credential.user!.uid);
      }
      return null;
    } on auth.FirebaseAuthException catch (e) {
      _logger.e('Sign in error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    }
  }

  Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String institutionId,
    String? studentId,
    String? employeeId,
    String? department,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = User(
          id: credential.user!.uid,
          email: email,
          name: name,
          role: role,
          institutionId: institutionId,
          studentId: studentId,
          employeeId: employeeId,
          department: department,
          createdAt: DateTime.now(),
        );

        await _createUserProfile(user);
        return user;
      }
      return null;
    } on auth.FirebaseAuthException catch (e) {
      _logger.e('Create user error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      _logger.e('Sign out error: $e');
      rethrow;
    }
  }

  Future<void> _createUserProfile(User user) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(user.id)
          .set(user.toJson());
    } catch (e) {
      _logger.e('Error creating user profile: $e');
      rethrow;
    }
  }

  Future<User?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return User.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting user profile: $e');
      return null;
    }
  }

  Stream<User?> getUserProfileStream(String userId) {
    return _firestore
        .collection(usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return User.fromJson(doc.data()!);
      }
      return null;
    });
  }

  // Device Management
  Future<void> bindDeviceToUser(String userId, DeviceInfo deviceInfo) async {
    try {
      // First, unbind any existing devices for this user
      final existingDevices = await _firestore
          .collection(devicesCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in existingDevices.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // Add new device binding
      final deviceRef = _firestore.collection(devicesCollection).doc();
      batch.set(deviceRef, deviceInfo.toJson());

      // Update user profile with device info
      final userRef = _firestore.collection(usersCollection).doc(userId);
      batch.update(userRef, {
        'boundDeviceId': deviceInfo.deviceId,
        'deviceFingerprint': deviceInfo.deviceFingerprint,
        'bleUuid': deviceInfo.bleUuid,
      });

      await batch.commit();
      _logger.i('Device bound to user: $userId');
    } catch (e) {
      _logger.e('Error binding device: $e');
      rethrow;
    }
  }

  // Session Management
  Future<String> createAttendanceSession(AttendanceSession session) async {
    try {
      final docRef = await _firestore
          .collection(sessionsCollection)
          .add(session.toJson());
      
      _logger.i('Created attendance session: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Error creating session: $e');
      rethrow;
    }
  }

  Future<void> updateAttendanceSession(String sessionId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection(sessionsCollection)
          .doc(sessionId)
          .update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error updating session: $e');
      rethrow;
    }
  }

  Stream<AttendanceSession?> getAttendanceSessionStream(String sessionId) {
    return _firestore
        .collection(sessionsCollection)
        .doc(sessionId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return AttendanceSession.fromJson(doc.data()!);
      }
      return null;
    });
  }

  Stream<List<AttendanceSession>> getInstructorSessionsStream(String instructorId) {
    return _firestore
        .collection(sessionsCollection)
        .where('instructorId', isEqualTo: instructorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceSession.fromJson(doc.data()))
          .toList();
    });
  }

  // Attendance Records
  Future<void> markAttendance(AttendanceRecord record) async {
    try {
      await _firestore
          .collection(recordsCollection)
          .add(record.toJson());
      
      // Update session with attendance count
      await updateAttendanceSession(record.sessionId, {
        'attendanceRecords': FieldValue.arrayUnion([record.studentId]),
      });

      _logger.i('Marked attendance for student: ${record.studentId}');
    } catch (e) {
      _logger.e('Error marking attendance: $e');
      rethrow;
    }
  }

  Stream<List<AttendanceRecord>> getSessionAttendanceStream(String sessionId) {
    return _firestore
        .collection(recordsCollection)
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceRecord.fromJson(doc.data()))
          .toList();
    });
  }

  Stream<List<AttendanceRecord>> getStudentAttendanceStream(String studentId) {
    return _firestore
        .collection(recordsCollection)
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceRecord.fromJson(doc.data()))
          .toList();
    });
  }

  // Challenge Management
  Future<void> storeChallengeData(ChallengeData challenge) async {
    try {
      await _firestore
          .collection(challengesCollection)
          .doc(challenge.sessionId)
          .set(challenge.toJson());
    } catch (e) {
      _logger.e('Error storing challenge: $e');
      rethrow;
    }
  }

  Future<ChallengeData?> getChallengeData(String sessionId) async {
    try {
      final doc = await _firestore
          .collection(challengesCollection)
          .doc(sessionId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ChallengeData.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting challenge: $e');
      return null;
    }
  }

  // Analytics and Reporting
  Future<Map<String, dynamic>> getAttendanceAnalytics({
    required String instructorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(recordsCollection)
          .where('instructorId', isEqualTo: instructorId);

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final records = snapshot.docs
          .map((doc) => AttendanceRecord.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Calculate analytics
      final totalRecords = records.length;
      final presentCount = records.where((r) => r.status.isPresent).length;
      final flaggedCount = records.where((r) => r.status.isFlagged).length;

      return {
        'totalRecords': totalRecords,
        'presentCount': presentCount,
        'absentCount': totalRecords - presentCount,
        'flaggedCount': flaggedCount,
        'attendanceRate': totalRecords > 0 ? (presentCount / totalRecords * 100) : 0.0,
      };
    } catch (e) {
      _logger.e('Error getting analytics: $e');
      return {};
    }
  }

  String _handleAuthException(auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}

// Providers
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final authStateProvider = StreamProvider<auth.User?>((ref) {
  return ref.watch(firebaseServiceProvider).authStateChanges;
});

final currentUserProvider = StreamProvider<User?>((ref) {
  final authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) return Stream.value(null);
  
  return ref.watch(firebaseServiceProvider).getUserProfileStream(authUser.uid);
});