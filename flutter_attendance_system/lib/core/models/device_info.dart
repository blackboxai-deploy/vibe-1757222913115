import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_info.freezed.dart';
part 'device_info.g.dart';

@freezed
class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({
    required String deviceId,
    required String userId,
    required String platform,
    required String model,
    required String manufacturer,
    required String osVersion,
    required String appVersion,
    required String bleUuid,
    required String deviceFingerprint,
    required DateTime registeredAt,
    DateTime? lastSeenAt,
    @Default(true) bool isActive,
    @Default({}) Map<String, dynamic> hardwareInfo,
    @Default([]) List<String> securityFlags,
  }) = _DeviceInfo;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);
}

@freezed
class BleDevice with _$BleDevice {
  const factory BleDevice({
    required String deviceId,
    required String userId,
    required String name,
    required String bleUuid,
    required double rssi,
    required DateTime discoveredAt,
    @Default({}) Map<String, dynamic> advertisementData,
    Position? location,
    List<String>? wifiNetworks,
  }) = _BleDevice;

  factory BleDevice.fromJson(Map<String, dynamic> json) =>
      _$BleDeviceFromJson(json);
}

@freezed
class Position with _$Position {
  const factory Position({
    required double latitude,
    required double longitude,
    double? altitude,
    double? accuracy,
    required DateTime timestamp,
  }) = _Position;

  factory Position.fromJson(Map<String, dynamic> json) =>
      _$PositionFromJson(json);
}

@freezed
class ChallengeData with _$ChallengeData {
  const factory ChallengeData({
    required String sessionId,
    required String challengeCode,
    required String nonce,
    required DateTime issuedAt,
    required DateTime expiresAt,
    required String instructorId,
    @Default({}) Map<String, dynamic> metadata,
  }) = _ChallengeData;

  factory ChallengeData.fromJson(Map<String, dynamic> json) =>
      _$ChallengeDataFromJson(json);
}

@freezed
class ChallengeResponse with _$ChallengeResponse {
  const factory ChallengeResponse({
    required String sessionId,
    required String studentId,
    required String challengeCode,
    required String signedResponse,
    required DateTime respondedAt,
    double? rssi,
    Position? location,
    List<String>? wifiNetworks,
    String? faceToken,
    @Default({}) Map<String, dynamic> deviceContext,
  }) = _ChallengeResponse;

  factory ChallengeResponse.fromJson(Map<String, dynamic> json) =>
      _$ChallengeResponseFromJson(json);
}

@freezed
class AntiProxyFlags with _$AntiProxyFlags {
  const factory AntiProxyFlags({
    @Default(false) bool weakSignal,
    @Default(false) bool duplicateDevice,
    @Default(false) bool invalidLocation,
    @Default(false) bool suspiciousWifi,
    @Default(false) bool lateResponse,
    @Default(false) bool invalidChallenge,
    @Default(false) bool rootedDevice,
    @Default(false) bool mockedLocation,
    @Default(false) bool unusualPattern,
    @Default({}) Map<String, dynamic> details,
  }) = _AntiProxyFlags;

  factory AntiProxyFlags.fromJson(Map<String, dynamic> json) =>
      _$AntiProxyFlagsFromJson(json);
}