class Lead {
  final int? id;
  final String placeId;
  final String name;
  final String? phoneNumber;
  final String? address;
  final String? website;
  final String status;
  final double? rating;

  Lead({
    this.id,
    required this.placeId,
    required this.name,
    this.phoneNumber,
    this.address,
    this.website,
    this.status = 'Uncontacted',
    this.rating,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'placeId': placeId,
      'name': name,
      'phoneNumber': phoneNumber,
      'address': address,
      'website': website,
      'status': status,
      'rating': rating,
    };
  }

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      id: map['id'],
      placeId: map['placeId'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      website: map['website'],
      status: map['status'] ?? 'Uncontacted',
      rating: map['rating'],
    );
  }

  Lead copyWith({
    int? id,
    String? placeId,
    String? name,
    String? phoneNumber,
    String? address,
    String? website,
    String? status,
    double? rating,
  }) {
    return Lead(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      website: website ?? this.website,
      status: status ?? this.status,
      rating: rating ?? this.rating,
    );
  }
}
