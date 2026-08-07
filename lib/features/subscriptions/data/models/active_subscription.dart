import 'package:nomowear/features/plans/data/plan_price_formatter.dart';

class ActiveSubscription {
  const ActiveSubscription({
    required this.id,
    required this.planRef,
    required this.planStatus,
    required this.planName,
    required this.kitDurationDays,
    required this.maxGarments,
    required this.noOfBookings,
    required this.planPrice,
    required this.billingPeriod,
    this.bookingsUsed,
    this.remainingBookings,
    this.usedGarments,
    this.remainingGarments,
    this.startDate,
    this.endDate,
    this.nextRenewalDate,
    this.createdAt,
  });

  final String id;
  final String planRef;
  final String planStatus;
  final String planName;
  final int kitDurationDays;
  final int maxGarments;
  final int noOfBookings;
  final String planPrice;
  final String billingPeriod;
  final int? bookingsUsed;
  final int? remainingBookings;
  /// Garments already consumed in this subscription period (API, when present).
  final int? usedGarments;
  /// Garments still available in this subscription period (API, when present).
  final int? remainingGarments;
  final String? startDate;
  final String? endDate;
  final String? nextRenewalDate;
  final String? createdAt;

  DateTime? get sortDate {
    for (final iso in [createdAt, startDate, endDate]) {
      if (iso == null || iso.isEmpty) continue;
      try {
        return DateTime.parse(iso);
      } catch (_) {}
    }
    return null;
  }

  /// The single subscription that should be treated as the customer's current plan.
  static ActiveSubscription? pickCurrent(
    Iterable<ActiveSubscription> subscriptions,
  ) {
    final active = subscriptions.where((s) => s.isActive).toList();
    if (active.isEmpty) return null;
    active.sort(compareByRecency);
    return active.first;
  }

  static int compareByRecency(ActiveSubscription a, ActiveSubscription b) {
    final aDate = a.sortDate;
    final bDate = b.sortDate;
    if (aDate != null && bDate != null) {
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }
    return b.id.compareTo(a.id);
  }

  bool get isActive {
    final status = planStatus.trim().toUpperCase();
    if (status == 'ACTIVE') return true;
    if (status == 'CANCELLED' ||
        status == 'EXPIRED' ||
        status == 'INACTIVE') {
      return false;
    }
    // Active endpoint returned a record — treat as active unless explicitly inactive.
    return id.isNotEmpty;
  }

  bool get shouldDisplay => id.isNotEmpty && isActive;

  bool get hasRemainingBookings {
    final explicitRemaining = remainingBookings;
    if (explicitRemaining != null) return explicitRemaining > 0;

    final used = bookingsUsed;
    if (used != null) return used < noOfBookings;

    return noOfBookings > 0;
  }

  int get remainingBookingsCount {
    final explicitRemaining = remainingBookings;
    if (explicitRemaining != null) return explicitRemaining;

    final used = bookingsUsed;
    if (used != null) return (noOfBookings - used).clamp(0, noOfBookings);

    return noOfBookings;
  }

  /// Remaining garments from API fields only (null when backend did not send usage).
  int? get apiRemainingGarments {
    final explicit = remainingGarments;
    if (explicit != null) return explicit.clamp(0, maxGarments < 0 ? 0 : maxGarments);

    final used = usedGarments;
    if (used != null) {
      final max = maxGarments < 0 ? 0 : maxGarments;
      return (max - used).clamp(0, max);
    }
    return null;
  }

  bool get hasRemainingGarmentsFromApi {
    final remaining = apiRemainingGarments;
    if (remaining == null) return true;
    return remaining > 0;
  }

  bool get isMonthly => billingPeriod.toLowerCase() == 'monthly';

  String get displayTitle {
    final name = planName.trim().toUpperCase();
    if (name.contains('MEMBERSHIP')) return name;
    return '$name MEMBERSHIP';
  }

  String get formattedPrice {
    final amount = num.tryParse(planPrice) ?? 0;
    final periodLabel = isMonthly ? 'month' : 'year';
    return '₹${PlanPriceFormatter.format(amount)} / $periodLabel';
  }

  String get expiryLabel {
    final formatted = formatDisplayDate(endDate ?? nextRenewalDate);
    if (formatted.isEmpty) return '';
    return 'Expires on $formatted';
  }

  List<String> get features {
    final periodLabel = isMonthly ? 'month' : 'year';
    return [
      '$kitDurationDays days per $periodLabel',
      '$noOfBookings Bookings per $periodLabel',
      'Across all categories',
    ];
  }

  factory ActiveSubscription.fromJson(Map<String, dynamic> json) {
    return ActiveSubscription(
      id: json['id']?.toString() ?? '',
      planRef: json['planRef']?.toString() ??
          json['plan_ref']?.toString() ??
          '',
      planStatus: json['planStatus']?.toString() ??
          json['plan_status']?.toString() ??
          json['status']?.toString() ??
          '',
      planName: json['planName']?.toString() ??
          json['plan_name']?.toString() ??
          'Membership',
      kitDurationDays:
          _parseInt(json['kitDurationDays'] ?? json['kit_duration_days']) ?? 0,
      maxGarments:
          _parseInt(json['maxGarments'] ?? json['max_garments']) ?? 0,
      noOfBookings:
          _parseInt(json['noOfBookings'] ?? json['no_of_bookings']) ?? 0,
      planPrice: json['planPrice']?.toString() ??
          json['plan_price']?.toString() ??
          '0',
      billingPeriod: json['billingPeriod']?.toString() ??
          json['billing_period']?.toString() ??
          'monthly',
      bookingsUsed: _parseInt(
        json['bookingsUsed'] ??
            json['bookings_used'] ??
            json['usedBookings'] ??
            json['used_bookings'],
      ),
      remainingBookings: _parseInt(
        json['remainingBookings'] ??
            json['remaining_bookings'] ??
            json['bookingsRemaining'] ??
            json['bookings_remaining'],
      ),
      usedGarments: _parseInt(
        json['usedGarments'] ??
            json['used_garments'] ??
            json['garmentsUsed'] ??
            json['garments_used'],
      ),
      remainingGarments: _parseInt(
        json['remainingGarments'] ??
            json['remaining_garments'] ??
            json['garmentsRemaining'] ??
            json['garments_remaining'],
      ),
      startDate: _nonEmpty(json['startDate'] ?? json['start_date']),
      endDate: _nonEmpty(json['endDate'] ?? json['end_date']),
      nextRenewalDate:
          _nonEmpty(json['nextRenewalDate'] ?? json['next_renewal_date']),
      createdAt: _nonEmpty(json['createdAt'] ?? json['created_at']),
    );
  }

  static String formatDisplayDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
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
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _nonEmpty(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
