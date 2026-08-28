import 'package:shared_preferences/shared_preferences.dart';

/// Isolates carts across home entry flows.
/// Switching modes clears local + remote cart; same mode keeps it.
enum CheckoutBookingMode {
  unset,
  subscription,
  oneTimeWardrobe,
  essentials,
}

class CheckoutSession {
  CheckoutSession._();

  static final CheckoutSession instance = CheckoutSession._()..restore();

  String? addressId;
  String? addressTitle;
  String? addressLines;
  double? addressLatitude;
  double? addressLongitude;
  DateTime? deliveryDate;
  String? deliveryTime;
  bool useSubscriptionBooking = false;
  /// When true, new wardrobe garments are paid rental items (existing
  /// subscription garments in cart are unchanged).
  bool continueWithoutMembership = false;
  CheckoutBookingMode bookingMode = CheckoutBookingMode.unset;
  String? gender;
  String? bodyType;
  String? kitType;
  /// Home wardrobe category currently locked for non-sub single-category rule.
  String? wardrobeCategory;
  /// Stable Home category ID for the active unpaid non-subscription booking.
  String? activeNonSubscriptionCategoryId;
  bool _didRestore = false;
  Future<void>? _restoreFuture;

  void setDelivery({
    String? addressId,
    String? addressTitle,
    String? addressLines,
    double? addressLatitude,
    double? addressLongitude,
    DateTime? deliveryDate,
    String? deliveryTime,
    bool? useSubscriptionBooking,
    bool? continueWithoutMembership,
    CheckoutBookingMode? bookingMode,
    String? gender,
    String? bodyType,
    String? kitType,
    String? wardrobeCategory,
    String? activeNonSubscriptionCategoryId,
  }) {
    if (addressId != null) this.addressId = addressId;
    if (addressTitle != null) this.addressTitle = addressTitle;
    if (addressLines != null) this.addressLines = addressLines;
    if (addressLatitude != null) this.addressLatitude = addressLatitude;
    if (addressLongitude != null) this.addressLongitude = addressLongitude;
    if (deliveryDate != null) this.deliveryDate = deliveryDate;
    if (deliveryTime != null) this.deliveryTime = deliveryTime;
    if (useSubscriptionBooking != null) {
      this.useSubscriptionBooking = useSubscriptionBooking;
    }
    if (continueWithoutMembership != null) {
      this.continueWithoutMembership = continueWithoutMembership;
    }
    if (bookingMode != null) {
      this.bookingMode = bookingMode;
      // Only auto-sync useSubscriptionBooking when the caller did not set it
      // explicitly — mixed carts (subscription rental + BUY) need both lanes.
      if (useSubscriptionBooking == null) {
        if (bookingMode == CheckoutBookingMode.subscription) {
          this.useSubscriptionBooking = true;
        } else if (bookingMode == CheckoutBookingMode.oneTimeWardrobe ||
            bookingMode == CheckoutBookingMode.essentials) {
          this.useSubscriptionBooking = false;
        }
      }
    }
    if (gender != null) this.gender = gender;
    if (bodyType != null) this.bodyType = bodyType;
    if (kitType != null) this.kitType = kitType;
    if (wardrobeCategory != null) this.wardrobeCategory = wardrobeCategory;
    if (activeNonSubscriptionCategoryId != null) {
      this.activeNonSubscriptionCategoryId =
          activeNonSubscriptionCategoryId.trim();
    }
    _persist();
  }

  Future<void> restore() async {
    if (_didRestore) return;
    if (_restoreFuture != null) {
      await _restoreFuture;
      return;
    }
    _restoreFuture = _restoreOnce();
    try {
      await _restoreFuture;
    } finally {
      _restoreFuture = null;
    }
  }

