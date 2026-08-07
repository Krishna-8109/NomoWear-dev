import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/features/profile/data/location_repository.dart';

/// UI state for Profile Address State / City-Village dropdowns.
///
/// CHANGE: Owns dynamic lists + loading/error so [EditProfileScreen] no longer
/// embeds hardcoded options and can swap data sources via [LocationRepository].
class LocationState extends Equatable {
  final List<String> states;
  final List<String> cities;
  final String? selectedState;
  final String? selectedCity;
  final bool isLoadingStates;
  final bool isLoadingCities;
  final String? errorMessage;

  /// Last state key for which [cities] were fetched (dedupes repeat calls).
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

/// Loads State list once; loads City/Village list per selected State with cache.
class LocationCubit extends Cubit<LocationState> {
  LocationCubit({LocationRepository? repository})
      : _repository = repository ?? LocalLocationRepository(),
        super(const LocationState());

  final LocationRepository _repository;

  /// In-flight / completed city fetches keyed by normalized state name.
  final Map<String, List<String>> _citiesCache = {};
  Future<void>? _statesFuture;
  String? _citiesRequestKey;

  /// Loads states once; concurrent callers share the same Future.
  /// Pass [force] to refetch after an empty/failed load.
  Future<void> loadStates({
    String country = 'India',
    bool force = false,
  }) async {
    if (!force && state.states.isNotEmpty && !state.isLoadingStates) return;
    if (_statesFuture != null) return _statesFuture;

    emit(
      state.copyWith(
        isLoadingStates: true,
        clearError: true,
      ),
    );

    _statesFuture = _doLoadStates(country);
    try {
      await _statesFuture;
    } finally {
      _statesFuture = null;
    }
  }

  Future<void> _doLoadStates(String country) async {
    try {
      final states = await _repository.getStates(country: country);
      if (isClosed) return;
      emit(
        state.copyWith(
          states: states,
          isLoadingStates: false,
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingStates: false,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingStates: false,
          errorMessage: 'Failed to load states',
        ),
      );
    }
  }

  /// Selects [stateName], clears previous city, and fetches cities for that state.
  /// Skips network when cities for the same state are already cached.
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

    // Cache hit — avoid duplicate API/local fetches (case-insensitive key).
    List<String>? cached;
    for (final entry in _citiesCache.entries) {
      if (entry.key.toLowerCase() == trimmed.toLowerCase()) {
        cached = entry.value;
        break;
      }
    }
    if (cached != null) {
      if (isClosed) return;
      emit(
        state.copyWith(
          cities: cached,
          citiesLoadedForState: trimmed,
          isLoadingCities: false,
          selectedCity: _resolvePreferredCity(cached, preferredCity),
          clearError: true,
        ),
      );
      return;
    }

    // Already loading this state — ignore duplicate triggers.
    if (state.isLoadingCities && _citiesRequestKey == trimmed) return;

    _citiesRequestKey = trimmed;
    emit(
      state.copyWith(
        isLoadingCities: true,
        clearCities: true,
        clearError: true,
      ),
    );

    try {
      final cities = await _repository.getCitiesForState(trimmed);
      _citiesCache[trimmed] = cities;
      if (isClosed) return;
      if (_citiesRequestKey != trimmed) return;

      emit(
        state.copyWith(
          cities: cities,
          citiesLoadedForState: trimmed,
          isLoadingCities: false,
          selectedCity: _resolvePreferredCity(cities, preferredCity),
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      if (isClosed) return;
      if (_citiesRequestKey != trimmed) return;
      emit(
        state.copyWith(
          isLoadingCities: false,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      if (_citiesRequestKey != trimmed) return;
      emit(
        state.copyWith(
          isLoadingCities: false,
          errorMessage: 'Failed to load cities',
        ),
      );
    }
  }

  void selectCity(String cityName) {
    final trimmed = cityName.trim();
    if (trimmed.isEmpty || trimmed == 'City') {
      emit(state.copyWith(clearSelectedCity: true));
      return;
    }
    emit(state.copyWith(selectedCity: trimmed, clearError: true));
  }

  /// Prefill for edit-profile: India is fixed in UI; restore saved state/city.
  Future<void> hydrateFromSavedAddress({
    required String? stateName,
    required String? cityName,
  }) async {
    await loadStates();
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

  String? _resolvePreferredCity(List<String> cities, String? preferredCity) {
    final preferred = preferredCity?.trim();
    if (preferred == null || preferred.isEmpty || preferred == 'City') {
      return state.selectedCity;
    }
    // Case-insensitive match so saved profile values still pre-select.
    for (final city in cities) {
      if (city.toLowerCase() == preferred.toLowerCase()) return city;
    }
    // Keep saved label visible even if not in the current list yet.
    return preferred;
  }
}
