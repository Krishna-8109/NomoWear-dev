import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// UI state for Profile Address State / City-Village dropdowns.
///
/// CHANGE: No longer makes API calls. Populates state/city lists based on
/// existing location data provided via selectState.
class LocationState extends Equatable {
  final List<String> states;
  final List<String> cities;
  final String? selectedState;
  final String? selectedCity;
  final bool isLoadingStates;
  final bool isLoadingCities;
  final String? errorMessage;
  final String? citiesLoadedForState;

  const LocationState({
    this.states = const [],
    this.cities = const [],
    this.selectedState,
    this.selectedCity,
    this.isLoadingStates = false,
    this.isLoadingCities = false,
    this.errorMessage,
    this.citiesLoadedForState,
  });

  bool get hasStates => states.isNotEmpty;
  bool get hasCities => cities.isNotEmpty;

  LocationState copyWith({
    List<String>? states,
    List<String>? cities,
    String? selectedState,
    String? selectedCity,
    bool? isLoadingStates,
    bool? isLoadingCities,
    String? errorMessage,
    String? citiesLoadedForState,
    bool clearError = false,
    bool clearSelectedCity = false,
    bool clearCities = false,
  }) {
    return LocationState(
      states: states ?? this.states,
      cities: clearCities ? const [] : (cities ?? this.cities),
      selectedState: selectedState ?? this.selectedState,
      selectedCity:
          clearSelectedCity ? null : (selectedCity ?? this.selectedCity),
      isLoadingStates: isLoadingStates ?? this.isLoadingStates,
      isLoadingCities: isLoadingCities ?? this.isLoadingCities,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      citiesLoadedForState: clearCities
          ? null
          : (citiesLoadedForState ?? this.citiesLoadedForState),
    );
  }

  @override
  List<Object?> get props => [
        states,
        cities,
        selectedState,
        selectedCity,
        isLoadingStates,
        isLoadingCities,
        errorMessage,
        citiesLoadedForState,
      ];
}

class LocationCubit extends Cubit<LocationState> {
  LocationCubit() : super(const LocationState());

  Future<void> loadStates({
    String country = 'India',
    bool force = false,
  }) async {
    // API removed. Only populate from map selection.
    if (state.selectedState != null && state.selectedState!.isNotEmpty) {
      emit(state.copyWith(states: [state.selectedState!], clearError: true));
    }
  }

  Future<void> selectState(
    String stateName, {
    String? preferredCity,
    bool clearCity = true,
  }) async {
    final trimmed = stateName.trim();
    if (trimmed.isEmpty || trimmed == 'State') {
      emit(
        state.copyWith(
          selectedState: null,
          clearSelectedCity: true,
          clearCities: true,
        ),
      );
      return;
    }

    final sameState = state.selectedState == trimmed;
    emit(
      state.copyWith(
        states: [trimmed],
        selectedState: trimmed,
        clearSelectedCity: clearCity && !sameState,
        clearCities: clearCity && !sameState,
        clearError: true,
      ),
    );

    await loadCitiesForState(trimmed, preferredCity: preferredCity);
  }

  Future<void> loadCitiesForState(
    String stateName, {
    String? preferredCity,
  }) async {
    final trimmed = stateName.trim();
    if (trimmed.isEmpty || trimmed == 'State') return;

    final preferred = preferredCity?.trim();
    final citiesList = preferred != null && preferred.isNotEmpty ? [preferred] : <String>[];

    emit(
      state.copyWith(
        cities: citiesList,
        citiesLoadedForState: trimmed,
        isLoadingCities: false,
        selectedCity: preferred,
        clearError: true,
      ),
    );
  }

  void selectCity(String cityName) {
    final trimmed = cityName.trim();
    if (trimmed.isEmpty || trimmed == 'City') {
      emit(state.copyWith(clearSelectedCity: true));
      return;
    }
    emit(state.copyWith(selectedCity: trimmed, clearError: true));
  }

  Future<void> hydrateFromSavedAddress({
    required String? stateName,
    required String? cityName,
  }) async {
    final savedState = stateName?.trim();
    if (savedState == null || savedState.isEmpty) return;

    await selectState(
      savedState,
      preferredCity: cityName,
      clearCity: false,
    );
  }

  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }
}
