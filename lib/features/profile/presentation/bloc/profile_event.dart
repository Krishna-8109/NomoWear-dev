import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ProfileUpdateFieldEvent extends ProfileEvent {
  final String? firstName;
  final String? lastName;
  final String? dob;
  final String? gender;
  final String? mobileNumber;
  final String? email;
  final String? state;
  final String? city;
  final String? pincode;
  final String? address;

  ProfileUpdateFieldEvent({
    this.firstName,
    this.lastName,
    this.dob,
    this.gender,
    this.mobileNumber,
    this.email,
    this.state,
    this.city,
    this.pincode,
    this.address,
  });

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
      ];
}

class SaveProfileEvent extends ProfileEvent {}
