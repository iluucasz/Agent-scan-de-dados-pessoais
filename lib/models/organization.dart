class Organization {
  final int id;
  final String name;
  final String description;
  final String? logoUrl;
  final String type;
  final int? parentId;
  final String? cnpj;
  final String? address;
  final String? city;
  final String? state;
  final String country;
  final String? postalCode;
  final String? phone;
  final String? website;
  final String subscriptionPlan;
  final String? subscriptionStart;
  final String? subscriptionEnd;
  final String paymentStatus;
  final dynamic enabledModules;
  final int? maxUsers;
  final int? maxStorage;
  final String? createdBy;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Organization({
    required this.id,
    required this.name,
    required this.description,
    this.logoUrl,
    required this.type,
    this.parentId,
    this.cnpj,
    this.address,
    this.city,
    this.state,
    required this.country,
    this.postalCode,
    this.phone,
    this.website,
    required this.subscriptionPlan,
    this.subscriptionStart,
    this.subscriptionEnd,
    required this.paymentStatus,
    this.enabledModules,
    this.maxUsers,
    this.maxStorage,
    this.createdBy,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      type: json['type'] as String? ?? 'empresa',
      parentId: json['parentId'] as int?,
      cnpj: json['cnpj'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String? ?? 'Brasil',
      postalCode: json['postalCode'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      subscriptionPlan: json['subscriptionPlan'] as String? ?? 'free',
      subscriptionStart: json['subscriptionStart'] as String?,
      subscriptionEnd: json['subscriptionEnd'] as String?,
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      enabledModules: json['enabledModules'],
      maxUsers: json['maxUsers'] as int?,
      maxStorage: json['maxStorage'] as int?,
      createdBy: json['createdBy'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt:
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt:
          json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'type': type,
      'parentId': parentId,
      'cnpj': cnpj,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'phone': phone,
      'website': website,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionStart': subscriptionStart,
      'subscriptionEnd': subscriptionEnd,
      'paymentStatus': paymentStatus,
      'enabledModules': enabledModules,
      'maxUsers': maxUsers,
      'maxStorage': maxStorage,
      'createdBy': createdBy,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Organization copyWith({
    int? id,
    String? name,
    String? description,
    String? logoUrl,
    String? type,
    int? parentId,
    String? cnpj,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? phone,
    String? website,
    String? subscriptionPlan,
    String? subscriptionStart,
    String? subscriptionEnd,
    String? paymentStatus,
    dynamic enabledModules,
    int? maxUsers,
    int? maxStorage,
    String? createdBy,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      cnpj: cnpj ?? this.cnpj,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionStart: subscriptionStart ?? this.subscriptionStart,
      subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      enabledModules: enabledModules ?? this.enabledModules,
      maxUsers: maxUsers ?? this.maxUsers,
      maxStorage: maxStorage ?? this.maxStorage,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
