class ParkingSpace {
  final int id;
  final String name;
  final String address;
  final String location;
  final int totalSlots;
  final String? vendorName;
  final bool isActive;
  final String? createdAt;

  ParkingSpace({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.totalSlots,
    this.vendorName,
    required this.isActive,
    this.createdAt,
  });

  factory ParkingSpace.fromJson(Map<String, dynamic> json) {
    return ParkingSpace(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      location: json['location'],
      totalSlots: json['total_slots'],
      vendorName: json['vendor_name'],
      isActive: json['is_active'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'location': location,
      'total_slots': totalSlots,
      'vendor_name': vendorName,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}