import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/auth/data/models/customer.dart';
import 'package:nomowear/features/profile/data/profile_date_utils.dart';
import 'package:nomowear/core/utils/mobile_number_utils.dart';
import 'package:nomowear/features/profile/data/profile_measurement_utils.dart';
import 'package:nomowear/features/profile/data/profile_photo_file.dart';
import 'package:nomowear/features/profile/data/profile_completion_helper.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';
import 'package:nomowear/features/profile/presentation/bloc/location_cubit.dart';

class EditProfileScreen extends StatefulWidget {
  final bool showSkip;
  final bool popOnSave;

  const EditProfileScreen({
    Key? key,
    this.showSkip = true,
    this.popOnSave = false,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedCountry = 'Country';
  String _selectedState = 'State';
  String _selectedCity = 'City';
  String? _activeDropdown;
  Uint8List? _profileImageBytes;
  String? _profilePhotoFilename;
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey _countryFieldKey = GlobalKey();
  final GlobalKey _stateFieldKey = GlobalKey();
  final GlobalKey _cityFieldKey = GlobalKey();
  final GlobalKey _heightFieldKey = GlobalKey();
  final GlobalKey _weightFieldKey = GlobalKey();

  final ProfileRepository _profileRepository = ProfileRepository();
  final AuthStorage _authStorage = AuthStorage();
  // CHANGE: State/City lists come from LocationCubit (swappable repository),
  // not from hardcoded dropdown options in this screen.
  late final LocationCubit _locationCubit;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasAuthToken = false;
  String? _profilePhotoUrl;
  String? _addressError;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddressFromMap;

  String? _selectedHeight;
  String? _selectedWeight;
  String? _selectedBodyType = 'Athletic';

  static const List<String> _heightOptions = [
    '5\'7"',
    '5\'8"',
    '5\'9"',
    '5\'10"',
    '5\'11"',
    '6\'0"',
  ];
  static const List<String> _weightOptions = [
    '65 kg',
    '70 kg',
    '75 kg',
    '80 kg',
    '85 kg',
    '90 kg',
  ];

  ProfilePhotoFile? get _pickedPhotoFile {
    if (_profileImageBytes == null) return null;
    return ProfilePhotoFile(
      bytes: _profileImageBytes!,
      filename: _profilePhotoFilename ?? 'profile.jpg',
    );
  }

  @override
  void initState() {
    super.initState();
    // Default: LocalLocationRepository. Switch to ApiLocationRepository when
    // ApiConstants.statesPath / citiesPath are set.
    _locationCubit = LocationCubit();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final token = await _authStorage.getAuthToken();
    _hasAuthToken = token != null && token.isNotEmpty;

    // Country is fixed as India for Profile Address (no free-country picker).
    _selectedCountry = 'India';

    String? savedState;
    String? savedCity;

    if (_hasAuthToken) {
      try {
        final profile = await _profileRepository.getProfile();
        if (!mounted) return;
        _applyProfile(profile);
        final address = profile.primaryAddress;
        savedState = address?.state;
        savedCity = address?.city;
      } on ApiException catch (e) {
        if (!mounted) return;
        _showMessage(e.message);
      } catch (_) {
        if (!mounted) return;
        _showMessage('Failed to load profile');
      }
    } else {
      final mobile = await _authStorage.getMobileNumber();
      if (mobile != null && mobile.isNotEmpty) {
        _mobileController.text =
            MobileNumberUtils.normalizeIndianMobile(mobile) ?? mobile;
      }
    }

    // Load states (and cities when editing) via Cubit — avoids duplicate fetches.
    try {
      await _locationCubit.hydrateFromSavedAddress(
        stateName: savedState,
        cityName: savedCity,
      );
      if (!mounted) return;
      final loc = _locationCubit.state;
      if (loc.selectedState != null && loc.selectedState!.isNotEmpty) {
        _selectedState = loc.selectedState!;
      }
      if (loc.selectedCity != null && loc.selectedCity!.isNotEmpty) {
        _selectedCity = loc.selectedCity!;
      }
    } catch (_) {
      // Cubit emits errorMessage; BlocListener shows SnackBar.
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _applyProfile(Customer profile) {
    _fullNameController.text = profile.fullName ?? '';
    _mobileController.text =
        MobileNumberUtils.normalizeIndianMobile(profile.mobile) ??
        profile.mobile;
    _emailController.text = profile.email ?? '';
    _dobController.text = ProfileDateUtils.toDisplayDate(profile.dob);
    _profilePhotoUrl = profile.profilePhoto;

    // CHANGE: Always show India; State/City are prefilled via LocationCubit.
    _selectedCountry = 'India';

    final address = profile.primaryAddress;
    if (address != null) {
      if (address.state != null && address.state!.isNotEmpty) {
        _selectedState = address.state!;
      }
      if (address.city != null && address.city!.isNotEmpty) {
        _selectedCity = address.city!;
      }
      if (address.pincode != null && address.pincode!.isNotEmpty) {
        _pincodeController.text = address.pincode!;
      }
      if (address.fullAddress != null && address.fullAddress!.isNotEmpty) {
        _addressController.text = address.fullAddress!;
        _selectedAddressFromMap = address.fullAddress!;
      }
      _selectedLatitude = address.latitude;
      _selectedLongitude = address.longitude;
    }

    _selectedHeight = ProfileMeasurementUtils.heightFromApi(profile.height);
    _selectedWeight = profile.weight;
    if (profile.bodySkinType != null && profile.bodySkinType!.isNotEmpty) {
      _selectedBodyType = profile.bodySkinType;
    }
  }

  ({String? height, String? weight, String? bodySkinType}) _measurementsPayload() {
    return (
      height: ProfileMeasurementUtils.heightToApi(_selectedHeight),
      weight: _selectedWeight,
      bodySkinType: _selectedBodyType,
    );
  }

  ({
    String? country,
    String? state,
    String? city,
    String? pincode,
    String? fullAddress,
    double? latitude,
    double? longitude,
  })
      _addressPayload() {
    return (
      country: _selectedCountry != 'Country' ? _selectedCountry : null,
      state: _selectedState != 'State' ? _selectedState : null,
      city: _selectedCity != 'City' ? _selectedCity : null,
      pincode: _pincodeController.text.trim().isEmpty
          ? null
          : _pincodeController.text.trim(),
      fullAddress: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
    );
  }

  Future<void> _openAddressMapPicker() async {
    if (kDebugMode) {
      debugPrint('[PROFILE_LOCATION] MAP_OPEN');
    }
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.selectAddressScreen,
      arguments: {
        if (_selectedLatitude != null) 'latitude': _selectedLatitude,
        if (_selectedLongitude != null) 'longitude': _selectedLongitude,
      },
    );
    if (!mounted || result is! Map) return;

    double? readCoord(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final selectedAddress = result['locationDetails']?.toString().trim();
    final lat = readCoord(result['latitude']);
    final lng = readCoord(result['longitude']);
    if (selectedAddress == null || selectedAddress.isEmpty) return;

    final country = result['country']?.toString().trim();
    final stateStr = result['state']?.toString().trim();
    final city = result['city']?.toString().trim();
    final pincode = result['pincode']?.toString().trim();

    setState(() {
      _addressController.text = selectedAddress;
      _selectedAddressFromMap = selectedAddress;
      _selectedLatitude = lat;
      _selectedLongitude = lng;
      _addressError = null;

      if (country != null && country.isNotEmpty) {
        _selectedCountry = country;
      }
      if (pincode != null && pincode.isNotEmpty) {
        _pincodeController.text = pincode;
      }
    });

    if (stateStr != null && stateStr.isNotEmpty) {
      await _locationCubit.selectState(stateStr, preferredCity: city, clearCity: true);
      if (!mounted) return;
      final locState = _locationCubit.state;
      setState(() {
        if (locState.selectedState != null && locState.selectedState!.isNotEmpty) {
          _selectedState = locState.selectedState!;
        }
        if (locState.selectedCity != null && locState.selectedCity!.isNotEmpty) {
          _selectedCity = locState.selectedCity!;
        }
      });
    }

    if (kDebugMode) {
      debugPrint('[PROFILE_LOCATION] SELECTED');
      debugPrint('latitude=$_selectedLatitude');
      debugPrint('longitude=$_selectedLongitude');
      debugPrint('address=$selectedAddress');
    }
  }

  Future<void> _saveChanges() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final dobDisplay = _dobController.text.trim();

    if (fullName.isEmpty) {
      _showMessage('Please enter full name');
      return;
    }
    final mobile = MobileNumberUtils.normalizeIndianMobile(
      _mobileController.text.trim(),
    );
    if (mobile == null) {
      _showMessage('Please enter a valid 10-digit mobile number');
      return;
    }
    if (email.isEmpty) {
      _showMessage('Please enter email');
      return;
    }
    if (dobDisplay.isEmpty) {
      _showMessage('Please select date of birth');
      return;
    }

    final apiDob = ProfileRepository.dobForApi(dobDisplay);
    if (apiDob == null) {
      _showMessage('Please enter date of birth as DD/MM/YYYY');
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      setState(() {
        _addressError =
            "You didn't enter Address. Please enter your address.";
      });
      return;
    }

    setState(() {
      _addressError = null;
      _isSaving = true;
    });

    final address = _addressPayload();
    final measurements = _measurementsPayload();

    try {
      if (_hasAuthToken) {
        await _profileRepository.updateProfile(
          UpdateProfileInput(
            fullName: fullName,
            dob: apiDob,
            businessEmail: email,
            mobileNumber: mobile,
            country: address.country,
            state: address.state,
            city: address.city,
            pincode: address.pincode,
            fullAddress: address.fullAddress,
            latitude: address.latitude,
            longitude: address.longitude,
            height: measurements.height,
            weight: measurements.weight,
            bodySkinType: measurements.bodySkinType,
            profilePhoto: _pickedPhotoFile,
          ),
        );
        final refreshed = await _profileRepository.getProfile();
        if (mounted) _applyProfile(refreshed);
      } else {
        await _profileRepository.register(
          RegisterProfileInput(
            fullName: fullName,
            mobile: mobile,
            businessEmail: email,
            dob: apiDob,
            profilePhoto: _pickedPhotoFile,
            country: address.country,
            state: address.state,
            city: address.city,
            pincode: address.pincode,
            fullAddress: address.fullAddress,
            latitude: address.latitude,
            longitude: address.longitude,
            height: measurements.height,
            weight: measurements.weight,
            bodySkinType: measurements.bodySkinType,
          ),
        );
        _hasAuthToken = true;
      }

      if (!mounted) return;
      setState(() {});
      final refreshed = _hasAuthToken
          ? await _profileRepository.getProfile()
          : null;
      if (refreshed?.profilePhoto != null && _pickedPhotoFile != null) {
        PaintingBinding.instance.imageCache.evict(NetworkImage(refreshed!.profilePhoto!));
      }
      final isComplete = refreshed != null
          ? ProfileCompletionHelper.isProfileComplete(refreshed)
          : true;
      await _authStorage.markProfileComplete(isComplete);
      _showMessage('Profile saved successfully');
      if (widget.popOnSave) {
        Navigator.pop(context, isComplete);
        return;
      }
      if (kDebugMode) {
        debugPrint('[PROFILE_LOCATION] PROFILE_UPDATED');
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.homeScreen,
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _locationCubit.close();
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CHANGE: Provide LocationCubit without altering visual layout.
    return BlocProvider.value(
      value: _locationCubit,
      child: BlocListener<LocationCubit, LocationState>(
        listenWhen: (previous, current) =>
            current.errorMessage != null &&
            current.errorMessage != previous.errorMessage,
        listener: (context, state) {
          final message = state.errorMessage;
          if (message == null || message.isEmpty) return;
          _showMessage(message);
          context.read<LocationCubit>().clearError();
        },
        child: _buildScaffold(),
      ),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D18),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Profile',
          style: TextStyle(
            color: const Color(0xFFE6C279),
            fontSize: 15.fSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: widget.showSkip
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFE6C279)),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (widget.showSkip)
            TextButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.homeScreen,
                  (route) => false,
                );
              },
              child: Row(
                children: [
                  Text(
                    'Skip',
                    style: CustomTextStyles.openSansSemiBold
                        .copyWith(color: AppColours.primary, fontSize: 12),
                  ),
                  SizedBox(width: 5,),
                  SvgPicture.asset(IconConstant.skip)
                ],
              ),
            ),
          SizedBox(width: 6.w),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const EditProfileShimmer()
            : SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topDivider(),
              SizedBox(height: 14.h),
              _buildProfileImage(),
              SizedBox(height: 14.h),
              _fieldLabel('FULL NAME *'),
              _textField(_fullNameController, hint: 'Enter Full Name'),
              _fieldLabel('DATE OF BIRTH *'),
              _textField(
                _dobController,
                hint: 'DD/MM/YYYY',
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  color: const Color(0xFFE6C279),
                  size: 16.fSize,
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
              ),
              _fieldLabel('GENDER *'),
              _genderRow(),
              SizedBox(height: 6.h),
              _fieldLabel('MOBILE NUMBER *'),
              _textField(
                _mobileController,
                hint: 'Enter Mobile Number',
                readOnly: _hasAuthToken,
              ),
              _fieldLabel('EMAIL *'),
              _textField(_emailController, hint: 'Enter Email'),
              Padding(
                padding: EdgeInsets.only(bottom: 8.h, top: 20.h),
                child: Row(
                  children: [
                    Icon(Icons.home_outlined, color: AppColours.primary, size: 18),
                    SizedBox(width: 6.w),
                    Text(
                      'SELECT ADDRESS',
                      style: CustomTextStyles.montserratBold.copyWith(
                        color: AppColours.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: AppColours.primary.withOpacity(0.15),
                thickness: 1,
                height: 1,
              ),
              SizedBox(height: 16.h),
              GestureDetector(
                onTap: _openAddressMapPicker,
                child: DottedBorder(
                  color: AppColours.primary,
                  strokeWidth: 1.2,
                  dashPattern: const [4, 4],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, color: AppColours.primary, size: 18),
                      SizedBox(width: 8.w),
                      Text(
                        'SELECT ADDRESS ON MAP',
                        style: CustomTextStyles.openSansSemiBold.copyWith(
                          color: AppColours.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _fieldLabel('RESIDENTIAL ADDRESS'),
              _residentialAddressRow(),
              _fieldLabel('PINCODE *'),
              _textField(_pincodeController, hint: 'Enter Pincode'),
              _fieldLabel('ENTER FULL ADDRESS'),
              _textField(
                _addressController,
                maxLines: 2,
                hint: 'Enter your full address',
                onChanged: (value) {
                  if (_addressError != null) {
                    setState(() => _addressError = null);
                  }
                  if (_selectedAddressFromMap != null &&
                      value.trim() != _selectedAddressFromMap!.trim()) {
                    _selectedLatitude = null;
                    _selectedLongitude = null;
                  }
                },
              ),
              if (_addressError != null) ...[
                SizedBox(height: 8.h),
                _addressAlert(_addressError!),
              ],
              SizedBox(height: 20.h),
              _optionalDetailsSection(),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.maxFinite,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE6C279),
                    disabledBackgroundColor:
                        const Color(0xFFE6C279).withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: CustomTextStyles.montserratBold.copyWith(
                            color: AppColours.black,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topDivider() {
    return Container(
      height: 2,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFE6C27A).withOpacity(0.15),
            Color(0xFFE6C27A),
            Color(0xFFE6C27A).withOpacity(0.15),
          ],
        ),
      ),
    );

  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, top: 10.h),
      child: Text(
        label,
        style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary,fontSize: 14),
      ),
    );
  }

  Widget _optionalDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT DETAILS (OPTIONAL)',
          style: CustomTextStyles.montserratBold.copyWith(
            color: AppColours.primary,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HEIGHT',
                    style: CustomTextStyles.openSansBold.copyWith(
                      fontSize: 12,
                      color: AppColours.primary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _optionalPickerField(
                    id: 'height',
                    anchorKey: _heightFieldKey,
                    value: _selectedHeight,
                    hint: 'Select height',
                    items: _heightOptions,
                    onSelected: (val) => setState(() => _selectedHeight = val),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEIGHT',
                    style: CustomTextStyles.openSansBold.copyWith(
                      fontSize: 12,
                      color: AppColours.primary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _optionalPickerField(
                    id: 'weight',
                    anchorKey: _weightFieldKey,
                    value: _selectedWeight,
                    hint: 'Select weight',
                    items: _weightOptions,
                    onSelected: (val) => setState(() => _selectedWeight = val),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Text(
          'BODY TYPE',
          style: CustomTextStyles.openSansSemiBold.copyWith(
            fontSize: 12,
            color: AppColours.primary,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            _bodyTypeCard('Slim', IconConstant.slim),
            SizedBox(width: 12.w),
            _bodyTypeCard('Athletic', IconConstant.curvy),
            SizedBox(width: 12.w),
            _bodyTypeCard('Regular', IconConstant.regular),
          ],
        ),
      ],
    );
  }

  Widget _optionalPickerField({
    required String id,
    required GlobalKey anchorKey,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) {
    final isOpen = _activeDropdown == id;
    final displayValue = value ?? hint;
    const borderColor = Color(0xFFE6C279);

    return GestureDetector(
      onTap: () => _openOptionalDropdown(
        id: id,
        anchorKey: anchorKey,
        items: items,
        currentValue: value,
        onSelected: onSelected,
      ),
      child: AnimatedContainer(
        key: anchorKey,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(26, 28, 35, 1),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(8),
            bottom: isOpen ? Radius.zero : const Radius.circular(8),
          ),
          border: Border(
            top: BorderSide(color: borderColor.withValues(alpha: 0.65)),
            left: BorderSide(color: borderColor.withValues(alpha: 0.65)),
            right: BorderSide(color: borderColor.withValues(alpha: 0.65)),
            bottom: isOpen
                ? BorderSide.none
                : BorderSide(color: borderColor.withValues(alpha: 0.65)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CustomTextStyles.openSansBold.copyWith(
                  fontSize: 10.fSize,
                  color: value == null ? AppColours.hintcolor : AppColours.secondary,
                ),
              ),
            ),
            AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: SvgPicture.asset(
                IconConstant.dropdown,
                height: 6,
                width: 6,
                color: borderColor.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOptionalDropdown({
    required String id,
    required GlobalKey anchorKey,
    required List<String> items,
    required String? currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    setState(() => _activeDropdown = id);
    final picked = await _showAddressDropdownMenu(
      anchorKey: anchorKey,
      options: items,
      currentValue: currentValue ?? '',
    );
    if (!mounted) return;
    setState(() => _activeDropdown = null);
    if (picked != null) onSelected(picked);
  }

  Widget _bodyTypeCard(String label, String iconPath) {
    final isActive = _selectedBodyType == label;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedBodyType = isActive ? null : label;
        }),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1115),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColours.primary,
              width: isActive ? 2.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                decoration: BoxDecoration(
                  color: isActive ? AppColours.primary.withOpacity(0.15) : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: SvgPicture.asset(
                  iconPath,
                  height: 44.h,
                  colorFilter: ColorFilter.mode(
                    isActive ? AppColours.primary : Colors.white70,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              Container(height: 1, color: AppColours.primary),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: isActive ? AppColours.primary : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isActive ? Colors.black : AppColours.secondary,
                    fontSize: 12.fSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController? controller, {
    int maxLines = 1,
    String? hint,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      style: CustomTextStyles.openSansBold.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:CustomTextStyles.openSansSemiBold.copyWith(fontSize: 14,color: AppColours.hintcolor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF1A1C23),
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColours.primary,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFE6C279),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF16181D),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Color(0xFFE6C279)),
                  title: Text(
                    'Choose from gallery',
                    style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 14, color: AppColours.secondary),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFE6C279)),
                  title: Text(
                    'Take a photo',
                    style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 14, color: AppColours.secondary),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final name = file.name.trim();
      setState(() {
        _profileImageBytes = bytes;
        _profilePhotoFilename = name.isNotEmpty ? name : 'profile.jpg';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update photo: $e')),
      );
    }
  }

  Widget _buildProfileImage() {
    final border = Border.all(color: const Color(0xFFE6C279), width: 1.2);
    return Center(
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickProfileImage,
              customBorder: const CircleBorder(),
              child: Ink(
                height: 84.h,
                width: 84.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: border,
                ),
                child: ClipOval(
                  child: _profileImageBytes != null
                      ? Image.memory(
                          _profileImageBytes!,
                          fit: BoxFit.cover,
                          width: 84.w,
                          height: 84.h,
                        )
                      : _profilePhotoUrl != null &&
                              _profilePhotoUrl!.startsWith('http')
                          ? Image.network(
                              _profilePhotoUrl!,
                              fit: BoxFit.cover,
                              width: 84.w,
                              height: 84.h,
                              errorBuilder: (_, __, ___) => Image.asset(
                                ImageConstant.homeScreenImg2,
                                fit: BoxFit.cover,
                                width: 84.w,
                                height: 84.h,
                              ),
                            )
                          : Image.asset(
                          ImageConstant.homeScreenImg2,
                          fit: BoxFit.cover,
                          width: 84.w,
                          height: 84.h,
                        ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          InkWell(
            onTap: _pickProfileImage,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    IconConstant.iconEdit,
                    height: 14.w,
                    width: 14.w,
                    color: const Color(0xFFE6C279),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Upload Photo',
                    style: CustomTextStyles.openSansMedium.copyWith(fontSize: 14, color: AppColours.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderRow() {
    return Row(
      children: [
        _genderOption('Male'),
        SizedBox(width: 16.w),
        _genderOption('Female'),
      ],
    );
  }


  Widget _genderOption(String value) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 16.w,
            height: 16.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColours.secondary : AppColours.secondary,
                width: 1,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 8.w,
                      height: 8.h,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColours.secondary,
                      ),
                    ),
                  )
                : null,
          ),
          SizedBox(width: 8.w),
          Text(
            value,
            style: CustomTextStyles.openSansBold.copyWith(
              fontSize: 14,
              color: isSelected ? AppColours.secondary : AppColours.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showAddressDropdownMenu({
    required GlobalKey anchorKey,
    required List<String> options,
    required String currentValue,
  }) async {
    final anchorContext = anchorKey.currentContext;
    if (anchorContext == null) return null;

    final renderBox = anchorContext.findRenderObject()! as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final fieldSize = renderBox.size;
    final borderColor = const Color(0xFFE6C279).withValues(alpha: 0.65);

    return showMenu<String>(
      context: context,
      color: const Color(0xFF111523),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        side: BorderSide(color: borderColor),
      ),
      constraints: BoxConstraints.tightFor(width: fieldSize.width),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + fieldSize.height,
        overlayBox.size.width - offset.dx - fieldSize.width,
        overlayBox.size.height - offset.dy - fieldSize.height,
      ),
      items: options
          .map(
            (option) => PopupMenuItem<String>(
              value: option,
              height: 36.h,
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 10.fSize,
                  fontWeight: option == currentValue ? FontWeight.w700 : FontWeight.w400,
                  color: option == currentValue ? AppColours.primary : AppColours.secondary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openAddressDropdown({
    required String id,
    required GlobalKey anchorKey,
    required String hint,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    var menuOptions = options.where((o) => o != hint).toList();
    if (menuOptions.isEmpty) {
      _showMessage('Please select an address from the map first.');
      return;
    }

    setState(() => _activeDropdown = id);
    final picked = await _showAddressDropdownMenu(
      anchorKey: anchorKey,
      options: menuOptions,
      currentValue: currentValue == hint ? '' : currentValue,
    );
    if (!mounted) return;
    setState(() => _activeDropdown = null);
    if (picked != null) onSelected(picked);
  }

  Widget _residentialAddressRow() {
    // CHANGE: Same Row + dropdown widgets; options come from LocationCubit.
    return BlocBuilder<LocationCubit, LocationState>(
      buildWhen: (previous, current) =>
          previous.states != current.states ||
          previous.cities != current.cities ||
          previous.citiesLoadedForState != current.citiesLoadedForState ||
          previous.isLoadingStates != current.isLoadingStates ||
          previous.isLoadingCities != current.isLoadingCities,
      builder: (context, locationState) {
        final countryReady = _selectedCountry == 'India';
        final stateReady = _selectedState != 'State';
        final stateOptions = locationState.states;
        // Only cities belonging to the selected state (Cubit clears on change).
        final loadedFor = locationState.citiesLoadedForState?.toLowerCase();
        final selectedKey = _selectedState.toLowerCase();
        final cityOptions =
            loadedFor != null && loadedFor == selectedKey
                ? locationState.cities
                : const <String>[];

        return Row(
          children: [
            Expanded(
              child: _addressDropdownField(
                id: 'country',
                anchorKey: _countryFieldKey,
                value: _selectedCountry,
                hint: 'Country',
                // Fixed to India — single option, same as before.
                options: const ['India'],
                onSelected: (v) => setState(() {
                  _selectedCountry = v;
                  if (v != 'India') {
                    _selectedState = 'State';
                    _selectedCity = 'City';
                  }
                }),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _addressDropdownField(
                id: 'state',
                anchorKey: _stateFieldKey,
                value: locationState.isLoadingStates && stateOptions.isEmpty
                    ? 'State'
                    : _selectedState,
                hint: 'State',
                enabled: countryReady && !locationState.isLoadingStates,
                options: stateOptions,
                onSelected: (v) async {
                  // Clear previous City/Village whenever State changes.
                  setState(() {
                    _selectedState = v;
                    _selectedCity = 'City';
                  });
                  await context.read<LocationCubit>().selectState(v);
                  if (!mounted) return;
                  setState(() {});
                },
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _addressDropdownField(
                id: 'city',
                anchorKey: _cityFieldKey,
                value: locationState.isLoadingCities &&
                        _selectedCity == 'City'
                    ? 'City'
                    : _selectedCity,
                hint: 'City',
                enabled: stateReady && !locationState.isLoadingCities,
                options: cityOptions,
                onSelected: (v) {
                  setState(() => _selectedCity = v);
                  context.read<LocationCubit>().selectCity(v);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _addressDropdownField({
    required String id,
    required GlobalKey anchorKey,
    required String value,
    required String hint,
    required List<String> options,
    required ValueChanged<String> onSelected,
    bool enabled = true,
  }) {
    final isOpen = _activeDropdown == id;
    final borderColor = enabled
        ? const Color(0xFFE6C279).withValues(alpha: 0.65)
        : const Color(0xFFE6C279).withValues(alpha: 0.25);

    return GestureDetector(
      onTap: enabled
          ? () => _openAddressDropdown(
                id: id,
                anchorKey: anchorKey,
                hint: hint,
                options: options,
                currentValue: value,
                onSelected: onSelected,
              )
          : null,
      child: AnimatedContainer(
        key: anchorKey,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(26, 28, 35, 1),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(8),
            bottom: isOpen ? Radius.zero : const Radius.circular(8),
          ),
          // CHANGE: Keep BorderSide.color uniform when open (width 0 instead of
          // BorderSide.none). Flutter asserts if borderRadius + non-uniform colors.
          border: Border(
            top: BorderSide(color: borderColor),
            left: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor, width: isOpen ? 0 : 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CustomTextStyles.openSansBold.copyWith(
                  fontSize: 10.fSize,
                  color: value == hint ? AppColours.hintcolor : AppColours.secondary,
                ),
              ),
            ),
            AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: SvgPicture.asset(
                IconConstant.dropdown,
                height: 6,
                width: 6,
                color: enabled
                    ? const Color(0xFFE6C279)
                    : const Color(0xFFE6C279).withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressAlert(String message) {
    return Container(
      width: double.maxFinite,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C23),
        border: Border.all(color: const Color(0xFFE6C279).withOpacity(0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          message,
          style: CustomTextStyles.openSansSemiBold.copyWith(
            fontSize: 12,
            color: AppColours.primary,
          ),
        ),
      ),
    );
  }
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE6C279),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1C23),
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE6C279),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }
}
