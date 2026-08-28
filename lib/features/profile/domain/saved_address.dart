import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/features/auth/data/models/customer.dart';
import 'package:nomowear/features/profile/data/address_repository.dart';

/// One saved delivery address (Profile → My Addresses).
class SavedAddress {
  final String id;
  final String title;
  final String addressLines;
  final String mobileDisplay;
  final String contactName;
  final String buildingNumber;
  final String streetName;
  final String locationDetails;
  final double? latitude;
  final double? longitude;

  const SavedAddress({
    required this.id,
    required this.title,
    required this.addressLines,
    required this.mobileDisplay,
    this.contactName = '',
    this.buildingNumber = '',
    this.streetName = '',
    this.locationDetails = '',
    this.latitude,
    this.longitude,
  });

  SavedAddress copyWith({
    String? id,
    String? title,
    String? addressLines,
    String? mobileDisplay,
    String? contactName,
    String? buildingNumber,
    String? streetName,
    String? locationDetails,
    double? latitude,
    double? longitude,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      title: title ?? this.title,
      addressLines: addressLines ?? this.addressLines,
      mobileDisplay: mobileDisplay ?? this.mobileDisplay,
      contactName: contactName ?? this.contactName,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      streetName: streetName ?? this.streetName,
      locationDetails: locationDetails ?? this.locationDetails,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

/// In-memory list populated from address API and new address flow.
final List<SavedAddress> userSavedAddresses = <SavedAddress>[];

final AddressRepository _addressRepository = AddressRepository();

String newSavedAddressId() => 'addr_${DateTime.now().millisecondsSinceEpoch}';

bool _isLocalOnlyAddressId(String id) => id.startsWith('addr_');

String _formatCustomerAddress(CustomerAddress address) {
  final building = address.buildingNumber?.trim() ?? '';
  final street = address.streetName?.trim() ?? '';
  
  String baseAddress = '';
  
  final full = address.fullAddress?.trim();
  if (full != null && full.isNotEmpty) {
    baseAddress = full;
  } else {
    final parts = <String?>[
      address.addressLine1,
      address.addressLine2,
      address.city,
      address.state,
      address.pincode,
      address.country,
    ]
        .map((part) => part?.trim())
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .toList();
    baseAddress = parts.join(', ');
  }

  final lowerBase = baseAddress.toLowerCase();
  
  final displayParts = <String>[];
  
  if (building.isNotEmpty && !lowerBase.contains(building.toLowerCase())) {
    displayParts.add(building);
  }
  
  if (street.isNotEmpty && !lowerBase.contains(street.toLowerCase())) {
    displayParts.add(street);
  }
  
  if (baseAddress.isNotEmpty) {
    displayParts.add(baseAddress);
  }

  return displayParts.join(', ');
}

String _titleForAddress(CustomerAddress address, int index, {String? label}) {
  final customLabel = label?.trim();
  if (customLabel != null && customLabel.isNotEmpty) return customLabel;

  final city = address.city?.trim();
  if (city != null && city.isNotEmpty) return city;

  final building = address.buildingNumber?.trim();
  if (building != null && building.isNotEmpty) return building;

  return 'Address ${index + 1}';
}

SavedAddress _toSavedAddress(
  CustomerAddress address,
  int index, {
  String? label,
}) {
  final building = address.buildingNumber?.trim() ??
      address.addressLine1?.trim() ??
      '';
  final street = address.streetName?.trim() ?? '';
  final location = address.addressLine2?.trim() ?? '';

  return SavedAddress(
    id: address.id?.trim().isNotEmpty == true
        ? address.id!.trim()
        : 'profile_addr_$index',
    title: _titleForAddress(address, index, label: label),
    addressLines: _formatCustomerAddress(address),
    mobileDisplay: address.phone?.trim() ?? '',
    contactName: address.fullName?.trim() ?? '',
    buildingNumber: building,
    streetName: street,
    locationDetails: location,
    latitude: address.latitude,
    longitude: address.longitude,
  );
}

SavedAddress _fromAddressMap(
  String id,
  Map<String, String> map, {
  SavedAddress? previous,
}) {
  final building = map['buildingNumber']?.trim() ?? '';
  final street = map['streetName']?.trim() ?? '';
  final location = map['locationDetails']?.trim() ?? '';

  return SavedAddress(
    id: id,
    title: map['title']?.trim().isNotEmpty == true
        ? map['title']!.trim()
        : (previous?.title ?? 'Address'),
    addressLines: map['addressLines']?.trim().isNotEmpty == true
        ? map['addressLines']!.trim()
        : (previous?.addressLines ?? ''),
    mobileDisplay: map['phone']?.trim().isNotEmpty == true
        ? map['phone']!.trim()
        : (previous?.mobileDisplay ?? ''),
    contactName: map['contactName']?.trim().isNotEmpty == true
        ? map['contactName']!.trim()
        : (previous?.contactName ?? ''),
    buildingNumber: building.isNotEmpty ? building : (previous?.buildingNumber ?? ''),
    streetName: street.isNotEmpty ? street : (previous?.streetName ?? ''),
    locationDetails: location.isNotEmpty ? location : (previous?.locationDetails ?? ''),
    latitude: double.tryParse(map['latitude'] ?? '') ?? previous?.latitude,
    longitude: double.tryParse(map['longitude'] ?? '') ?? previous?.longitude,
  );
}

/// Loads addresses from GET customer-addresses/customer.
Future<void> loadSavedAddressesFromProfile({bool forceRefresh = false}) async {
  if (!forceRefresh && userSavedAddresses.isNotEmpty) {
    return;
  }
  final addresses = await _addressRepository.getCustomerAddresses();

  final fromApi = <SavedAddress>[];
  for (var i = 0; i < addresses.length; i++) {
    final address = addresses[i];
    if (!address.hasAnyField) continue;
    fromApi.add(_toSavedAddress(address, i));
  }

  final localOnly = userSavedAddresses
      .where(
        (address) =>
            _isLocalOnlyAddressId(address.id) &&
            !fromApi.any((apiAddress) => apiAddress.id == address.id),
      )
      .toList();

  userSavedAddresses
    ..clear()
    ..addAll(fromApi)
    ..addAll(localOnly);
}

/// Creates address via POST and appends to the in-memory list.
Future<SavedAddress> createAndAppendSavedAddress(
  Map<String, String> map,
) async {
  final created = await _addressRepository.createAddressFromMap(
    map,
    isDefault: userSavedAddresses.isEmpty,
  );

  final saved = _toSavedAddress(
    created,
    userSavedAddresses.length,
    label: map['title'],
  ).copyWith(
    mobileDisplay: map['phone']?.trim().isNotEmpty == true
        ? map['phone']!.trim()
        : savedMobile(created, map),
    contactName: map['contactName']?.trim().isNotEmpty == true
        ? map['contactName']!.trim()
        : (created.fullName?.trim() ?? ''),
    addressLines: map['addressLines']?.trim().isNotEmpty == true
        ? map['addressLines']!.trim()
        : _formatCustomerAddress(created),
    buildingNumber: map['buildingNumber']?.trim() ?? created.buildingNumber ?? '',
    streetName: map['streetName']?.trim() ?? created.streetName ?? '',
    locationDetails: map['locationDetails']?.trim() ?? created.addressLine2 ?? '',
    latitude: double.tryParse(map['latitude'] ?? '') ?? created.latitude,
    longitude: double.tryParse(map['longitude'] ?? '') ?? created.longitude,
  );

  userSavedAddresses.add(saved);
  return saved;
}

String savedMobile(CustomerAddress created, Map<String, String> map) {
  return created.phone?.trim().isNotEmpty == true
      ? created.phone!.trim()
      : (map['phone']?.trim() ?? '');
}

/// Local-only append fallback (no API).
void appendSavedAddressFromMap(Map<String, String> map) {
  userSavedAddresses.add(
    _fromAddressMap(newSavedAddressId(), map),
  );
}

void replaceSavedAddress(String id, Map<String, String> map) {
  final i = userSavedAddresses.indexWhere((e) => e.id == id);
  if (i < 0) return;
  userSavedAddresses[i] = _fromAddressMap(
    id,
    map,
    previous: userSavedAddresses[i],
  );
}

/// Updates address via PUT API when persisted, then refreshes local list entry.
Future<SavedAddress> updateSavedAddressById(
  String id,
  Map<String, String> map,
) async {
  if (_isLocalOnlyAddressId(id)) {
    replaceSavedAddress(id, map);
    return userSavedAddresses.firstWhere((address) => address.id == id);
  }

  final updated = await _addressRepository.updateAddressFromMap(id, map);
  final index = userSavedAddresses.indexWhere((address) => address.id == id);
  final saved = _toSavedAddress(
    updated,
    index >= 0 ? index : userSavedAddresses.length,
    label: map['title'],
  ).copyWith(
    id: updated.id?.trim().isNotEmpty == true ? updated.id!.trim() : id,
    mobileDisplay: map['phone']?.trim().isNotEmpty == true
        ? map['phone']!.trim()
        : savedMobile(updated, map),
    contactName: map['contactName']?.trim().isNotEmpty == true
        ? map['contactName']!.trim()
        : (updated.fullName?.trim() ?? ''),
    addressLines: map['addressLines']?.trim().isNotEmpty == true
        ? map['addressLines']!.trim()
        : _formatCustomerAddress(updated),
    buildingNumber: map['buildingNumber']?.trim() ??
        updated.buildingNumber ??
        updated.addressLine1 ??
        '',
    streetName: map['streetName']?.trim() ?? updated.streetName ?? '',
    locationDetails: map['locationDetails']?.trim() ??
        updated.addressLine2 ??
        '',
    latitude: double.tryParse(map['latitude'] ?? '') ?? updated.latitude,
    longitude: double.tryParse(map['longitude'] ?? '') ?? updated.longitude,
  );

  if (index >= 0) {
    userSavedAddresses[index] = saved;
  } else {
    userSavedAddresses.add(saved);
  }
  return saved;
}

void removeSavedAddressById(String id) {
  userSavedAddresses.removeWhere((e) => e.id == id);
}

/// Deletes address via API when persisted, then removes from local list.
Future<void> deleteSavedAddressById(String id) async {
  if (!_isLocalOnlyAddressId(id)) {
    await _addressRepository.deleteAddress(id);
  }
  removeSavedAddressById(id);
}

String? addressErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'Unable to save address. Please try again.';
}