  String? get apiDeliveryDate {
    final date = deliveryDate;
    if (date == null) return null;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String get deliveryDateDisplay {
    final date = deliveryDate;
    if (date == null) return 'Not selected';
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[date.weekday - 1];
    final suffix = _daySuffix(date.day);
    final time = deliveryTime?.trim();
    if (time != null && time.isNotEmpty) {
      return '$weekday, ${date.day}$suffix ${months[date.month - 1]}   $time';
    }
    return '$weekday, ${date.day}$suffix ${months[date.month - 1]}';
  }

  String get addressDisplay =>
      addressLines?.trim().isNotEmpty == true
          ? addressLines!.trim()
          : 'No delivery address selected';

  /// Clears delivery address / kit type fields only. Does not reset booking
  /// path flags or [WardrobeBookingSession] state.
  void clearDeliveryDetails() {
    addressId = null;
    addressTitle = null;
    addressLines = null;
    addressLatitude = null;
    addressLongitude = null;
    deliveryDate = null;
    deliveryTime = null;
    gender = null;
    bodyType = null;
    kitType = null;
    _persist();
  }

  void clear() {
    addressId = null;
    addressTitle = null;
    addressLines = null;
    addressLatitude = null;
    addressLongitude = null;
    deliveryDate = null;
    deliveryTime = null;
    useSubscriptionBooking = false;
    continueWithoutMembership = false;
    bookingMode = CheckoutBookingMode.unset;
    gender = null;
    bodyType = null;
    kitType = null;
    wardrobeCategory = null;
    activeNonSubscriptionCategoryId = null;
    _clearPersisted();
  }

  /// Clears only the non-sub wardrobe category lock (keeps address/date).
  void clearWardrobeCategoryLock() {
    wardrobeCategory = null;
    activeNonSubscriptionCategoryId = null;
    _persist();
  }

  /// Clears only temporary booking-mode selections.
  /// Keeps address/date details intact.
  void clearBookingModeSelection() {
    useSubscriptionBooking = false;
    continueWithoutMembership = false;
    bookingMode = CheckoutBookingMode.unset;
    wardrobeCategory = null;
    activeNonSubscriptionCategoryId = null;
    _persist();
  }

  /// Clears the booking mode ONLY if it is currently set to essentials.
  /// Does NOT clear WITHOUT_MEMBERSHIP state or other unrelated flags.
  void clearEssentialsBookingMode() {
    if (bookingMode == CheckoutBookingMode.essentials) {
      bookingMode = CheckoutBookingMode.unset;
      wardrobeCategory = null;
      _persist();
    }
  }

  /// Locks one-time (non-subscription) booking to a single home wardrobe category.
  void lockNonSubWardrobeCategory(String category, {String? categoryId}) {
    final value = category.trim();
    if (value.isEmpty) return;
    wardrobeCategory = value;
    final id = categoryId?.trim();
    if (id != null && id.isNotEmpty) {
      activeNonSubscriptionCategoryId = id;
    }
    useSubscriptionBooking = false;
    _persist();
  }

  Future<void> _restoreOnce() async {
    final prefs = await SharedPreferences.getInstance();
    addressId = prefs.getString(_kAddressId);
    addressTitle = prefs.getString(_kAddressTitle);
    addressLines = prefs.getString(_kAddressLines);
    final latStr = prefs.getString(_kAddressLatitude);
    final lngStr = prefs.getString(_kAddressLongitude);
    addressLatitude = latStr != null ? double.tryParse(latStr) : null;
    addressLongitude = lngStr != null ? double.tryParse(lngStr) : null;
    deliveryTime = prefs.getString(_kDeliveryTime);
    // Persist continueWithoutMembership and category lock so WITHOUT_MEMBERSHIP state survives refresh
    continueWithoutMembership = prefs.getBool(_kContinueWithoutMembership) ?? false;
    useSubscriptionBooking = prefs.getBool(_kUseSubscriptionBooking) ?? false;
    final savedMode = prefs.getString(_kBookingMode);
    bookingMode = CheckoutBookingMode.values.firstWhere(
      (e) => e.name == savedMode,
      orElse: () => CheckoutBookingMode.unset,
    );
    
    gender = prefs.getString(_kGender);
    bodyType = prefs.getString(_kBodyType);
    kitType = prefs.getString(_kKitType);
    
    wardrobeCategory = prefs.getString(_kWardrobeCategory);
    activeNonSubscriptionCategoryId = prefs.getString(_kActiveNonSubscriptionCategoryId);

    final deliveryEpoch = prefs.getInt(_kDeliveryDateEpochMs);
    if (deliveryEpoch != null && deliveryEpoch > 0) {
      deliveryDate = DateTime.fromMillisecondsSinceEpoch(deliveryEpoch);
    } else {
      deliveryDate = null;
    }
    _didRestore = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();

    if (addressId?.trim().isNotEmpty == true) {
      await prefs.setString(_kAddressId, addressId!.trim());
    } else {
      await prefs.remove(_kAddressId);
    }

    if (addressTitle?.trim().isNotEmpty == true) {
      await prefs.setString(_kAddressTitle, addressTitle!.trim());
    } else {
      await prefs.remove(_kAddressTitle);
    }

    if (addressLines?.trim().isNotEmpty == true) {
      await prefs.setString(_kAddressLines, addressLines!.trim());
    } else {
      await prefs.remove(_kAddressLines);
    }

    if (addressLatitude != null) {
      await prefs.setString(_kAddressLatitude, addressLatitude.toString());
    } else {
      await prefs.remove(_kAddressLatitude);
    }
    if (addressLongitude != null) {
      await prefs.setString(_kAddressLongitude, addressLongitude.toString());
    } else {
      await prefs.remove(_kAddressLongitude);
    }

    if (deliveryTime?.trim().isNotEmpty == true) {
      await prefs.setString(_kDeliveryTime, deliveryTime!.trim());
    } else {
      await prefs.remove(_kDeliveryTime);
    }

    if (deliveryDate != null) {
      await prefs.setInt(
        _kDeliveryDateEpochMs,
        deliveryDate!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_kDeliveryDateEpochMs);
    }

    await prefs.setBool(_kUseSubscriptionBooking, useSubscriptionBooking);
    await prefs.setBool(_kContinueWithoutMembership, continueWithoutMembership);
    await prefs.setString(_kBookingMode, bookingMode.name);

    if (gender?.trim().isNotEmpty == true) {
      await prefs.setString(_kGender, gender!.trim());
    } else {
      await prefs.remove(_kGender);
    }
    if (bodyType?.trim().isNotEmpty == true) {
      await prefs.setString(_kBodyType, bodyType!.trim());
    } else {
      await prefs.remove(_kBodyType);
    }
    if (kitType?.trim().isNotEmpty == true) {
      await prefs.setString(_kKitType, kitType!.trim());
    } else {
      await prefs.remove(_kKitType);
    }
    if (wardrobeCategory != null && wardrobeCategory!.isNotEmpty) {
      await prefs.setString(_kWardrobeCategory, wardrobeCategory!);
    } else {
      await prefs.remove(_kWardrobeCategory);
    }
    
    if (activeNonSubscriptionCategoryId != null && activeNonSubscriptionCategoryId!.isNotEmpty) {
      await prefs.setString(_kActiveNonSubscriptionCategoryId, activeNonSubscriptionCategoryId!);
    } else {
      await prefs.remove(_kActiveNonSubscriptionCategoryId);
    }
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAddressId);
    await prefs.remove(_kAddressTitle);
    await prefs.remove(_kAddressLines);
    await prefs.remove(_kAddressLatitude);
    await prefs.remove(_kAddressLongitude);
    await prefs.remove(_kDeliveryDateEpochMs);
    await prefs.remove(_kDeliveryTime);
    await prefs.remove(_kUseSubscriptionBooking);
    await prefs.remove(_kContinueWithoutMembership);
    await prefs.remove(_kBookingMode);
    await prefs.remove(_kGender);
    await prefs.remove(_kBodyType);
    await prefs.remove(_kKitType);
    await prefs.remove(_kWardrobeCategory);
    await prefs.remove(_kActiveNonSubscriptionCategoryId);
  }

  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}

const String _kAddressId = 'checkout_session_address_id';
const String _kAddressTitle = 'checkout_session_address_title';
const String _kAddressLines = 'checkout_session_address_lines';
const String _kAddressLatitude = 'checkout_session_address_latitude';
const String _kAddressLongitude = 'checkout_session_address_longitude';
const String _kDeliveryDateEpochMs = 'checkout_session_delivery_date_epoch_ms';
const String _kDeliveryTime = 'checkout_session_delivery_time';
const String _kUseSubscriptionBooking = 'checkout_session_use_subscription';
const String _kContinueWithoutMembership =
    'checkout_session_continue_without_membership';
const String _kBookingMode = 'checkout_session_booking_mode';
const String _kGender = 'checkout_session_gender';
const String _kBodyType = 'checkout_session_body_type';
const String _kKitType = 'checkout_session_kit_type';
const String _kWardrobeCategory = 'checkout_session_wardrobe_category';
const String _kActiveNonSubscriptionCategoryId =
    'checkout_session_active_non_sub_category_id';
