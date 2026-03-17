class Lead {
  final String name;
  final String? phoneNumber;
  final String? address;
  final String? website;

  Lead({
    required this.name,
    this.phoneNumber,
    this.address,
    this.website,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'address': address,
      'website': website,
    };
  }

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      website: map['website'],
    );
  }
}
