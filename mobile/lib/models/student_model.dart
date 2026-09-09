class InstitutionSummary {
  final int? id;
  final String? name;
  final String? institutionType;
  final String? campusName;
  final String? boardOrUniversity;
  final String? city;
  final String? stateName;
  final String? countryName;
  final bool? verified;

  const InstitutionSummary({
    this.id,
    this.name,
    this.institutionType,
    this.campusName,
    this.boardOrUniversity,
    this.city,
    this.stateName,
    this.countryName,
    this.verified,
  });

  factory InstitutionSummary.fromJson(Map<String, dynamic> json) {
    return InstitutionSummary(
      id: json['id'] as int?,
      name: json['name']?.toString(),
      institutionType: json['institutionType']?.toString(),
      campusName: json['campusName']?.toString(),
      boardOrUniversity: json['boardOrUniversity']?.toString(),
      city: json['city']?.toString(),
      stateName: json['stateName']?.toString(),
      countryName: json['countryName']?.toString(),
      verified: json['verified'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'institutionType': institutionType,
        'campusName': campusName,
        'boardOrUniversity': boardOrUniversity,
        'city': city,
        'stateName': stateName,
        'countryName': countryName,
        'verified': verified,
      };
}

class Student {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? branch;
  final String? hostel;
  final String? collegeId;
  final InstitutionSummary? institution;
  final String? institutionType;
  final String? institutionName;
  final String? campusName;
  final String? courseName;
  final String? classLevel;
  final String? city;
  final String? stateName;
  final String? countryName;
  final String? profilePic;
  final String? bio;
  final double? averageRating;
  final int? totalReviews;
  final String role;
  final bool emailVerified;
  final bool phoneVerified;
  final bool isActive;
  final bool isBanned;
  final String? banReason;
  final bool pushNotificationsEnabled;
  final bool emailNotificationsEnabled;
  final bool showPhoneOnListings;
  final bool allowDirectChat;
  final String privacyMode;
  final String preferredLanguage;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final String? authProvider;
  final String contactAccessTier;
  final String? contactAccessExpiresAt;
  final String activeSubscriptionCode;
  final String? subscriptionActivatedAt;
  final int availableBoostCredits;
  final int usedBoostCredits;
  final double currentCommissionPercent;
  final int moderationStrikeCount;
  final String? maskedPhone;
  final bool phoneVisibleToViewer;
  final String? contactRevealReason;
  final bool identityVerified;

  Student({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.branch,
    this.hostel,
    this.collegeId,
    this.institution,
    this.institutionType,
    this.institutionName,
    this.campusName,
    this.courseName,
    this.classLevel,
    this.city,
    this.stateName,
    this.countryName,
    this.profilePic,
    this.bio,
    this.averageRating,
    this.totalReviews,
    this.role = 'STUDENT',
    this.emailVerified = false,
    this.phoneVerified = false,
    this.isActive = false,
    this.isBanned = false,
    this.banReason,
    this.pushNotificationsEnabled = true,
    this.emailNotificationsEnabled = true,
    this.showPhoneOnListings = true,
    this.allowDirectChat = true,
    this.privacyMode = 'CAMPUS_ONLY',
    this.preferredLanguage = 'EN',
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.authProvider,
    this.contactAccessTier = 'FREE',
    this.contactAccessExpiresAt,
    this.activeSubscriptionCode = 'FREE',
    this.subscriptionActivatedAt,
    this.availableBoostCredits = 0,
    this.usedBoostCredits = 0,
    this.currentCommissionPercent = 7,
    this.moderationStrikeCount = 0,
    this.maskedPhone,
    this.phoneVisibleToViewer = false,
    this.contactRevealReason,
    this.identityVerified = false,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      branch: json['branch'],
      hostel: json['hostel'],
      collegeId: json['collegeId'],
      institution: json['institution'] is Map<String, dynamic>
          ? InstitutionSummary.fromJson(json['institution'] as Map<String, dynamic>)
          : null,
      institutionType: json['institutionType']?.toString(),
      institutionName: json['institutionName']?.toString(),
      campusName: json['campusName']?.toString(),
      courseName: json['courseName']?.toString(),
      classLevel: json['classLevel']?.toString(),
      city: json['city']?.toString(),
      stateName: json['stateName']?.toString(),
      countryName: json['countryName']?.toString(),
      profilePic: json['profilePic'],
      bio: json['bio'],
      averageRating: json['averageRating'] != null
          ? (json['averageRating'] as num).toDouble()
          : null,
      totalReviews: json['totalReviews'] as int?,
      role: json['role'] ?? 'STUDENT',
      emailVerified: json['emailVerified'] ?? false,
      phoneVerified: json['phoneVerified'] ?? false,
      isActive: json['isActive'] ?? false,
      isBanned: json['isBanned'] ?? false,
      banReason: json['banReason']?.toString(),
      pushNotificationsEnabled: json['pushNotificationsEnabled'] ?? true,
      emailNotificationsEnabled: json['emailNotificationsEnabled'] ?? true,
      showPhoneOnListings: json['showPhoneOnListings'] ?? true,
      allowDirectChat: json['allowDirectChat'] ?? true,
      privacyMode: json['privacyMode'] ?? 'CAMPUS_ONLY',
      preferredLanguage: json['preferredLanguage'] ?? 'EN',
      locationLabel: json['locationLabel'],
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      authProvider: json['authProvider']?.toString(),
      contactAccessTier: json['contactAccessTier']?.toString() ?? 'FREE',
      contactAccessExpiresAt: json['contactAccessExpiresAt']?.toString(),
      activeSubscriptionCode:
          json['activeSubscriptionCode']?.toString() ?? 'FREE',
      subscriptionActivatedAt:
          json['subscriptionActivatedAt']?.toString(),
      availableBoostCredits:
          (json['availableBoostCredits'] as num?)?.toInt() ?? 0,
      usedBoostCredits:
          (json['usedBoostCredits'] as num?)?.toInt() ?? 0,
      currentCommissionPercent:
          (json['currentCommissionPercent'] as num?)?.toDouble() ?? 7,
      moderationStrikeCount: (json['moderationStrikeCount'] as num?)?.toInt() ?? 0,
      maskedPhone: json['maskedPhone']?.toString(),
      phoneVisibleToViewer: json['phoneVisibleToViewer'] ?? false,
      contactRevealReason: json['contactRevealReason']?.toString(),
      identityVerified: json['identityVerified'] ?? false,
    );
  }

  Student copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? branch,
    String? hostel,
    String? collegeId,
    InstitutionSummary? institution,
    String? institutionType,
    String? institutionName,
    String? campusName,
    String? courseName,
    String? classLevel,
    String? city,
    String? stateName,
    String? countryName,
    String? profilePic,
    String? bio,
    double? averageRating,
    int? totalReviews,
    String? role,
    bool? emailVerified,
    bool? phoneVerified,
    bool? isActive,
    bool? isBanned,
    String? banReason,
    bool? pushNotificationsEnabled,
    bool? emailNotificationsEnabled,
    bool? showPhoneOnListings,
    bool? allowDirectChat,
    String? privacyMode,
    String? preferredLanguage,
    String? locationLabel,
    double? latitude,
    double? longitude,
    String? authProvider,
    String? contactAccessTier,
    String? contactAccessExpiresAt,
    String? activeSubscriptionCode,
    String? subscriptionActivatedAt,
    int? availableBoostCredits,
    int? usedBoostCredits,
    double? currentCommissionPercent,
    int? moderationStrikeCount,
    String? maskedPhone,
    bool? phoneVisibleToViewer,
    String? contactRevealReason,
    bool? identityVerified,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      branch: branch ?? this.branch,
      hostel: hostel ?? this.hostel,
      collegeId: collegeId ?? this.collegeId,
      institution: institution ?? this.institution,
      institutionType: institutionType ?? this.institutionType,
      institutionName: institutionName ?? this.institutionName,
      campusName: campusName ?? this.campusName,
      courseName: courseName ?? this.courseName,
      classLevel: classLevel ?? this.classLevel,
      city: city ?? this.city,
      stateName: stateName ?? this.stateName,
      countryName: countryName ?? this.countryName,
      profilePic: profilePic ?? this.profilePic,
      bio: bio ?? this.bio,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      role: role ?? this.role,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      showPhoneOnListings: showPhoneOnListings ?? this.showPhoneOnListings,
      allowDirectChat: allowDirectChat ?? this.allowDirectChat,
      privacyMode: privacyMode ?? this.privacyMode,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      locationLabel: locationLabel ?? this.locationLabel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      authProvider: authProvider ?? this.authProvider,
      contactAccessTier: contactAccessTier ?? this.contactAccessTier,
      contactAccessExpiresAt:
          contactAccessExpiresAt ?? this.contactAccessExpiresAt,
      activeSubscriptionCode:
          activeSubscriptionCode ?? this.activeSubscriptionCode,
      subscriptionActivatedAt:
          subscriptionActivatedAt ?? this.subscriptionActivatedAt,
      availableBoostCredits:
          availableBoostCredits ?? this.availableBoostCredits,
      usedBoostCredits: usedBoostCredits ?? this.usedBoostCredits,
      currentCommissionPercent:
          currentCommissionPercent ?? this.currentCommissionPercent,
      moderationStrikeCount:
          moderationStrikeCount ?? this.moderationStrikeCount,
      maskedPhone: maskedPhone ?? this.maskedPhone,
      phoneVisibleToViewer:
          phoneVisibleToViewer ?? this.phoneVisibleToViewer,
      contactRevealReason:
          contactRevealReason ?? this.contactRevealReason,
      identityVerified: identityVerified ?? this.identityVerified,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'branch': branch,
        'hostel': hostel,
        'collegeId': collegeId,
        'institution': institution?.toJson(),
        'institutionType': institutionType,
        'institutionName': institutionName,
        'campusName': campusName,
        'courseName': courseName,
        'classLevel': classLevel,
        'city': city,
        'stateName': stateName,
        'countryName': countryName,
        'profilePic': profilePic,
        'bio': bio,
        'averageRating': averageRating,
        'totalReviews': totalReviews,
        'role': role,
        'emailVerified': emailVerified,
        'phoneVerified': phoneVerified,
        'isActive': isActive,
        'isBanned': isBanned,
        'banReason': banReason,
        'pushNotificationsEnabled': pushNotificationsEnabled,
        'emailNotificationsEnabled': emailNotificationsEnabled,
        'showPhoneOnListings': showPhoneOnListings,
        'allowDirectChat': allowDirectChat,
        'privacyMode': privacyMode,
        'preferredLanguage': preferredLanguage,
        'locationLabel': locationLabel,
        'latitude': latitude,
        'longitude': longitude,
        'authProvider': authProvider,
        'contactAccessTier': contactAccessTier,
        'contactAccessExpiresAt': contactAccessExpiresAt,
        'activeSubscriptionCode': activeSubscriptionCode,
        'subscriptionActivatedAt': subscriptionActivatedAt,
        'availableBoostCredits': availableBoostCredits,
        'usedBoostCredits': usedBoostCredits,
        'currentCommissionPercent': currentCommissionPercent,
        'moderationStrikeCount': moderationStrikeCount,
        'maskedPhone': maskedPhone,
        'phoneVisibleToViewer': phoneVisibleToViewer,
        'contactRevealReason': contactRevealReason,
        'identityVerified': identityVerified,
      };
}
