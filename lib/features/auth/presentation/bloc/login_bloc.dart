import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/auth/data/auth_repository.dart';
import 'package:nomowear/features/auth/presentation/bloc/login_event.dart';
import 'package:nomowear/features/auth/presentation/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AuthRepository _authRepository;
  final AuthStorage _authStorage;

  LoginBloc({
    AuthRepository? authRepository,
    AuthStorage? authStorage,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _authStorage = authStorage ?? AuthStorage(),
        super(const LoginState()) {
    on<MobileNumberChangedEvent>(_onMobileNumberChanged);
    on<LoginSubmitEvent>(_onLoginSubmit);
  }

  void _onMobileNumberChanged(
    MobileNumberChangedEvent event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(
      mobileNumber: event.mobileNumber,
      isButtonEnabled: event.mobileNumber.length == 10,
      clearError: true,
      clearOtpSession: true,
    ));
  }

  Future<void> _onLoginSubmit(
    LoginSubmitEvent event,
    Emitter<LoginState> emit,
  ) async {
    if (!state.isButtonEnabled || state.isLoading) return;

    emit(state.copyWith(isLoading: true, clearError: true, clearOtpSession: true));

    try {
      final session = await _authRepository.login(state.mobileNumber);
      await _authStorage.savePendingOtpSession(
        customerId: session.customerId,
        userToken: session.userToken,
        mobileNumber: session.mobileNumber,
      );
      emit(state.copyWith(isLoading: false, otpSession: session));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Something went wrong. Please try again.',
      ));
    }
  }
}
