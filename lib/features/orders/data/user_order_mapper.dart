import 'package:nomowear/features/auth/data/models/customer.dart';
import 'package:nomowear/features/orders/data/models/order_history.dart';
import 'package:nomowear/features/orders/data/pending_return_store.dart';
import 'package:nomowear/features/profile/domain/user_order.dart';

class UserOrderMapper {
  UserOrderMapper._();

  static const _returnTimelineStatuses = {
    'RETURN_REQUESTED',
    'RETURNED',
    'APPROVED',
    'RETURN_APPROVED',
  };

  static bool isReturnTimelineStatus(String? status) {
    final normalized = status?.trim().toUpperCase() ?? '';
    return _returnTimelineStatuses.contains(normalized);
  }

  static List<UserOrder> fromHistory(
    List<OrderHistoryItem> orders, {
    Customer? customer,
  }) {
    return orders
        .map((order) => fromHistoryItem(order, customer: customer))
        .toList();
  }

  static UserOrder fromHistoryItem(
    OrderHistoryItem order, {
    Customer? customer,
  }) {
    final items = order.orderItems;

    OrderLineKitDetails? matchedKitDetails;
    List<OrderKitSelectedItem> selectedGarments = [];
    for (final item in items) {
      if (item.kitDetails != null && item.kitDetails!.selectedItems.isNotEmpty) {
        matchedKitDetails = item.kitDetails;
        selectedGarments = item.kitDetails!.selectedItems;
        break;
      }
    }

    final isKit = selectedGarments.isNotEmpty;
    final garmentCount = isKit
        ? selectedGarments.length
        : (items.isEmpty
            ? 1
            : items.fold<int>(0, (sum, item) => sum + item.quantity));

    final title = isKit
        ? _kitTitle(matchedKitDetails, order)
        : _title(order, items);

    final coverImages = isKit
        ? selectedGarments
            .map((g) => g.primaryImageUrl?.trim())
            .whereType<String>()
            .where((url) => url.isNotEmpty)
            .toList()
        : _coverImages(items);

    final isDelivered = order.isDelivered;
    final pendingReturn = PendingReturnStore.instance.contains(order.id);
    // Waitlisted returns stay ACTIVE on API until admin approval.
    final inReturnFlow =
        isDelivered && (order.isInReturnFlow || pendingReturn);
    final canReturn = order.canReturn && !pendingReturn;
    final statusCopy = _statusCopy(
      order,
      isDelivered,
      pendingReturn: pendingReturn,
    );
    final address = _resolveAddress(order, customer);

    final parsedDeliveryDate = _parseDate(order.resolvedDeliveryDate) ??
        _parseDate(matchedKitDetails?.deliveryDate) ??
        order.createdAt;
    final formattedDelivery = _formatDisplayDate(parsedDeliveryDate);

    // Once admin approves (API reflects return timeline), drop local pending.
    if (order.shouldShowReturnTimeline || order.isReturnComplete) {
      // Fire-and-forget; UI already has correct flags from API.
      PendingReturnStore.instance.clear(order.id);
    }

    return UserOrder(
      id: order.id,
      title: title,
      coverImageAssets: coverImages,
      orderIdDisplay: order.orderNumber.isNotEmpty
          ? order.orderNumber
          : order.id,
      attributeLabel: _attributeLabel(order, items),
      attributeValue: _attributeValue(order, items, garmentCount),
      statusLabel: statusCopy.label,
      statusDate: statusCopy.date,
      isDelivered: isDelivered,
      canReturn: canReturn,
      isInReturnFlow: inReturnFlow,
      lineItems: items.isEmpty ? null : _lineItems(order, items, isDelivered),
      addressLabel: address.label,
      addressLines: address.lines,
      mobileDisplay: address.mobile,
      deliveredSummaryShowsReturn: canReturn,
      isWardrobeKit: isKit,
      totalGarmentsCount: garmentCount,
      deliveryDateFormatted: formattedDelivery,
      totalAmount: order.totalAmount,
    );
  }

  static String _kitTitle(
    OrderLineKitDetails? kitDetails,
    OrderHistoryItem order,
  ) {
    final rawType = kitDetails?.kitType?.trim();
    if (rawType != null &&
        rawType.isNotEmpty &&
        rawType.toLowerCase() != 'custom' &&
        rawType.toLowerCase() != 'standard') {
      return rawType;
    }
    final days = kitDetails?.durationDays ?? order.resolvedKitDurationDays;
    if (days != null && days > 0) {
      return '$days-Day Wardrobe Kit';
    }
    return 'Wardrobe Kit';
  }

