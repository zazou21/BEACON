class ProfileModel {
  int? id;
  String fullName;
  String phone;
  String emergencyName;
  String emergencyPhone;
  String? location;
  int? createdAt;
  int? updatedAt;

  ProfileModel({
    this.id,
    required this.fullName,
    required this.phone,
    required this.emergencyName,
    required this.emergencyPhone,
    this.location,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'emergencyName': emergencyName,
      'emergencyPhone': emergencyPhone,
      'location': location,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as int?,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String,
      emergencyName: json['emergencyName'] as String,
      emergencyPhone: json['emergencyPhone'] as String,
      location: json['location'] as String?,
      createdAt: json['createdAt'] as int?,
      updatedAt: json['updatedAt'] as int?,
    );
  }
}
