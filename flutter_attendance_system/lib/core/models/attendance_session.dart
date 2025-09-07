import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';

part 'attendance_session.freezed.dart';
part 'attendance_session.g.dart';

@freezed
class AttendanceSession with _$AttendanceSession {
  const factory AttendanceSession({
    required String id,
    required String instructorId,
    required String classId,
    required String className,
    required String subject,
    required DateTime startTime,
    required DateTime endTime,
    required GeofenceData geofence,
    required int timeWindowMinutes,
    required String challengeCode,
    required SessionStatus status,
    @Default([]) List<String> detectedStudentIds,
    @Default([]) List<AttendanceRecord> attendanceRecords,
    @Default({}) Map<String, dynamic> metadata,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _AttendanceSession;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) =>
      _$AttendanceSessionFromJson(json);
}

@freezed
class GeofenceData with _$GeofenceData {
  const factory GeofenceData({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    String? locationName,
    String? buildingName,
    String? roomNumber,
  }) = _GeofenceData;

  factory GeofenceData.fromJson(Map<String, dynamic> json) =>
      _$GeofenceDataFromJson(json);
}

@freezed
class AttendanceRecord with _$AttendanceRecord {
  const factory AttendanceRecord({
    required String studentId,
    required String sessionId,
    required AttendanceStatus status,
    required DateTime timestamp,
    double? rssi,
    Position? gpsLocation,
    List<String>? wifiNetworks,
    String? challengeResponse,
    bool? faceVerified,
    String? faceToken,
    @Default({}) Map<String, dynamic> antiProxyData,
    List<String>? suspiciousFlags,
    bool? manualOverride,
    String? overrideReason,
    String? overrideByUserId,
  }) = _AttendanceRecord;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      _$AttendanceRecordFromJson(json);
}

@JsonEnum()
enum SessionStatus {
  @JsonValue('created')
  created,
  @JsonValue('active')
  active,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

@JsonEnum()
enum AttendanceStatus {
  @JsonValue('present')
  present,
  @JsonValue('absent')
  absent,
  @JsonValue('late')
  late,
  @JsonValue('flagged')
  flagged,
  @JsonValue('pending')
  pending,
}

extension SessionStatusX on SessionStatus {
  String get displayName {
    switch (this) {
      case SessionStatus.created:
        return 'Created';
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.cancelled:
        return 'Cancelled';
    }
  }
  
  bool get isActive => this == SessionStatus.active;
  bool get isCompleted => this == SessionStatus.completed;
}

extension AttendanceStatusX on AttendanceStatus {
  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.flagged:
        return 'Flagged';
      case AttendanceStatus.pending:
        return 'Pending';
    }
  }
  
  bool get isPresent => this == AttendanceStatus.present;
  bool get isFlagged => this == AttendanceStatus.flagged;
}