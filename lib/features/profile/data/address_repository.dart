import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/core/utils/mobile_number_utils.dart';
import 'package:nomowear/features/auth/data/models/customer.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';

class CreateCustomerAddressInput {
  final String customerId;
  final String fullName;
  final String phone;
  final String buildingNumber;
  final String streetName;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String country;
  final String zipCode;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final bool isDefault;

  const CreateCustomerAddressInput({
    required this.customerId,
    required this.fullName,
    required this.phone,
    required this.buildingNumber,
    required this.streetName,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.country,
    required this.zipCode,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    final normalizedPhone = MobileNumberUtils.normalizeIndianMobile(phone) ?? phone;
    final normalizedFullAddress =
        fullAddress.replaceAll('\n', ', ').replaceAll(RegExp(r',\s*,+'), ', ').trim();

    return {
      'customer_id': customerId,
      'fullName': fullName,
      'phoneNumber': normalizedPhone,
      'buildingNumber': buildingNumber,
      'streetName': streetName,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'country': country,
      'zip_code': zipCode,
      'pincode': zipCode,
      'fullAddress': normalizedFullAddress,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final normalizedPhone = MobileNumberUtils.normalizeIndianMobile(phone) ?? phone;
    final normalizedFullAddress =
        fullAddress.replaceAll('\n', ', ').replaceAll(RegExp(r',\s*,+'), ', ').trim();

    return {
      'fullName': fullName,
      'phoneNumber': normalizedPhone,
      'buildingNumber': buildingNumber,
      'streetName': streetName,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'country': country,
      'zip_code': zipCode,
      'pincode': zipCode,
      'fullAddress': normalizedFullAddress,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    };
  }
}

class AddressRepository {
  AddressRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
    ProfileRepository? profileRepository,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage(),
        _profileRepository = profileRepository ?? ProfileRepository();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;
  final ProfileRepository _profileRepository;

  Future<String> _authToken() async {
    final token = await _authStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }
    return token;
  }

  Future<String> _customerId() async {
    var customer = ProfileCache.instance.customer;
    if (customer == null || customer.id.isEmpty) {
      customer = await _profileRepository.getProfile();
    }
    if (customer.id.isEmpty) {
      throw const ApiException('Customer profile not found.');
    }
    return customer.id;
  }

  Future<List<CustomerAddress>> getCustomerAddresses() async {
    final authToken = await _authToken();

    final json = await _apiClient.get(
      ApiConstants.customerAddressesByCustomerPath,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load addresses',
      );
    }

    return _parseAddressList(json['data']);
  }

  Future<CustomerAddress> createAddress(
    CreateCustomerAddressInput input,
  ) async {
    _validateInput(input);
    final authToken = await _authToken();

    final json = await _apiClient.post(
      ApiConstants.customerAddressesPath,
      input.toJson(),
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to save address',
      );
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return CustomerAddress.fromJson(data);
    }

