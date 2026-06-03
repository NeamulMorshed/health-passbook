class DoctorProfile {
  final String uid;
  final String name;
  final String? specialty;
  final String? hospital;
  final String? licenseNo;
  final String? phone;
  final String? photoUrl;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool acceptingNewPatients;
  final String? availableHours;
  final String? consultationFee;
  // 'unverified' | 'pending' | 'verified'
  final String verificationStatus;
  final String? city;
  final String? area;

  const DoctorProfile({
    required this.uid,
    required this.name,
    this.specialty,
    this.hospital,
    this.licenseNo,
    this.phone,
    this.photoUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isVerified = false,
    this.acceptingNewPatients = true,
    this.availableHours,
    this.consultationFee,
    this.verificationStatus = 'unverified',
    this.city,
    this.area,
  });

  factory DoctorProfile.fromMap(Map<String, dynamic> map, String uid) {
    return DoctorProfile(
      uid: uid,
      name: map['name'] ?? '',
      specialty: map['specialty'],
      hospital: map['hospital'],
      licenseNo: map['licenseNo'],
      phone: map['phone'],
      photoUrl: map['photoUrl'],
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: map['reviewCount'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      acceptingNewPatients: map['acceptingNewPatients'] ?? true,
      availableHours: map['availableHours'],
      consultationFee: map['consultationFee'],
      verificationStatus: map['verificationStatus'] ?? 'unverified',
      city: map['city'],
      area: map['area'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'specialty': specialty,
        'hospital': hospital,
        'licenseNo': licenseNo,
        'phone': phone,
        'photoUrl': photoUrl,
        'rating': rating,
        'reviewCount': reviewCount,
        'isVerified': isVerified,
        'acceptingNewPatients': acceptingNewPatients,
        'availableHours': availableHours,
        'consultationFee': consultationFee,
        'verificationStatus': verificationStatus,
        'city': city,
        'area': area,
      };
}
