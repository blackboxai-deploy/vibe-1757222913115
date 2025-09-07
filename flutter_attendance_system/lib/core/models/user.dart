import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String name,
    required UserRole role,
    required String institutionId,
    String? profileImageUrl,
    String? phoneNumber,
    required DateTime createdAt,
    DateTime? lastLoginAt,
    @Default(true) bool isActive,
    
    // Student-specific fields
    String? studentId,
    String? department,
    String? year,
    
    // Instructor-specific fields
    String? employeeId,
    List<String>? subjectIds,
    
    // Device binding for anti-proxy
    String? boundDeviceId,
    String? deviceFingerprint,
    String? bleUuid,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@JsonEnum()
enum UserRole {
  @JsonValue('student')
  student,
  @JsonValue('instructor')
  instructor,
  @JsonValue('admin')
  admin,
}

extension UserRoleX on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.instructor:
        return 'Instructor';
      case UserRole.admin:
        return 'Administrator';
    }
  }
  
  bool get isStudent => this == UserRole.student;
  bool get isInstructor => this == UserRole.instructor;
  bool get isAdmin => this == UserRole.admin;
}