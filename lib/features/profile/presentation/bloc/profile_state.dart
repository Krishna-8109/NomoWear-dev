import 'package:equatable/equatable.dart';

class ProfileState extends Equatable {
  final String firstName;
  final String lastName;
  final String dob;
  final String gender;
  final String mobileNumber;
  final String email;
  final String state;
  final String city;
  final String pincode;
  final String address;
  
  final bool isSaving;
  final bool isSuccess;
  final String? errorMessage;
  final String? addressError;

  const ProfileState({
    this.firstName = "",
    this.lastName = "",
    this.dob = "",
    this.gender = "Male",
    this.mobileNumber = "",
    this.email = "",
    this.state = "",
    this.city = "",
    this.pincode = "",
    this.address = "",
    this.isSaving = false,
    this.isSuccess = false,
    this.errorMessage,
    this.addressError,
  });

  ProfileState copyWith({
    String? firstName,
    String? lastName,
    String? dob,
    String? gender,
    String? mobileNumber,
    String? email,
    String? state,
    String? city,
    String? pincode,
    String? address,
    bool? isSaving,
    bool? isSuccess,
    String? errorMessage,
    String? addressError,
  }) {
    return ProfileState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      state: state ?? this.state,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      address: address ?? this.address,
      isSaving: isSaving ?? this.isSaving,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
      addressError: addressError ?? this.addressError,
    );
  }

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        dob,
        gender,
        mobileNumber,
        email,
        state,
        city,
        pincode,
        address,
        isSaving,
        isSuccess,
        errorMessage,
        addressError,
      ];
}