    return input.toCustomerAddress();
  }

  Future<void> deleteAddress(String addressId) async {
    final id = addressId.trim();
    if (id.isEmpty) {
      throw const ApiException('Address ID is missing.');
    }

    final authToken = await _authToken();

    final json = await _apiClient.delete(
      '${ApiConstants.customerAddressesPath}/$id',
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to delete address',
      );
    }
  }

  Future<CustomerAddress> createAddressFromMap(
    Map<String, String> map, {
    bool isDefault = false,
  }) async {
    final customerId = await _customerId();
    var customer = ProfileCache.instance.customer;
    if (customer == null || customer.id.isEmpty) {
      customer = await _profileRepository.getProfile();
    }
    final input = buildCreateInput(
      map: map,
      customerId: customerId,
      fallbackPhone: customer.mobile,
      isDefault: isDefault,
    );
    return createAddress(input);
  }

  Future<CustomerAddress> updateAddress(
    String addressId,
    CreateCustomerAddressInput input,
  ) async {
    _validateInput(input);

    final id = addressId.trim();
    if (id.isEmpty) {
      throw const ApiException('Address ID is missing.');
    }

    final authToken = await _authToken();

    final json = await _apiClient.put(
      '${ApiConstants.customerAddressesPath}/$id',
      input.toUpdateJson(),
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to update address',
      );
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return CustomerAddress.fromJson(data);
    }

    return input.toCustomerAddress(id: id);
  }

  Future<CustomerAddress> updateAddressFromMap(
    String addressId,
    Map<String, String> map, {
    bool isDefault = false,
  }) async {
    final customerId = await _customerId();
    var customer = ProfileCache.instance.customer;
    if (customer == null || customer.id.isEmpty) {
      customer = await _profileRepository.getProfile();
    }

    final input = buildCreateInput(
      map: map,
      customerId: customerId,
      fallbackPhone: customer.mobile,
      isDefault: isDefault,
    );
    return updateAddress(addressId, input);
  }

  void _validateInput(CreateCustomerAddressInput input) {
    if (input.fullName.trim().isEmpty) {
      throw const ApiException('Full name is required');
    }
    final phone = MobileNumberUtils.normalizeIndianMobile(input.phone);
    if (phone == null || phone.isEmpty) {
      throw const ApiException('Phone number is required');
    }
    if (input.buildingNumber.trim().isEmpty && input.streetName.trim().isEmpty) {
      throw const ApiException('Building or street is required');
    }
    if (input.city.trim().isEmpty) {
      throw const ApiException('City is required');
    }
    if (input.state.trim().isEmpty) {
      throw const ApiException('State is required');
    }
    if (input.country.trim().isEmpty) {
      throw const ApiException('Country is required');
    }
    if (input.zipCode.trim().isEmpty) {
      throw const ApiException('Pincode is required');
    }
    if (input.fullAddress.trim().isEmpty) {
      throw const ApiException('Full address is required');
    }
  }

  static CreateCustomerAddressInput buildCreateInput({
    required Map<String, String> map,
    required String customerId,
    String? fallbackPhone,
    bool isDefault = false,
  }) {
    final building = map['buildingNumber']?.trim() ??
        _firstLine(map['addressLines']) ??
        '';
    final street = map['streetName']?.trim() ?? building;
    final locationDetails = map['locationDetails']?.trim() ?? '';
    final areaTitle = map['areaTitle']?.trim() ?? '';
    final city = _resolveCity(areaTitle, locationDetails);
    final state = _resolveState(locationDetails);
    final country = _resolveCountry(locationDetails);
    final zipCode = _extractPincode(locationDetails);
    final phone = MobileNumberUtils.normalizeIndianMobile(map['phone']) ??
        MobileNumberUtils.normalizeIndianMobile(fallbackPhone) ??
        map['phone']?.trim() ??
        fallbackPhone?.trim() ??
        '';
    final fullAddress = _resolveFullAddress(
      map: map,
      building: building,
      street: street,
      locationDetails: locationDetails,
      city: city,
      state: state,
      zipCode: zipCode,
    );

    return CreateCustomerAddressInput(
      customerId: customerId,
      fullName: map['contactName']?.trim() ?? '',
      phone: phone,
      buildingNumber: building,
      streetName: street,
      addressLine1: building.isNotEmpty ? building : street,
      addressLine2: locationDetails.isNotEmpty ? locationDetails : street,
      city: city,
      state: state,
      country: country,
      zipCode: zipCode,
      fullAddress: fullAddress,
      latitude: double.tryParse(map['latitude'] ?? '') ?? 0,
      longitude: double.tryParse(map['longitude'] ?? '') ?? 0,
      isDefault: isDefault,
    );
  }

  List<CustomerAddress> _parseAddressList(dynamic data) {
    if (data is! List) return const [];

    final addresses = <CustomerAddress>[];
    for (final entry in data) {
      if (entry is Map<String, dynamic>) {
        addresses.add(CustomerAddress.fromJson(entry));
      }
    }
    return addresses;
  }

  static String? _firstLine(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text.split('\n').first.trim();
  }

  static String _resolveFullAddress({
    required Map<String, String> map,
    required String building,
    required String street,
    required String locationDetails,
    required String city,
    required String state,
    required String zipCode,
  }) {
    final fromForm = map['addressLines']?.trim();
    if (fromForm != null && fromForm.isNotEmpty) return fromForm;

    final parts = <String>[
      if (building.isNotEmpty) building,
      if (street.isNotEmpty && street != building) street,
      if (locationDetails.isNotEmpty) locationDetails,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (zipCode.isNotEmpty) zipCode,
    ];
    return parts.join(', ');
  }

  static String _extractPincode(String text) {
    final match = RegExp(r'\b\d{6}\b').firstMatch(text);
    return match?.group(0) ?? '';
  }

  static String _resolveCity(String areaTitle, String locationDetails) {
    final parts = _splitLocationParts(locationDetails);
    for (var i = parts.length - 1; i >= 0; i--) {
      final lower = parts[i].toLowerCase();
      if (lower == 'india') continue;

      if (RegExp(r'\b\d{6}\b').hasMatch(parts[i])) {
        if (i >= 1) {
          final candidate = parts[i - 1].trim();
          if (candidate.isNotEmpty) return candidate;
        }
        continue;
      }

      final withoutPin = parts[i].replaceAll(RegExp(r'\b\d{6}\b'), '').trim();
      if (withoutPin.isEmpty) continue;
      if (_looksLikeState(withoutPin)) {
        if (i >= 1) return parts[i - 1].trim();
        continue;
      }
    }

    if (areaTitle.isNotEmpty) return areaTitle;

    if (parts.length >= 3) return parts[parts.length - 3];
    if (parts.length >= 2) return parts[parts.length - 2];
    return parts.isNotEmpty ? parts.first : '';
  }

  static bool _looksLikeState(String value) {
    const states = {
      'andhra pradesh',
      'arunachal pradesh',
      'assam',
      'bihar',
      'chhattisgarh',
      'goa',
      'gujarat',
      'haryana',
      'himachal pradesh',
      'jharkhand',
      'karnataka',
      'kerala',
      'madhya pradesh',
      'maharashtra',
      'manipur',
      'meghalaya',
      'mizoram',
      'nagaland',
      'odisha',
      'punjab',
      'rajasthan',
      'sikkim',
      'tamil nadu',
      'telangana',
      'tripura',
      'uttar pradesh',
      'uttarakhand',
      'west bengal',
      'delhi',
    };
    return states.contains(value.toLowerCase());
  }

  static String _resolveCountry(String locationDetails) {
    final parts = _splitLocationParts(locationDetails);
    if (parts.isNotEmpty && parts.last.toLowerCase() == 'india') {
      return 'India';
    }
    return 'India';
  }

  static String _resolveState(String locationDetails) {
    final parts = _splitLocationParts(locationDetails);
    if (parts.isEmpty) return '';

    for (var i = parts.length - 1; i >= 0; i--) {
      final part = parts[i].replaceAll(RegExp(r'\b\d{6}\b'), '').trim();
      if (part.isEmpty) continue;

      final lower = part.toLowerCase();
      if (lower == 'india') continue;

      return part;
    }
    return '';
  }

  static List<String> _splitLocationParts(String locationDetails) {
    return locationDetails
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }
}

extension on CreateCustomerAddressInput {
  CustomerAddress toCustomerAddress({String? id}) {
    return CustomerAddress(
      id: id,
      fullName: fullName,
      phone: phone,
      buildingNumber: buildingNumber,
      streetName: streetName,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      country: country,
      pincode: zipCode,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
      fullAddress: fullAddress.isNotEmpty ? fullAddress : addressLine2,
    );
  }
}
