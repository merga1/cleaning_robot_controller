import 'package:equatable/equatable.dart';

enum UserRole {
  admin,
  operator,
  readOnly;

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'administrator':
      case 'admin':
        return UserRole.admin;
      case 'operator':
        return UserRole.operator;
      case 'readonly':
      case 'read_only':
      case 'auditor':
      default:
        return UserRole.readOnly;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.operator:
        return 'Operator';
      case UserRole.readOnly:
        return 'Read-Only Supervisor';
    }
  }

  bool get canControlRobots => this != UserRole.readOnly;
  bool get canManageUsers => this == UserRole.admin;
}

class User extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role.name,
      };

  @override
  List<Object?> get props => [id, email, fullName, role];
}