  static ({String label, String date}) _statusCopy(
    OrderHistoryItem order,
    bool isDelivered, {
    bool pendingReturn = false,
  }) {
    if (order.isReturnComplete) {
      return (
        label: 'Returned on',
        date: _formatDisplayDate(order.returnedAt ?? order.rentalEndDate),
      );
    }

    if (order.isInReturnFlow || pendingReturn) {
      final status = order.returnStatus?.trim();
      if (pendingReturn &&
          (status == null ||
              status.isEmpty ||
              status.toUpperCase() == 'ACTIVE')) {
        return (
          label: 'Return status',
          date: 'Pending approval',
        );
      }
      return (
        label: 'Return status',
        date: _humanizeStatus(status ?? order.orderStatus),
      );
    }

    return (
      label: isDelivered ? 'Delivered on' : 'Delivery on',
      date: _statusDate(order, isDelivered),
    );
  }

  static String _humanizeStatus(String? status) {
    if (status == null || status.trim().isEmpty) return '-';
    return status
        .trim()
        .toLowerCase()
        .split('_')
        .map((part) =>
            part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String _title(
    OrderHistoryItem order,
    List<OrderHistoryLineItem> items,
  ) {
    if (order.isSubscription) {
      final days = order.resolvedKitDurationDays;
      if (days != null && days > 0) {
        return '$days-Day Wardrobe Kit';
      }
      return 'Wardrobe Kit';
    }

    final firstName = items
        .map((item) => item.productName?.trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .firstOrNull;
    if (firstName != null) return firstName;

    return 'Order';
  }

  static String _attributeLabel(
    OrderHistoryItem order,
    List<OrderHistoryLineItem> items,
  ) {
    if (order.isSubscription || items.length > 1) {
      return 'No of Garments';
    }

    final size = items.firstOrNull?.size?.trim();
    if (size != null && size.isNotEmpty) return 'Size';

    if (order.resolvedKitDurationDays != null) return 'Duration';

    return 'Quantity';
  }

  static String _attributeValue(
    OrderHistoryItem order,
    List<OrderHistoryLineItem> items,
    int garmentCount,
  ) {
    if (order.isSubscription || items.length > 1) {
      return garmentCount.toString();
    }

    final size = items.firstOrNull?.size?.trim();
    if (size != null && size.isNotEmpty) return size;

    final duration = order.resolvedKitDurationDays;
    if (duration != null && duration > 0) {
      return duration == 1 ? '1 day' : '$duration days';
    }

    return garmentCount.toString();
  }

  static ({String label, String lines, String mobile}) _resolveAddress(
    OrderHistoryItem order,
    Customer? customer,
  ) {
    final addressId = order.resolvedCustomerAddressId;
    CustomerAddress? matched;

    if (customer != null && addressId != null && addressId.isNotEmpty) {
      for (final address in customer.addresses) {
        if (address.id == addressId) {
          matched = address;
          break;
        }
      }
    }

    matched ??= customer?.primaryAddress;

    final lines = _formatAddressLines(matched);
    final label = matched?.city?.trim().isNotEmpty == true
        ? matched!.city!.trim()
        : 'Home';

    return (
      label: label,
      lines: lines,
      mobile: customer?.mobile ?? '',
    );
  }

  static String _formatAddressLines(CustomerAddress? address) {
    if (address == null) return '';

    final full = address.fullAddress?.trim();
    if (full != null && full.isNotEmpty) return full;

    final parts = [
      address.city,
      address.state,
      address.pincode,
      address.country,
    ]
        .map((part) => part?.trim())
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .toList();

    return parts.join(', ');
  }

  static List<String> _coverImages(List<OrderHistoryLineItem> items) {
    return items
        .map((item) => item.imageUrl?.trim())
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .take(4)
        .toList();
  }

  static List<OrderLineItem> _lineItems(
    OrderHistoryItem order,
    List<OrderHistoryLineItem> items,
    bool isDelivered,
  ) {
    final statusText = isDelivered
        ? 'Delivered on ${_statusDate(order, true)}'
        : 'Delivery on: ${_statusDate(order, false)}';

    final expandedItems = _expandItemsForDisplay(items);
    return expandedItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final name = item.productName?.trim();
      final image = item.imageUrl?.trim();
      final resolvedSize = _resolveLineItemSize(item);
      final productId = item.productId?.trim();
      return OrderLineItem(
        productId: (productId != null && productId.isNotEmpty) ? productId : '',
        productName: (name != null && name.isNotEmpty) ? name : 'Item ${index + 1}',
        orderIdDisplay: order.orderNumber,
        sizeLabel: resolvedSize,
        statusText: statusText,
        isDelivered: isDelivered,
        imageAsset: (image != null && image.isNotEmpty) ? image : '',
        category: _categoryForLineItem(item),
        itemType: item.itemType,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        lineTotal: item.lineTotal,
      );
    }).toList();
  }

  static List<OrderHistoryLineItem> _expandItemsForDisplay(
    List<OrderHistoryLineItem> items,
  ) {
    final expanded = <OrderHistoryLineItem>[];
    for (final item in items) {
      final selected = item.kitDetails?.selectedItems ?? const [];
      if (selected.isEmpty) {
        expanded.add(item);
        continue;
      }

      for (final selectedItem in selected) {
        expanded.add(
          OrderHistoryLineItem(
            productId: selectedItem.productId ?? item.productId,
            productName: selectedItem.productName ?? item.productName,
            size: selectedItem.size ?? item.size,
            quantity: selectedItem.quantity,
            unitPrice: selectedItem.price,
            lineTotal: selectedItem.price * selectedItem.quantity,
            imageUrl: selectedItem.primaryImageUrl ?? item.imageUrl,
            productClass: item.productClass,
            kitDetails: item.kitDetails,
            itemType: item.itemType,
            cartSection: item.cartSection,
          ),
        );
      }
    }
    return expanded;
  }

  static String? _categoryForLineItem(OrderHistoryLineItem item) {
    final name = item.productName?.trim().toLowerCase() ?? '';
    if (name.contains('kids') || name.contains('kid wear')) {
      return 'Kids Wardrobe';
    }
    if (name.contains('essential')) {
      return 'Essentials Wardrobe';
    }
    const wardrobeKeys = [
      'Comfort Wardrobe',
      'Professional Wardrobe',
      'Premium Wardrobe',
      'Kids Wardrobe',
    ];
    for (final key in wardrobeKeys) {
      if (name == key.toLowerCase()) return key;
      final short = key.toLowerCase().replaceAll(' wardrobe', '');
      if (short.isNotEmpty && name.contains(short)) return key;
    }
    final productClass = item.productClass?.trim().toLowerCase();
    if (productClass == 'wardrobe_kit') {
      return item.productName?.trim();
    }
    return null;
  }

  static String _resolveLineItemSize(OrderHistoryLineItem item) {
    final direct = item.size?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final productId = item.productId?.trim();
    final selectedItems = item.kitDetails?.selectedItems ?? const [];
    if (selectedItems.isEmpty) return '-';

    if (productId != null && productId.isNotEmpty) {
      for (final selected in selectedItems) {
        final selectedProductId = selected.productId?.trim();
        final selectedSize = selected.size?.trim();
        if (selectedProductId == productId &&
            selectedSize != null &&
            selectedSize.isNotEmpty) {
          return selectedSize;
        }
      }
    }

    for (final selected in selectedItems) {
      final selectedSize = selected.size?.trim();
      if (selectedSize != null && selectedSize.isNotEmpty) {
        return selectedSize;
      }
    }
    return '-';
  }

  static String _statusDate(OrderHistoryItem order, bool isDelivered) {
    if (isDelivered) {
      return _formatDisplayDate(
        order.actualDeliveredAt ?? _parseDate(order.resolvedDeliveryDate),
      );
    }

    final date = _formatDisplayDate(_parseDate(order.resolvedDeliveryDate));
    final time = order.resolvedDeliveryTime?.trim();
    if (time != null && time.isNotEmpty && date != '-') {
      return '$date, $time';
    }
    return date;
  }

  static DateTime? _parseDate(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String _formatDisplayDate(DateTime? date) {
    if (date == null) return '-';
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
    final day = date.day;
    final suffix = _daySuffix(day);
    return '$day$suffix ${months[date.month - 1]}';
  }

  static String formatTrackingTimestamp(DateTime? date) {
    if (date == null) return 'Pending';
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
    final local = date.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} • $hour:$minute $period';
  }

  static String formatDeliveryWindow(OrderHistoryItem order) {
    final date = _parseDate(order.resolvedDeliveryDate);
    if (date == null) return '-';
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final suffix = _daySuffix(date.day).toUpperCase();
    final time = order.resolvedDeliveryTime?.trim();
    if (time != null && time.isNotEmpty) {
      return '${day}$suffix ${months[date.month - 1]}, $time';
    }
    return '${day}$suffix ${months[date.month - 1]}';
  }

  static String _daySuffix(int day) {
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

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
