import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/device_info.dart';
import '../models/user.dart';
import '../config/app_config.dart';

class ChallengeService {
  ChallengeService();

  final Logger _logger = Logger();
  static const String _secretKey = 'your-super-secret-key-change-in-production';
  static const Duration _challengeTimeout = Duration(seconds: 15);

  // Generate secure challenge code
  String generateChallengeCode() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // Generate nonce for replay attack prevention
  String generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // Create challenge data for session
  ChallengeData createChallenge({
    required String sessionId,
    required String instructorId,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return ChallengeData(
      sessionId: sessionId,
      challengeCode: generateChallengeCode(),
      nonce: generateNonce(),
      issuedAt: now,
      expiresAt: now.add(_challengeTimeout),
      instructorId: instructorId,
      metadata: metadata ?? {},
    );
  }

  // Student signs challenge response
  String signChallengeResponse({
    required String challengeCode,
    required String nonce,
    required String studentId,
    required String deviceId,
    required String sessionId,
    Map<String, dynamic>? additionalData,
  }) {
    try {
      final payload = {
        'challengeCode': challengeCode,
        'nonce': nonce,
        'studentId': studentId,
        'deviceId': deviceId,
        'sessionId': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'additionalData': additionalData ?? {},
      };

      // Create HMAC signature
      final hmacKey = utf8.encode(_secretKey);
      final payloadBytes = utf8.encode(jsonEncode(payload));
      final hmac = Hmac(sha256, hmacKey);
      final digest = hmac.convert(payloadBytes);

      final signedResponse = {
        'payload': payload,
        'signature': digest.toString(),
      };

      return base64Url.encode(utf8.encode(jsonEncode(signedResponse)));
    } catch (e) {
      _logger.e('Error signing challenge response: $e');
      rethrow;
    }
  }

  // Verify challenge response (instructor side)
  ChallengeVerificationResult verifyChallengeResponse({
    required String signedResponse,
    required ChallengeData originalChallenge,
    required double rssi,
    Position? studentLocation,
    List<String>? wifiNetworks,
  }) {
    try {
      // Decode signed response
      final decodedBytes = base64Url.decode(signedResponse);
      final responseData = jsonDecode(utf8.decode(decodedBytes)) as Map<String, dynamic>;
      
      final payload = responseData['payload'] as Map<String, dynamic>;
      final signature = responseData['signature'] as String;

      // Verify signature
      final hmacKey = utf8.encode(_secretKey);
      final payloadBytes = utf8.encode(jsonEncode(payload));
      final hmac = Hmac(sha256, hmacKey);
      final expectedDigest = hmac.convert(payloadBytes);

      if (signature != expectedDigest.toString()) {
        return ChallengeVerificationResult(
          isValid: false,
          errorReason: 'Invalid signature',
          flags: const AntiProxyFlags(invalidChallenge: true),
        );
      }

      // Verify challenge code matches
      if (payload['challengeCode'] != originalChallenge.challengeCode) {
        return ChallengeVerificationResult(
          isValid: false,
          errorReason: 'Challenge code mismatch',
          flags: const AntiProxyFlags(invalidChallenge: true),
        );
      }

      // Verify nonce matches
      if (payload['nonce'] != originalChallenge.nonce) {
        return ChallengeVerificationResult(
          isValid: false,
          errorReason: 'Nonce mismatch',
          flags: const AntiProxyFlags(invalidChallenge: true),
        );
      }

      // Check timestamp (response timing)
      final responseTimestamp = payload['timestamp'] as int;
      final responseTime = DateTime.fromMillisecondsSinceEpoch(responseTimestamp);
      final responseLatency = responseTime.difference(originalChallenge.issuedAt);

      // Check if response is within time window
      if (responseTime.isAfter(originalChallenge.expiresAt)) {
        return ChallengeVerificationResult(
          isValid: false,
          errorReason: 'Response timeout',
          flags: const AntiProxyFlags(lateResponse: true),
        );
      }

      // Perform anti-proxy checks
      final antiProxyFlags = _performAntiProxyChecks(
        rssi: rssi,
        responseLatency: responseLatency,
        studentLocation: studentLocation,
        wifiNetworks: wifiNetworks,
        payload: payload,
      );

      final hasFlags = _hasAntiProxyFlags(antiProxyFlags);

      return ChallengeVerificationResult(
        isValid: !hasFlags,
        studentId: payload['studentId'] as String,
        deviceId: payload['deviceId'] as String,
        responseLatency: responseLatency,
        flags: antiProxyFlags,
        errorReason: hasFlags ? 'Anti-proxy flags detected' : null,
        additionalData: payload['additionalData'] as Map<String, dynamic>?,
      );

    } catch (e) {
      _logger.e('Error verifying challenge response: $e');
      return ChallengeVerificationResult(
        isValid: false,
        errorReason: 'Verification error: $e',
        flags: const AntiProxyFlags(invalidChallenge: true),
      );
    }
  }

  // Perform comprehensive anti-proxy checks
  AntiProxyFlags _performAntiProxyChecks({
    required double rssi,
    required Duration responseLatency,
    Position? studentLocation,
    List<String>? wifiNetworks,
    required Map<String, dynamic> payload,
  }) {
    final flags = AntiProxyFlags();
    final details = <String, dynamic>{};

    // RSSI check (weak signal indicates distance)
    const double rssiThreshold = -70.0; // Adjust based on classroom size
    if (rssi < rssiThreshold) {
      flags = flags.copyWith(weakSignal: true);
      details['rssi'] = rssi;
      details['rssiThreshold'] = rssiThreshold;
    }

    // Response latency check (too fast might indicate automation)
    const Duration minResponseTime = Duration(milliseconds: 500);
    const Duration maxResponseTime = Duration(seconds: 10);
    
    if (responseLatency < minResponseTime || responseLatency > maxResponseTime) {
      flags = flags.copyWith(lateResponse: true);
      details['responseLatency'] = responseLatency.inMilliseconds;
    }

    // Location consistency check
    if (studentLocation != null) {
      // Check if location is reasonable (not obviously mocked)
      if (_isLocationSuspicious(studentLocation)) {
        flags = flags.copyWith(invalidLocation: true, mockedLocation: true);
        details['suspiciousLocation'] = {
          'lat': studentLocation.latitude,
          'lng': studentLocation.longitude,
          'accuracy': studentLocation.accuracy,
        };
      }
    }

    // WiFi environment check
    if (wifiNetworks != null && wifiNetworks.isNotEmpty) {
      if (_areWifiNetworksSuspicious(wifiNetworks)) {
        flags = flags.copyWith(suspiciousWifi: true);
        details['wifiNetworks'] = wifiNetworks;
      }
    }

    // Device consistency check
    final deviceId = payload['deviceId'] as String?;
    if (deviceId != null) {
      // In a real implementation, you would check against known device patterns
      if (_isDeviceIdSuspicious(deviceId)) {
        flags = flags.copyWith(duplicateDevice: true);
        details['deviceId'] = deviceId;
      }
    }

    return flags.copyWith(details: details);
  }

  bool _hasAntiProxyFlags(AntiProxyFlags flags) {
    return flags.weakSignal ||
        flags.duplicateDevice ||
        flags.invalidLocation ||
        flags.suspiciousWifi ||
        flags.lateResponse ||
        flags.invalidChallenge ||
        flags.rootedDevice ||
        flags.mockedLocation ||
        flags.unusualPattern;
  }

  bool _isLocationSuspicious(Position location) {
    // Check for obviously fake coordinates (0,0), exact duplicates, etc.
    if (location.latitude == 0.0 && location.longitude == 0.0) return true;
    
    // Check for unrealistic accuracy
    if (location.accuracy != null && location.accuracy! < 1.0) return true;
    
    // Add more sophisticated location analysis here
    return false;
  }

  bool _areWifiNetworksSuspicious(List<String> networks) {
    // Check for known suspicious patterns
    const suspiciousNetworks = ['MOCK_WIFI', 'TEST_AP', 'FAKE_NETWORK'];
    
    for (final network in networks) {
      if (suspiciousNetworks.contains(network.toUpperCase())) {
        return true;
      }
    }
    
    // Check for too many or too few networks
    if (networks.length < 1 || networks.length > 20) {
      return true;
    }
    
    return false;
  }

  bool _isDeviceIdSuspicious(String deviceId) {
    // Check for patterns indicating emulation or spoofing
    const suspiciousPatterns = ['EMULATOR', 'SIMULATOR', 'GENERIC'];
    
    final upperDeviceId = deviceId.toUpperCase();
    for (final pattern in suspiciousPatterns) {
      if (upperDeviceId.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }

  // Generate JWT token for additional security
  String generateJwtToken({
    required String studentId,
    required String sessionId,
    Map<String, dynamic>? claims,
  }) {
    final jwt = JWT({
      'studentId': studentId,
      'sessionId': sessionId,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      ...?claims,
    });

    return jwt.sign(SecretKey(_secretKey));
  }

  bool verifyJwtToken(String token) {
    try {
      JWT.verify(token, SecretKey(_secretKey));
      return true;
    } catch (e) {
      _logger.w('JWT verification failed: $e');
      return false;
    }
  }
}

@freezed
class ChallengeVerificationResult with _$ChallengeVerificationResult {
  const factory ChallengeVerificationResult({
    required bool isValid,
    String? studentId,
    String? deviceId,
    Duration? responseLatency,
    required AntiProxyFlags flags,
    String? errorReason,
    Map<String, dynamic>? additionalData,
  }) = _ChallengeVerificationResult;
}

// Provider
final challengeServiceProvider = Provider<ChallengeService>((ref) {
  return ChallengeService();
});