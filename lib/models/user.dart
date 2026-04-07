class User {
  final String id;
  final int organizationId;
  final int currentOrganizationId;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final String? department;
  final String? jobTitle;
  final String? phone;
  final String? accessToken;
  final String? emailVerifiedAt;
  final String lastLogin;
  final String createdAt;
  final String updatedAt;
  final String token; // Token JWT armazenado localmente

  User({
    required this.id,
    required this.organizationId,
    required this.currentOrganizationId,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.department,
    this.jobTitle,
    this.phone,
    this.accessToken,
    this.emailVerifiedAt,
    required this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json, {String? token}) {
    return User(
      id: json['id'].toString(),
      organizationId: json['organizationId'] as int? ??
          json['organization_id'] as int? ??
          0,
      currentOrganizationId: json['currentOrganizationId'] as int? ??
          json['current_organization_id'] as int? ??
          0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      department: json['department'] as String?,
      jobTitle: json['jobTitle'] as String? ?? json['job_title'] as String?,
      phone: json['phone'] as String?,
      accessToken:
          json['accessToken'] as String? ?? json['access_token'] as String?,
      emailVerifiedAt: json['emailVerifiedAt'] as String? ??
          json['email_verified_at'] as String?,
      lastLogin: json['lastLogin'] as String? ??
          json['last_login'] as String? ??
          DateTime.now().toIso8601String(),
      createdAt: json['createdAt'] as String? ??
          json['created_at'] as String? ??
          DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] as String? ??
          json['updated_at'] as String? ??
          DateTime.now().toIso8601String(),
      token: token ?? json['token'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'currentOrganizationId': currentOrganizationId,
      'name': name,
      'email': email,
      'role': role,
      'isActive': isActive,
      'department': department,
      'jobTitle': jobTitle,
      'phone': phone,
      'accessToken': accessToken,
      'emailVerifiedAt': emailVerifiedAt,
      'lastLogin': lastLogin,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'token': token,
    };
  }

  User copyWith({
    String? id,
    int? organizationId,
    int? currentOrganizationId,
    String? name,
    String? email,
    String? role,
    bool? isActive,
    String? department,
    String? jobTitle,
    String? phone,
    String? accessToken,
    String? emailVerifiedAt,
    String? lastLogin,
    String? createdAt,
    String? updatedAt,
    String? token,
  }) {
    return User(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      currentOrganizationId:
          currentOrganizationId ?? this.currentOrganizationId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      phone: phone ?? this.phone,
      accessToken: accessToken ?? this.accessToken,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      token: token ?? this.token,
    );
  }
}
