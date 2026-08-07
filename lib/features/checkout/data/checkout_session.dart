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
  DateTime? deliveryDate;
  String? deliveryTime;
  bool useSubscriptionBooking = false;
  CheckoutBookingMode bookingMode = CheckoutBookingMode.unset;
  String? gender;
  String? bodyType;
  String? kitType;
  /// Home wardrobe category currently locked for non-sub single-category rule.
  String? wardrobeCategory;
  bool _didRestore = false;
  Future<void>? _restoreFuture;

  void setDelivery({
    String? addressId,
    String? addressTitle,
    String? addressLines,
    DateTime? deliveryDate,
    String? deliveryTime,
    bool? useSubscriptionBooking,
    CheckoutBookingMode? bookingMode,
    String? gender,
    String? bodyType,
    String? kitType,
    String? wardrobeCategory,
  }) {
    if (addressId != null) this.addressId = addressId;
    if (addressTitle != null) this.addressTitle = addressTitle;
    if (addressLines != null) this.addressLines = addressLines;
    if (deliveryDate != null) this.deliveryDate = deliveryDate;
    if (deliveryTime != null) this.deliveryTime = deliveryTime;
    if (useSubscriptionBooking != null) {
      this.useSubscriptionBooking = useSubscriptionBooking;
    }
    if (bookingMode != null) {
      this.bookingMode = bookingMode;
      // Keep the boolean flag aligned for existing checkout / pricing checks.
      if (bookingMode == CheckoutBookingMode.subscription) {
        this.useSubscriptionBooking = true;
      } else if (bookingMode == CheckoutBookingMode.oneTimeWardrobe ||
          bookingMode == CheckoutBookingMode.essentials) {
        this.useSubscriptionBooking = false;
      }
    }
    if (gender != null) this.gender = gender;
    if (bodyType != null) this.bodyType = bodyType;
    if (kitType != null) this.kitType = kitType;
    if (wardrobeCategory != null) this.wardrobeCategory = wardrobeCategory;
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

  void clear() {
    addressId = null;
    addressTitle = null;
    addressLines = null;
    deliveryDate = null;
    deliveryTime = null;
    useSubscriptionBooking = false;
    bookingMode = CheckoutBookingMode.unset;
    gender = null;
    bodyType = null;
    kitType = null;
    wardrobeCategory = null;
    _clearPersisted();
  }

  /// Clears only the non-sub wardrobe category lock (keeps address/date).
  void clearWardrobeCategoryLock() {
    wardrobeCategory = null;
    _persist();
  }

  /// Locks one-time (non-subscription) booking to a single home wardrobe category.
  void lockNonSubWardrobeCategory(String category) {
    final value = category.trim();
    if (value.isEmpty) return;
    wardrobeCategory = value;
    useSubscriptionBooking = false;
    _persist();
  }

  Future<void> _restoreOnce() async {
    final prefs = await SharedPreferences.getInstance();
    addressId = prefs.getString(_kAddressId);
    addressTitle = prefs.getString(_kAddressTitle);
    addressLines = prefs.getString(_kAddressLines);
    deliveryTime = prefs.getString(_kDeliveryTime);
    useSubscriptionBooking = prefs.getBool(_kUseSubscriptionBooking) ?? false;
    bookingMode = _bookingModeFromStorage(prefs.getString(_kBookingMode));
    if (bookingMode == CheckoutBookingMode.unset) {
      // Legacy sessions only had the boolean flag.
      bookingMode = useSubscriptionBooking
          ? CheckoutBookingMode.subscription
          : CheckoutBookingMode.unset;
    }
    gender = prefs.getString(_kGender);
    bodyType = prefs.getString(_kBodyType);
    kitType = prefs.getString(_kKitType);
    wardrobeCategory = prefs.getString(_kWardrobeCategory);

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
    if (wardrobeCategory?.trim().isNotEmpty == true) {
      await prefs.setString(_kWardrobeCategory, wardrobeCategory!.trim());
    } else {
      await prefs.remove(_kWardrobeCategory);
    }
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAddressId);
    await prefs.remove(_kAddressTitle);
    await prefs.remove(_kAddressLines);
    await prefs.remove(_kDeliveryDateEpochMs);
    await prefs.remove(_kDeliveryTime);
    await prefs.remove(_kUseSubscriptionBooking);
    await prefs.remove(_kBookingMode);
    await prefs.remove(_kGender);
    await prefs.remove(_kBodyType);
    await prefs.remove(_kKitType);
    await prefs.remove(_kWardrobeCategory);
  }

  static CheckoutBookingMode _bookingModeFromStorage(String? raw) {
    switch (raw?.trim()) {
      case 'subscription':
        return CheckoutBookingMode.subscription;
      case 'oneTimeWardrobe':
        return CheckoutBookingMode.oneTimeWardrobe;
      case 'essentials':
        return CheckoutBookingMode.essentials;
      default:
        return CheckoutBookingMode.unset;
    }
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
const String _kDeliveryDateEpochMs = 'checkout_session_delivery_date_epoch_ms';
const String _kDeliveryTime = 'checkout_session_delivery_time';
const String _kUseSubscriptionBooking = 'checkout_session_use_subscription';
const String _kBookingMode = 'checkout_session_booking_mode';
const String _kGender = 'checkout_session_gender';
const String _kBodyType = 'checkout_session_body_type';
const String _kKitType = 'checkout_session_kit_type';
const String _kWardrobeCategory = 'checkout_session_wardrobe_category';
