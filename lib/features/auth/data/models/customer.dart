import 'package:nomowear/core/utils/mobile_number_utils.dart';

class CustomerAddress {
  final String? id;
  final String? country;
  final String? state;
  final String? city;
  final String? pincode;
  final String? fullAddress;
  final String? phone;
  final String? fullName;
  final String? buildingNumber;
  final String? streetName;
  final String? addressLine1;
  final String? addressLine2;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const CustomerAddress({
    this.id,
    this.country,
    this.state,
    this.city,
    this.pincode,
    this.fullAddress,
    this.phone,
    this.fullName,
    this.buildingNumber,
    this.streetName,
    this.addressLine1,
    this.addressLine2,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    String? pick(String a, String b, [String? c, String? d, String? e]) {
      final v = json[a] ??
          json[b] ??
          (c != null ? json[c] : null) ??
          (d != null ? json[d] : null) ??
          (e != null ? json[e] : null);
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    double? pickDouble(String a, String b) {
      final value = json[a] ?? json[b];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    final isDefaultRaw = json['is_default'] ?? json['isDefault'];

    return CustomerAddress(
      id: pick('id', 'address_id', 'addressId'),
      country: pick('country', 'country_name'),
      state: pick('state', 'state_name'),
      city: pick('city', 'city_name'),
      pincode: pick('pincode', 'pin_code', 'postal_code', 'zip', 'zip_code'),
      fullAddress: pick(
        'full_address',
        'fullAddress',
        'address',
        'address_line',
      ),
      phone: pick('phone', 'phone_number', 'mobile', 'mobileNumber'),
      fullName: pick('fullName', 'full_name', 'name'),
      buildingNumber: pick('buildingNumber', 'building_number'),
      streetName: pick('streetName', 'street_name'),
      addressLine1: pick('address_line1', 'addressLine1'),
      addressLine2: pick('address_line2', 'addressLine2'),
      latitude: pickDouble('latitude', 'lat'),
      longitude: pickDouble('longitude', 'lng'),
      isDefault: isDefaultRaw == true ||
          isDefaultRaw?.toString().toLowerCase() == 'true' ||
          isDefaultRaw?.toString() == '1',
    );
  }

  bool get hasAnyField =>
      (country?.isNotEmpty ?? false) ||
      (state?.isNotEmpty ?? false) ||
      (city?.isNotEmpty ?? false) ||
      (pincode?.isNotEmpty ?? false) ||
      (fullAddress?.isNotEmpty ?? false) ||
      (addressLine1?.isNotEmpty ?? false) ||
      (addressLine2?.isNotEmpty ?? false) ||
      (buildingNumber?.isNotEmpty ?? false) ||
      (streetName?.isNotEmpty ?? false);
}

class Customer {
  final String id;
  final String? fullName;
  final String mobile;
  final String? email;
  final String? dob;
  final String? profilePhoto;
  final String? height;
  final String? weight;
  final String? bodySkinType;
  final String subscriptionTier;
  final String status;
  final String wallet;
  final int isVerified;
  final List<CustomerAddress> addresses;
  final double? latitude;
  final double? longitude;

  const Customer({
    required this.id,
    this.fullName,
    required this.mobile,
    this.email,
    this.dob,
    this.profilePhoto,
    this.height,
    this.weight,
    this.bodySkinType,
    required this.subscriptionTier,
    this.status = 'active',
    this.wallet = '0.00',
    required this.isVerified,
    this.addresses = const [],
    this.latitude,
    this.longitude,
  });

  CustomerAddress? get primaryAddress {
    if (addresses.isEmpty) return null;
    return addresses.firstWhere(
      (a) => a.hasAnyField,
      orElse: () => addresses.first,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    final addresses = <CustomerAddress>[];

    final rawAddresses = json['addresses'];
    if (rawAddresses is List) {
      for (final item in rawAddresses) {
        if (item is Map<String, dynamic>) {
          addresses.add(CustomerAddress.fromJson(item));
        }
      }
    }

    for (final key in ['default_address', 'defaultAddress', 'shipping_address']) {
      final nested = json[key];
      if (nested is Map<String, dynamic>) {
        addresses.insert(0, CustomerAddress.fromJson(nested));
        break;
      }
    }

    // Some APIs return address on the customer root (register / profile).
    final rootAddress = CustomerAddress.fromJson(json);
    if (rootAddress.hasAnyField) {
      final duplicate = addresses.any(
        (a) =>
            a.pincode == rootAddress.pincode &&
            a.fullAddress == rootAddress.fullAddress,
      );
      if (!duplicate) {
        addresses.insert(0, rootAddress);
      }
    }

    return Customer(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString(),
      mobile: MobileNumberUtils.normalizeIndianMobile(
            json['mobile']?.toString() ?? json['mobileNumber']?.toString(),
          ) ??
          json['mobile']?.toString() ??
          json['mobileNumber']?.toString() ??
          '',
      email: json['email']?.toString() ?? json['businessEmail']?.toString(),
      dob: json['dob']?.toString(),
      profilePhoto: json['profile_photo']?.toString() ??
          json['profilePhoto']?.toString(),
      height: json['height']?.toString(),
      weight: json['weight']?.toString(),
      bodySkinType: json['bodySkinType']?.toString() ??
          json['body_skin_type']?.toString(),
      subscriptionTier:
          json['subscription_tier']?.toString() ?? 'Standard',
      status: json['status']?.toString() ?? 'active',
      wallet: json['wallet']?.toString() ?? '0.00',
      isVerified: json['is_verified'] is int
          ? json['is_verified'] as int
          : int.tryParse(json['is_verified']?.toString() ?? '0') ?? 0,
      addresses: addresses,
      latitude: parseDouble(json['latitude'] ?? json['lat']),
      longitude: parseDouble(json['longitude'] ?? json['lng']),
    );
  }
}
