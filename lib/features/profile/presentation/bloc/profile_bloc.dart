import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomowear/features/profile/presentation/bloc/profile_event.dart';
import 'package:nomowear/features/profile/presentation/bloc/profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(const ProfileState()) {
    on<ProfileUpdateFieldEvent>(_onUpdateField);
    on<SaveProfileEvent>(_onSaveProfile);
  }

  void _onUpdateField(ProfileUpdateFieldEvent event, Emitter<ProfileState> emit) {
    emit(state.copyWith(
      firstName: event.firstName,
      lastName: event.lastName,
      dob: event.dob,
      gender: event.gender,
      mobileNumber: event.mobileNumber,
      email: event.email,
      state: event.state,
      city: event.city,
      pincode: event.pincode,
      address: event.address,
      addressError: event.address != null ? null : state.addressError, // Clear address error when typing
    ));
  }

  Future<void> _onSaveProfile(SaveProfileEvent event, Emitter<ProfileState> emit) async {
    if (state.address.isEmpty) {
      emit(state.copyWith(
        addressError: "You didn’t enter Address. Please enter your address.",
      ));
    } else {
      emit(state.copyWith(isSaving: true, addressError: null));
      emit(state.copyWith(isSaving: false, isSuccess: true));
    }
  }
}
