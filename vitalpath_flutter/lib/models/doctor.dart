
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
      };
}
