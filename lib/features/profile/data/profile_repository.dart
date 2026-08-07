import 'package:http/http.dart' as http;
import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/auth/data/models/customer.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/data/profile_completion_helper.dart';
import 'package:nomowear/features/profile/data/profile_date_utils.dart';
import 'package:nomowear/features/profile/data/profile_photo_file.dart';

class RegisterProfileInput {
  final String fullName;
  final String mobile;
  final String businessEmail;
  final String? dob;
  final ProfilePhotoFile? profilePhoto;
  final String subscriptionTier;
  final String? country;
  final String? state;
  final String? city;
  final String? pincode;
  final String? fullAddress;
  final String? height;
  final String? weight;
  final String? bodySkinType;

  const RegisterProfileInput({
    required this.fullName,
    required this.mobile,
    required this.businessEmail,
    this.dob,
    this.profilePhoto,
    this.subscriptionTier = 'Standard',
    this.country,
    this.state,
    this.city,
    this.pincode,
    this.fullAddress,
    this.height,
    this.weight,
    this.bodySkinType,
  });

  Map<String, String> toMultipartFields() {
    final fields = <String, String>{
      'fullName': fullName,
      'mobileNumber': mobile,
      'mobile': mobile,
      'businessEmail': businessEmail,
      'subscriptionTier': subscriptionTier,
    };
    if (dob != null && dob!.isNotEmpty) fields['dob'] = dob!;
    if (country != null && country!.isNotEmpty) fields['country'] = country!;
    if (state != null && state!.isNotEmpty) fields['state'] = state!;
    if (city != null && city!.isNotEmpty) fields['city'] = city!;
    if (pincode != null && pincode!.isNotEmpty) fields['pincode'] = pincode!;
    if (fullAddress != null && fullAddress!.isNotEmpty) {
      fields['fullAddress'] = fullAddress!;
    }
    if (height != null && height!.isNotEmpty) fields['height'] = height!;
    if (weight != null && weight!.isNotEmpty) fields['weight'] = weight!;
    if (bodySkinType != null && bodySkinType!.isNotEmpty) {
      fields['bodySkinType'] = bodySkinType!;
    }
    return fields;
  }

  Map<String, dynamic> toJson() => toMultipartFields();
}

class UpdateProfileInput {
  final String? fullName;
  final String? dob;
  final String? businessEmail;
  final String? subscriptionTier;
  final String? country;
  final String? state;
  final String? city;
  final String? pincode;
  final String? fullAddress;
  final String? mobileNumber;
  final String? height;
  final String? weight;
  final String? bodySkinType;
  final ProfilePhotoFile? profilePhoto;

  const UpdateProfileInput({
    this.fullName,
    this.dob,
    this.businessEmail,
    this.subscriptionTier,
    this.country,
    this.state,
    this.city,
    this.pincode,
    this.fullAddress,
    this.mobileNumber,
    this.height,
    this.weight,
    this.bodySkinType,
    this.profilePhoto,
  });

  Map<String, String> toMultipartFields() {
    final fields = <String, String>{};
    if (fullName != null && fullName!.isNotEmpty) fields['fullName'] = fullName!;
    if (dob != null && dob!.isNotEmpty) fields['dob'] = dob!;
    if (businessEmail != null && businessEmail!.isNotEmpty) {
      fields['businessEmail'] = businessEmail!;
    }
    if (subscriptionTier != null && subscriptionTier!.isNotEmpty) {
      fields['subscriptionTier'] = subscriptionTier!;
    }
    if (country != null && country!.isNotEmpty) fields['country'] = country!;
    if (state != null && state!.isNotEmpty) fields['state'] = state!;
    if (city != null && city!.isNotEmpty) fields['city'] = city!;
    if (pincode != null && pincode!.isNotEmpty) fields['pincode'] = pincode!;
    if (fullAddress != null && fullAddress!.isNotEmpty) {
      fields['fullAddress'] = fullAddress!;
    }
    if (mobileNumber != null && mobileNumber!.isNotEmpty) {
      fields['mobileNumber'] = mobileNumber!;
      fields['mobile'] = mobileNumber!;
    }
    if (height != null && height!.isNotEmpty) fields['height'] = height!;
    if (weight != null && weight!.isNotEmpty) fields['weight'] = weight!;
    if (bodySkinType != null && bodySkinType!.isNotEmpty) {
      fields['bodySkinType'] = bodySkinType!;
    }
    return fields;
  }

  Map<String, dynamic> toJson() => toMultipartFields();
}

class ProfileRepository {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  ProfileRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  List<http.MultipartFile> _photoFiles(ProfilePhotoFile? photo) {
    if (photo == null) return [];
    return [
      http.MultipartFile.fromBytes(
        'profilePhoto',
        photo.bytes,
        filename: photo.filename,
      ),
    ];
  }

  Future<Customer> register(RegisterProfileInput input) async {
    final Map<String, dynamic> json;

    if (input.profilePhoto != null) {
      json = await _apiClient.postMultipart(
        ApiConstants.registerPath,
        fields: input.toMultipartFields(),
        files: _photoFiles(input.profilePhoto),
      );
    } else {
      json = await _apiClient.postMultipart(
        ApiConstants.registerPath,
        fields: input.toMultipartFields(),
      );
    }

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Registration failed',
      );
    }

    final authToken = json['authToken']?.toString();
    final customerJson = json['customer'];
    if (authToken == null ||
        authToken.isEmpty ||
        customerJson is! Map<String, dynamic>) {
      throw const ApiException('Invalid registration response');
    }

    final customer = Customer.fromJson(customerJson);
    await _persistSession(customer, authToken: authToken);

    return customer;
  }

  Future<Customer> getProfile({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = ProfileCache.instance.customer;
      if (cached != null) return cached;
    }

    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.get(
      ApiConstants.profilePath,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load profile',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid profile response');
    }

    final customer = Customer.fromJson(data);
    ProfileCache.instance.set(customer);
    return customer;
  }

  Future<Customer> updateProfile(UpdateProfileInput input) async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final fields = input.toMultipartFields();
    if (fields.isEmpty && input.profilePhoto == null) {
      throw const ApiException('No profile changes to save');
    }

    final json = await _apiClient.putMultipart(
      ApiConstants.profilePath,
      fields: fields,
      files: _photoFiles(input.profilePhoto),
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to update profile',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid profile update response');
    }

    final customer = Customer.fromJson(data);
    await _persistSession(customer, authToken: authToken);

    return customer;
  }

  Future<void> _persistSession(
    Customer customer, {
    required String authToken,
  }) async {
    ProfileCache.instance.set(customer);
    await _authStorage.saveAuthenticatedSession(
      authToken: authToken,
      customerId: customer.id,
      mobileNumber: customer.mobile,
      profileComplete: ProfileCompletionHelper.isProfileComplete(customer),
    );
  }

  static String? dobForApi(String displayDob) =>
      ProfileDateUtils.toApiDate(displayDob);
}
