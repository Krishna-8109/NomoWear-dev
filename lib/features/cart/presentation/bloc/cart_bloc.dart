import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/utils/api_id_utils.dart';

import 'package:nomowear/features/cart/data/cart_repository.dart';
import 'package:nomowear/features/cart/data/models/remote_cart.dart';
import 'package:nomowear/features/cart/presentation/utils/cart_limits.dart';
import 'package:nomowear/features/cart/presentation/utils/cart_stock.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/checkout/data/subscription_kit_preferences.dart';
import 'package:nomowear/features/checkout/data/wardrobe_booking_session.dart';
import 'package:nomowear/features/products/data/product_cache.dart';
import 'package:nomowear/features/products/data/models/product_variant.dart';
import 'package:nomowear/features/products/data/product_mapper.dart';

void _cartLog(String message) {
  if (kDebugMode) debugPrint('[CART] $message');
}

void _perf(String message) {
  if (kDebugMode) debugPrint('[CART_PERF] $message');
}

void _addUiLog(String message) {
  if (kDebugMode) debugPrint('[CART_ADD_UI] $message');
}

enum CartStatus { initial, loading, loaded, updating, error }

String _resolveItemType({
  String? itemType,
  bool? isKids,
  bool? isEssential,
  bool? isSubscriptionGarment,
}) {
  final explicit = itemType?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  if (isKids == true) return 'kids';
  if (isEssential == true) return 'essentials';
  if (isSubscriptionGarment == true) return 'subscription';
  if (isSubscriptionGarment == false) return 'non_subscription';
  if (itemType != null) return itemType;
  return 'non_subscription';
}

class CartItem extends Equatable {
  CartItem({
    String? id,
    required this.productId,
    this.variantId,
    required this.title,
    required this.imageUrl,
    this.price,
    this.selectedSize = 'M',
    this.quantity = 1,
    String? itemType,
    bool? isKids,
    bool? isEssential,
    bool? isSubscriptionGarment,
    this.category,
    this.productClass,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.kitDetails,
  })  : itemType = _resolveItemType(
          itemType: itemType,
          isKids: isKids,
          isEssential: isEssential,
          isSubscriptionGarment: isSubscriptionGarment,
        ),
        id = id ??
            _lineId(
              productId,
              variantId,
              _resolveItemType(
                itemType: itemType,
                isKids: isKids,
                isEssential: isEssential,
                isSubscriptionGarment: isSubscriptionGarment,
              ),
            );

  final String id;
  final String productId;
  final String? variantId;
  final String title;
  final String imageUrl;
  final String? price;
  final String selectedSize;
  final int quantity;
  final String itemType;
  final String? category;
  final String? productClass;
  final num unitPrice;
  final num lineTotal;
  final RemoteCartKitDetails? kitDetails;

  String get productName => title;
  String? get categoryName => category;
  bool get isKids => itemType == 'kids';
  bool get isEssential => itemType == 'essentials' || itemType == 'kids';
  bool get isSubscriptionGarment => itemType == 'subscription';

  CartItem copyWith({
    String? id,
    String? selectedSize,
    int? quantity,
    bool? isSubscriptionGarment,
    bool? isKids,
    bool? isEssential,
    String? itemType,
    String? imageUrl,
    String? price,
  }) {
    final nextType = itemType ??
        (isKids == true
            ? 'kids'
            : isEssential == true
                ? 'essentials'
                : isSubscriptionGarment == true
                    ? 'subscription'
                    : isSubscriptionGarment == false
                        ? 'non_subscription'
                        : this.itemType);
    return CartItem(
      id: id ?? this.id,
      productId: productId,
      variantId: variantId,
      title: title,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      selectedSize: selectedSize ?? this.selectedSize,
      quantity: quantity ?? this.quantity,
      itemType: nextType,
      category: category,
      productClass: productClass,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      kitDetails: kitDetails,
    );
  }

  @override
  List<Object?> get props =>
      [id, productId, variantId, quantity, selectedSize, itemType];
}

String _lineId(String productId, String? variantId, String itemType) {
  final vid = variantId?.trim();
  final v = (vid == null || vid.isEmpty) ? '-' : vid;
  return '${productId.trim()}_${v}_$itemType';
}

bool _variantsCompatible(String? a, String? b) {
  final va = a?.trim() ?? '';
  final vb = b?.trim() ?? '';
  if (va.isEmpty && vb.isEmpty) return true;
  return va == vb;
}

abstract class CartEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadCartEvent extends CartEvent {
  LoadCartEvent({this.forceRefresh = false, this.source = 'unknown'});
  final bool forceRefresh;
  final String source;
  @override
  List<Object?> get props => [forceRefresh, source];
}

class AddToCartEvent extends CartEvent {
  AddToCartEvent(this.item);
  final CartItem item;
  @override
  List<Object?> get props => [item];
}

class RemoveFromCartEvent extends CartEvent {
  RemoveFromCartEvent(this.itemId);
  final String itemId;
  @override
  List<Object?> get props => [itemId];
}

class UpdateCartItemSizeEvent extends CartEvent {
  UpdateCartItemSizeEvent(this.itemId, this.size);
  final String itemId;
  final String size;
  @override
  List<Object?> get props => [itemId, size];
}

class UpdateCartItemVariantEvent extends CartEvent {
  UpdateCartItemVariantEvent(this.itemId, this.newVariant);
  final String itemId;
  final ProductVariant newVariant;
  @override
  List<Object?> get props => [itemId, newVariant];
}

class UpdateCartItemQuantityEvent extends CartEvent {
  UpdateCartItemQuantityEvent(this.itemId, this.quantity);
  final String itemId;
  final int quantity;
  @override
  List<Object?> get props => [itemId, quantity];
}

class AdjustCartItemQuantityEvent extends CartEvent {
  AdjustCartItemQuantityEvent(this.itemId, {required this.delta});
  final String itemId;
  final int delta;
  @override
  List<Object?> get props => [itemId, delta];
}

class ClearCartEvent extends CartEvent {}

class ClearLocalCartEvent extends CartEvent {}

class ClearPaidRentalItemsEvent extends CartEvent {}

class SetWardrobeKitDaysEvent extends CartEvent {
  SetWardrobeKitDaysEvent(this.kitDays);
  final int kitDays;
  @override
  List<Object?> get props => [kitDays];
}

class SetWardrobeKitEvent extends CartEvent {
  SetWardrobeKitEvent({
    required this.kitId,
    this.wardrobeKitProductId,
    required this.kitDays,
    required this.kitName,
    required this.maxGarments,
    this.kitPrice,
    this.wardrobeCategory,
    this.wardrobeCategoryId,
  });
  final String kitId;
  final String? wardrobeKitProductId;
  final int kitDays;
  final String kitName;
  final int maxGarments;
  final String? kitPrice;
  final String? wardrobeCategory;
  final String? wardrobeCategoryId;
}

class LockWardrobeCategoryEvent extends CartEvent {
  LockWardrobeCategoryEvent({
    required this.wardrobeCategory,
    this.wardrobeCategoryId,
  });
  final String wardrobeCategory;
  final String? wardrobeCategoryId;
}

class CartState extends Equatable {
  const CartState({
    this.status = CartStatus.initial,
    this.items = const [],
    this.remote = const RemoteCart(id: '', items: []),
    this.errorMessage,
    this.wardrobeKitDays = 1,
    this.wardrobeKitId,
    this.wardrobeKitProductId,
    this.wardrobeKitName = '',
    this.wardrobeKitMaxGarments = 0,
    this.wardrobeKitPrice,
    this.wardrobeCategory,
    this.wardrobeCategoryId,
    this.pendingLineIds = const {},
    this.outOfStockLineIds = const {},
  });

  final CartStatus status;
  final List<CartItem> items;
  final RemoteCart remote;
  final String? errorMessage;
  final int wardrobeKitDays;
  final String? wardrobeKitId;
  final String? wardrobeKitProductId;
  final String wardrobeKitName;
  final int wardrobeKitMaxGarments;
  final String? wardrobeKitPrice;
  final String? wardrobeCategory;
  final String? wardrobeCategoryId;
  final Set<String> pendingLineIds;
  final Set<String> outOfStockLineIds;

  int get apiItemCount => remote.itemCount;
  int get totalItems => items.fold<int>(0, (sum, item) => sum + item.quantity);

  List<CartItem> get subscriptionGarmentItems =>
      items.where((e) => e.itemType == 'subscription').toList();
  List<CartItem> get paidRentalGarmentItems =>
      items.where((e) => e.itemType == 'non_subscription').toList();
  List<CartItem> get essentialsOnlyItems =>
      items.where((e) => e.itemType == 'essentials').toList();
  List<CartItem> get kidsItems =>
      items.where((e) => e.itemType == 'kids').toList();
  List<CartItem> get wardrobeItems => items
      .where((e) =>
          e.itemType == 'subscription' || e.itemType == 'non_subscription')
      .toList();
  List<CartItem> get essentialItems => items
      .where((e) => e.itemType == 'essentials' || e.itemType == 'kids')
      .toList();
  List<CartItem> get purchaseItems => essentialItems;
  List<CartItem> get groupedEssentialItems => essentialsOnlyItems;

  bool get hasMixedWardrobeTypes =>
      subscriptionGarmentItems.isNotEmpty && paidRentalGarmentItems.isNotEmpty;
  bool get hasSubscriptionGarments => subscriptionGarmentItems.isNotEmpty;
  bool get hasPaidRentalGarments => paidRentalGarmentItems.isNotEmpty;

  int get subscriptionGarmentCount => subscriptionGarmentItems.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );
  int get paidRentalGarmentCount => paidRentalGarmentItems.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );
  int get wardrobeGarmentCount => wardrobeItems.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );

  int get currentBookingSelectedGarments => subscriptionGarmentCount;
  int get currentKitLimit {
    if (wardrobeKitMaxGarments > 0) return wardrobeKitMaxGarments;
    final sessionLimit = WardrobeBookingSession.instance.kitGarmentLimit;
    if (sessionLimit > 0) return sessionLimit;
    final prefLimit = SubscriptionKitPreferences.instance.wardrobeKitMaxGarments;
    if (prefLimit > 0) return prefLimit;
    return maxWardrobeGarments;
  }

  int get currentBookingRemaining {
    final remaining = currentKitLimit - currentBookingSelectedGarments;
    return remaining < 0 ? 0 : remaining;
  }

  bool get shouldGroupEssentialsUnderWardrobe => false;

  int get maxWardrobeGarments {
    if (wardrobeKitMaxGarments > 0) return wardrobeKitMaxGarments;
    final sessionLimit = WardrobeBookingSession.instance.kitGarmentLimit;
    if (sessionLimit > 0) return sessionLimit;
    final prefLimit = SubscriptionKitPreferences.instance.wardrobeKitMaxGarments;
    if (prefLimit > 0) return prefLimit;
    final days = wardrobeKitDays > 0
        ? wardrobeKitDays
        : SubscriptionKitPreferences.instance.wardrobeKitDays;
    if (days == 1) return 4;
    if (days == 3) return 7;
    if (days == 7) return 10;
    if (days > 0) return 4;
    if (wardrobeItems.isNotEmpty ||
        WardrobeBookingSession.instance.kitSelected ||
        SubscriptionKitPreferences.instance.isKitConfigured) {
      return 4;
    }
    return 0;
  }

  String get wardrobeKitTitle => wardrobeKitName.isNotEmpty &&
          wardrobeKitName.toLowerCase() != 'custom' &&
          wardrobeKitName.toLowerCase() != 'standard'
      ? wardrobeKitName
      : '$wardrobeKitDays Day wardrobe kit';

  bool get isEmpty => items.isEmpty && remote.itemCount <= 0;
  bool get isConfirmedEmpty => status == CartStatus.loaded && isEmpty;
  bool get isSyncing =>
      status == CartStatus.loading || status == CartStatus.updating;
  bool get hasLoadedRemote =>
      status == CartStatus.loaded ||
      status == CartStatus.updating ||
      status == CartStatus.error;
  bool get showLoading =>
      status == CartStatus.initial ||
      (status == CartStatus.loading && items.isEmpty);

  bool isLinePending(String lineId) => pendingLineIds.contains(lineId);

  bool isProductPending({
    String? productId,
    String? variantId,
    String? itemType,
  }) {
    final pid = productId?.trim() ?? '';
    if (pid.isEmpty) return false;
    final type =
        (itemType == null || itemType.isEmpty) ? 'non_subscription' : itemType;
    if (pendingLineIds.contains(_lineId(pid, variantId, type))) return true;
    if (pendingLineIds.contains(_lineId(pid, null, type))) return true;
    final prefix = '${pid}_';
    for (final key in pendingLineIds) {
      if (key.startsWith(prefix)) return true;
    }
    return false;
  }

  bool isVariantOutOfStock({
    String? productId,
    String? variantId,
    String? itemType,
  }) {
    final pid = productId?.trim() ?? '';
    if (pid.isEmpty) return false;
    final type =
        (itemType == null || itemType.isEmpty) ? 'non_subscription' : itemType;
    return outOfStockLineIds.contains(_lineId(pid, variantId, type));
  }

  int quantityForListingCard({
    String? productId,
    String? variantId,
    String? itemType,
  }) {
    final exact = quantityForProduct(
      productId,
      variantId: variantId,
      itemType: itemType,
    );
    if (exact > 0) return exact;
    return quantityForProduct(productId, variantId: variantId);
  }

  CartItem? lineForListingCard({
    String? productId,
    String? variantId,
    String? itemType,
  }) {
    return lineForProduct(
          productId,
          variantId: variantId,
          itemType: itemType,
        ) ??
        lineForProduct(
          productId,
          variantId: variantId,
        );
  }

  CartItem? lineForProduct(
    String? productId, {
    String? variantId,
    String? itemType,
    bool? isEssential,
    bool? isSubscriptionGarment,
  }) {
    final pid = productId?.trim() ?? '';
    if (pid.isEmpty) return null;
    final vid = variantId?.trim();
    String? type = itemType;
    if (type == null) {
      if (isSubscriptionGarment == true) type = 'subscription';
      if (isEssential == true) type = 'essentials';
      if (isSubscriptionGarment == false && isEssential == false) {
        type = 'non_subscription';
      }
    }
    CartItem? fallback;
    for (final item in items) {
      if (item.productId.trim() != pid) continue;
      if (vid != null &&
          vid.isNotEmpty &&
          !_variantsCompatible(item.variantId, vid) &&
          item.id != '${pid}_$vid') {
        continue;
      }
      if (type != null && item.itemType != type) continue;
      if (vid != null &&
          vid.isNotEmpty &&
          (_variantsCompatible(item.variantId, vid) ||
              item.id == '${pid}_$vid')) {
        return item;
      }
      fallback ??= item;
    }
    return fallback;
  }

  int quantityForProduct(
    String? productId, {
    String? variantId,
    String? itemType,
  }) {
    final pid = productId?.trim() ?? '';
    if (pid.isEmpty) return 0;
    final vid = variantId?.trim();
    return items.where((item) {
      if (item.productId.trim() != pid) return false;
      if (itemType != null && item.itemType != itemType) return false;
      if (vid == null || vid.isEmpty) return true;
      return _variantsCompatible(item.variantId, vid) ||
          item.id == '${pid}_$vid';
    }).fold<int>(0, (sum, item) => sum + item.quantity);
  }

  CartState copyWith({
    CartStatus? status,
    List<CartItem>? items,
    RemoteCart? remote,
    String? errorMessage,
    int? wardrobeKitDays,
    String? wardrobeKitId,
    String? wardrobeKitProductId,
    String? wardrobeKitName,
    int? wardrobeKitMaxGarments,
    String? wardrobeKitPrice,
    String? wardrobeCategory,
    String? wardrobeCategoryId,
    Set<String>? pendingLineIds,
    Set<String>? outOfStockLineIds,
    bool clearWardrobeKit = false,
    bool clearError = false,
  }) {
    return CartState(
      status: status ?? this.status,
      items: items ?? this.items,
      remote: remote ?? this.remote,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      wardrobeKitDays: wardrobeKitDays ?? this.wardrobeKitDays,
      wardrobeKitId:
          clearWardrobeKit ? null : wardrobeKitId ?? this.wardrobeKitId,
      wardrobeKitProductId: clearWardrobeKit
          ? null
          : wardrobeKitProductId ?? this.wardrobeKitProductId,
      wardrobeKitName:
          clearWardrobeKit ? '' : wardrobeKitName ?? this.wardrobeKitName,
      wardrobeKitMaxGarments: clearWardrobeKit
          ? 0
          : wardrobeKitMaxGarments ?? this.wardrobeKitMaxGarments,
      wardrobeKitPrice: clearWardrobeKit
          ? null
          : wardrobeKitPrice ?? this.wardrobeKitPrice,
      wardrobeCategory: wardrobeCategory ?? this.wardrobeCategory,
      wardrobeCategoryId: wardrobeCategoryId ?? this.wardrobeCategoryId,
      pendingLineIds: pendingLineIds ?? this.pendingLineIds,
      outOfStockLineIds: outOfStockLineIds ?? this.outOfStockLineIds,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        remote.itemCount,
        remote.id,
        errorMessage,
        wardrobeKitId,
        wardrobeKitDays,
        wardrobeCategory,
        pendingLineIds.join(','),
        outOfStockLineIds.join(','),
      ];
}

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc({CartRepository? repository})
      : _repository = repository ?? CartRepository(),
        super(const CartState()) {
    on<LoadCartEvent>(_onLoad);
    on<AddToCartEvent>(_onAdd);
    on<RemoveFromCartEvent>(_onRemove);
    on<UpdateCartItemSizeEvent>(_onSize);
    on<UpdateCartItemVariantEvent>(_onUpdateVariant);
    on<UpdateCartItemQuantityEvent>(_onQty);
    on<AdjustCartItemQuantityEvent>(_onAdjust);
    on<ClearCartEvent>(_onClear);
    on<ClearLocalCartEvent>(_onClearLocal);
    on<ClearPaidRentalItemsEvent>(_onClearPaid);
    on<SetWardrobeKitDaysEvent>((event, emit) {
      emit(state.copyWith(wardrobeKitDays: event.kitDays));
    });
    on<SetWardrobeKitEvent>((event, emit) {
      emit(state.copyWith(
        wardrobeKitId: event.kitId,
        wardrobeKitProductId: event.wardrobeKitProductId,
        wardrobeKitDays: event.kitDays,
        wardrobeKitName: event.kitName,
        wardrobeKitMaxGarments: event.maxGarments,
        wardrobeKitPrice: event.kitPrice,
        wardrobeCategory: event.wardrobeCategory,
        wardrobeCategoryId: event.wardrobeCategoryId,
      ));
    });
    on<LockWardrobeCategoryEvent>((event, emit) {
      final category = event.wardrobeCategory.trim();
      if (category.isEmpty) return;
      emit(state.copyWith(
        wardrobeCategory: category,
        wardrobeCategoryId: event.wardrobeCategoryId,
      ));
    });
  }

  final CartRepository _repository;
  Future<void> _ops = Future.value();
  int _latestApplyId = 0;
  final Map<String, Future<void>> _lineOps = {};
  final Set<String> _inflightLines = {};
  final Set<String> _qtyFlushing = {};
  final Map<String, int> _desiredQty = {};
  final List<Completer<RemoteCart>> _refreshWaiters = [];

  Future<void> _enqueue(Future<void> Function() action) async {
    final previous = _ops;
    final gate = Completer<void>();
    _ops = gate.future;
    await previous;
    try {
      await action();
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }

  Future<void> _enqueueLine(String key, Future<void> Function() action) async {
    final previous = _lineOps[key] ?? Future.value();
    final gate = Completer<void>();
    _lineOps[key] = gate.future;
    await previous;
    try {
      await action();
    } finally {
      if (!gate.isCompleted) gate.complete();
      if (identical(_lineOps[key], gate.future)) {
        _lineOps.remove(key);
      }
    }
  }

  Set<String> _pendingPlus(String lineId) => {...state.pendingLineIds, lineId};

  Set<String> _pendingMinus(String lineId) {
    final next = {...state.pendingLineIds}..remove(lineId);
    return next;
  }

  void _emitClearPending(
    Emitter<CartState> emit,
    String lineId,
    String source,
  ) {
    if (emit.isDone) {
      _addUiLog('CLEAR LOADING skipped emit.done productKey=$lineId');
      return;
    }
    if (!state.pendingLineIds.contains(lineId)) {
      _addUiLog('CLEAR LOADING already-clear productKey=$lineId');
      return;
    }
    _addUiLog('CLEAR LOADING productKey=$lineId');
    _emitLogged(
      emit,
      state.copyWith(pendingLineIds: _pendingMinus(lineId)),
      source,
    );
  }

  void _completeRefreshWaiters(RemoteCart remote, [Object? error, StackTrace? st]) {
    final waiters = List<Completer<RemoteCart>>.from(_refreshWaiters);
    _refreshWaiters.clear();
    for (final waiter in waiters) {
      if (waiter.isCompleted) continue;
      if (error != null) {
        waiter.completeError(error, st);
      } else {
        waiter.complete(remote);
      }
    }
  }

  Future<RemoteCart> refresh({required String source}) {
    final completer = Completer<RemoteCart>();
    _refreshWaiters.add(completer);
    add(LoadCartEvent(forceRefresh: true, source: source));
    return completer.future;
  }

  void _emitLogged(Emitter<CartState> emit, CartState next, String source) {
    _cartLog(
      'CART_STATE status=${next.status.name} source=$source '
      'subscription=${next.subscriptionGarmentCount} '
      'non_subscription=${next.paidRentalGarmentCount} '
      'essentials=${next.essentialsOnlyItems.fold<int>(0, (n, e) => n + e.quantity)} '
      'kids=${next.kidsItems.fold<int>(0, (n, e) => n + e.quantity)} '
      'total=${next.totalItems}',
    );
    emit(next);
  }

  Future<RemoteCart> _applyRemote(
    Emitter<CartState> emit, {
    required RemoteCart remote,
    required String source,
    int? expectedApplyId,
    String? clearLineId,
  }) async {
    if (expectedApplyId != null && expectedApplyId != _latestApplyId) {
      _perf(
        'SKIP STALE APPLY expected=$expectedApplyId current=$_latestApplyId source=$source',
      );
      return state.remote;
    }
    final mapped = _mapRemote(remote);
    final kit = _kitFrom(remote);
    final pending = clearLineId == null
        ? state.pendingLineIds
        : ({...state.pendingLineIds}..remove(clearLineId));
    final outOfStock = clearLineId == null
        ? state.outOfStockLineIds
        : ({...state.outOfStockLineIds}..remove(clearLineId));
    if (clearLineId != null) {
      _addUiLog('CLEAR LOADING productKey=$clearLineId source=$source');
    }
    final stateSw = Stopwatch()..start();
    final resolvedMaxGarments = state.wardrobeKitMaxGarments > 0
        ? state.wardrobeKitMaxGarments
        : (WardrobeBookingSession.instance.kitGarmentLimit > 0
            ? WardrobeBookingSession.instance.kitGarmentLimit
            : SubscriptionKitPreferences.instance.wardrobeKitMaxGarments);

    final preservedItems = <CartItem>[];
    final existingItems = state.items;
    final newItemsMap = {for (final item in mapped) item.id: item};
    for (final existing in existingItems) {
      if (newItemsMap.containsKey(existing.id)) {
        preservedItems.add(newItemsMap[existing.id]!);
        newItemsMap.remove(existing.id);
      }
    }
    preservedItems.addAll(newItemsMap.values);

    final nextState = state.copyWith(
      status: CartStatus.loaded,
      items: preservedItems,
      remote: remote,
      clearError: true,
      wardrobeKitId: kit.kitId ?? state.wardrobeKitId,
      wardrobeKitProductId: kit.productId ?? state.wardrobeKitProductId,
      wardrobeKitDays: kit.days ?? state.wardrobeKitDays,
      wardrobeKitName: kit.name ?? state.wardrobeKitName,
      wardrobeKitMaxGarments:
          resolvedMaxGarments > 0 ? resolvedMaxGarments : null,
      pendingLineIds: pending,
      outOfStockLineIds: outOfStock,
    );
    _emitLogged(emit, nextState, source);
    stateSw.stop();
    _perf(
      'STATE UPDATE duration=${stateSw.elapsedMilliseconds}ms source=$source',
    );
    
    // Clear stale Kids/Essentials session state if their cart items were removed
    if (CheckoutSession.instance.bookingMode == CheckoutBookingMode.essentials) {
      if (nextState.essentialsOnlyItems.isEmpty && nextState.kidsItems.isEmpty) {
        _cartLog('CLEARING stale Essentials/Kids bookingMode because cart section is empty');
        CheckoutSession.instance.clearEssentialsBookingMode();
      }
    }

    // Reset booking mode selection if cart transitions from having items to empty
    if (state.items.isNotEmpty && remote.items.isEmpty) {
      _cartLog('Cart transitioned from items -> zero items. Resetting booking mode selection.');
      CheckoutSession.instance.clearBookingModeSelection();
      WardrobeBookingSession.instance.startNewBooking();
    }

    _completeRefreshWaiters(remote);
    return remote;
  }

  Future<RemoteCart> _getAuthoritative(
    Emitter<CartState> emit, {
    required String source,
    int? applyId,
    String? clearLineId,
  }) async {
    final expected = applyId ?? _latestApplyId;
    final requestId = _repository.nextRequestId();
    _perf('GET START requestId=$requestId source=$source');
    _addUiLog('GET START productKey=${clearLineId ?? '-'}');
    _cartLog('CART_API GET START requestId=$requestId source=$source');
    final remote = await _repository.getCart(
      requestId: requestId,
      source: source,
    );
    _addUiLog('GET COMPLETE productKey=${clearLineId ?? '-'}');
    return _applyRemote(
      emit,
      remote: remote,
      source: 'GET response $requestId',
      expectedApplyId: expected,
      clearLineId: clearLineId,
    );
  }

  ({String? kitId, String? productId, int? days, String? name}) _kitFrom(
    RemoteCart remote,
  ) {
    for (final item in remote.items) {
      final kit = item.kitDetails;
      if (kit == null) continue;
      return (
        kitId: kit.wardrobeKitId,
        productId: kit.wardrobeKitProductId,
        days: kit.durationDays,
        name: kit.kitType,
      );
    }
    return (kitId: null, productId: null, days: null, name: null);
  }

  List<CartItem> _mapRemote(RemoteCart remote) {
    return remote.items.map((item) {
      final type = item.itemType;
      if (type.isEmpty) {
        _cartLog(
          'GET item missing item_type productId=${item.productId} '
          'name=${item.productName}',
        );
      }
      final image = (item.imageUrl != null && item.imageUrl!.isNotEmpty)
          ? item.imageUrl!
          : '';
      final isSub = type == 'subscription';
      final effectiveUnitPrice = isSub ? 0 : item.unitPrice;
      final price = effectiveUnitPrice > 0
          ? '₹ ${effectiveUnitPrice.round()}'
          : null;
      return CartItem(
        productId: item.productId,
        variantId: item.variantId,
        title: item.productName,
        imageUrl: image,
        price: price,
        selectedSize: item.size ?? 'M',
        quantity: item.quantity,
        itemType: type,
        category: item.categoryName,
        productClass: item.productClass,
        unitPrice: item.unitPrice,
        lineTotal: item.lineTotal,
        kitDetails: item.kitDetails,
      );
    }).toList();
  }

  Future<void> _onLoad(LoadCartEvent event, Emitter<CartState> emit) async {
    await _enqueue(() async {
      if (!event.forceRefresh &&
          (state.status == CartStatus.loading ||
              state.status == CartStatus.loaded ||
              state.status == CartStatus.updating)) {
        _cartLog('GET skipped already-loaded source=${event.source}');
        return;
      }
      if (state.items.isEmpty) {
        _emitLogged(
          emit,
          state.copyWith(status: CartStatus.loading),
          'GET loading ${event.source}',
        );
      } else {
        _emitLogged(
          emit,
          state.copyWith(status: CartStatus.updating),
          'GET updating ${event.source}',
        );
      }
      try {
        await _getAuthoritative(emit, source: event.source);
      } catch (e, st) {
        _completeRefreshWaiters(state.remote, e, st);
        _emitLogged(
          emit,
          state.copyWith(
            status: state.items.isEmpty ? CartStatus.error : CartStatus.loaded,
            errorMessage: e.toString(),
          ),
          'GET error ${event.source}',
        );
      }
    });
  }

  Future<RemoteCart> _writeThenGet(
    Emitter<CartState> emit, {
    required CartWriteRequest request,
    required String source,
    String? postedType,
    String? productName,
    String? lineId,
  }) async {
    _perf('REQUEST START source=$source productId=${request.productId}');
    final postId = _repository.nextRequestId();
    final result = await _repository.upsert(
      request: request,
      requestId: postId,
      source: source,
    );
    _perf(
      'REQUEST END duration=${result.durationMs}ms source=$source',
    );
    _addUiLog('POST COMPLETE productKey=${lineId ?? request.productId}');
    final completedId = ++_latestApplyId;
    late final RemoteCart remote;
    if (result.isAuthoritative) {
      _perf('GET SKIPPED reason=POST_AUTHORITATIVE source=$source');
      _addUiLog(
        'GET COMPLETE productKey=${lineId ?? request.productId} skipped=true',
      );
      remote = await _applyRemote(
        emit,
        remote: result.remote,
        source: '$source.postCart',
        clearLineId: lineId,
      );
    } else {
      remote = await _getAuthoritative(
        emit,
        source: '$source.afterPost',
        applyId: completedId,
        clearLineId: lineId,
      );
    }

    final matched = remote.items.any((item) =>
        item.productId == request.productId &&
        _variantsCompatible(item.variantId, request.variantId));
    _addUiLog(
      'CART MATCH productKey=${lineId ?? request.productId} $matched',
    );

    if (postedType != null && request.quantity > 0) {
      if (result.isAuthoritative) {
        _cartLog(
          'TYPE CHECK product=${productName ?? request.productId} '
          'POST=$postedType GET=SKIPPED reason=POST_AUTHORITATIVE '
          'status=NOT_APPLICABLE',
        );
        return remote;
      }
      RemoteCartItem? found;
      for (final item in remote.items) {
        if (item.productId == request.productId &&
            (request.variantId == null ||
                (item.variantId ?? '') == (request.variantId ?? ''))) {
          found = item;
          if (item.itemType == postedType) break;
        }
      }
      final got = found?.itemType ?? '-';
      if (postedType != got) {
        _cartLog(
          'BACKEND TYPE MISMATCH product=${productName ?? request.productId} '
          'POST=$postedType GET=$got — Flutter will not rewrite GET',
        );
      } else {
        _cartLog(
          'TYPE CHECK product=${productName ?? request.productId} '
          'POST=$postedType GET=$got status=MATCH',
        );
      }
    }
    return remote;
  }

  String _resolveAddType(CartItem item) {
    var type = item.itemType.trim();
    if (type.isEmpty) {
      if (item.isKids || isKidsCategory(item.category)) {
        type = 'kids';
      } else if (item.isEssential || isEssentialCategory(item.category)) {
        type = 'essentials';
      }
    }
    if (type.isEmpty && kDebugMode) {
      debugPrint(
        '[CART_ITEM_TYPE] BACKEND MISSING REQUIRED FIELD: item_type in product catalog payload',
      );
    }
    return type;
  }

  Future<CartWriteRequest> _buildKitWriteRequest({
    required String itemType,
    required String targetProductId,
    required String? targetVariantId,
    required int targetQuantity,
    required String? targetSize,
    required String? targetCategory,
    required String? targetProductClass,
    required String? targetProductName,
    String? lineIdToSkip,
  }) async {
    if (itemType != 'subscription' && itemType != 'non_subscription') {
      return CartWriteRequest(
        productId: targetProductId,
        variantId: targetVariantId,
        quantity: targetQuantity,
        itemType: itemType,
        size: targetSize,
        categoryName: targetCategory,
        productClass: targetProductClass,
        productName: targetProductName,
      );
    }

    final garments = <Map<String, dynamic>>[];
    final existingGarments = state.items.where((i) {
      if (i.itemType != itemType) return false;
      if (i.isKids || isKidsCategory(i.category)) return false;
      if (i.isEssential || isEssentialCategory(i.category)) return false;
      return true;
    });
    
    for (final g in existingGarments) {
      if (lineIdToSkip != null && g.id == lineIdToSkip) {
        continue;
      }
      if (g.productId == targetProductId &&
          (g.variantId ?? '') == (targetVariantId ?? '')) {
        continue;
      }
      garments.add({
        'productId': g.productId,
        'quantity': g.quantity,
        'variantId': g.variantId,
        'size': g.selectedSize,
        'product_name': g.productName,
        'price': g.unitPrice,
        'primary_image_url': g.imageUrl,
      });
    }

    if (targetQuantity > 0) {
      garments.add({
        'productId': targetProductId,
        'quantity': targetQuantity,
        'variantId': targetVariantId,
        'size': targetSize,
        'product_name': targetProductName,
      });
    }

    String? kitProductId;
    String? kitId;
    int? durationDays;
    String? kitName;

    if (existingGarments.isNotEmpty) {
      final existingKit = existingGarments.first.kitDetails;
      kitProductId = existingKit?.wardrobeKitProductId;
      kitId = existingKit?.wardrobeKitId;
      durationDays = existingKit?.durationDays;
      kitName = existingKit?.kitType;
    }

    final kit = await _repository.subscriptionKitDetails(
      wardrobeKitId: kitId ?? state.wardrobeKitId,
      wardrobeKitProductId: kitProductId ?? state.wardrobeKitProductId,
      durationDays: durationDays ?? state.wardrobeKitDays,
      kitName: kitName ?? state.wardrobeKitName,
      selectedItems: garments,
    );

    if (kit != null) {
      kit['non_subscription'] = itemType == 'non_subscription';
      kit['cart_section'] = itemType;
    }
    
    if (kitProductId == null || kitProductId.isEmpty) {
      return CartWriteRequest(
        productId: targetProductId,
        variantId: targetVariantId,
        quantity: targetQuantity,
        itemType: itemType,
        size: targetSize,
        categoryName: targetCategory,
        kitDetails: kit,
        productClass: targetProductClass,
        productName: targetProductName,
      );
    }

    return CartWriteRequest(
      productId: kitProductId,
      variantId: null,
      quantity: garments.isEmpty ? 0 : 1,
      itemType: itemType,
      kitDetails: kit,
      productClass: 'wardrobe_kit',
      productName: state.wardrobeKitName ?? 'Wardrobe Kit',
    );
  }

  Future<void> _onAdd(AddToCartEvent event, Emitter<CartState> emit) async {
    if (!isApiUuid(event.item.productId)) return;
    final type = _resolveAddType(event.item);
    final key = _lineId(event.item.productId, event.item.variantId, type);
    if (_inflightLines.contains(key) || state.pendingLineIds.contains(key)) {
      _perf('ADD SKIP duplicate line=$key');
      return;
    }
    final opSw = Stopwatch()..start();
    _perf('ADD START line=$key product=${event.item.title}');
    _addUiLog('START productKey=$key');
    _inflightLines.add(key);
    _emitLogged(
      emit,
      state.copyWith(pendingLineIds: _pendingPlus(key)),
      'AddToCart pending',
    );
    try {
      await _enqueueLine(key, () => _handleAdd(event, emit, type: type));
    } catch (e) {
      _addUiLog('CLEAR LOADING productKey=$key error=true');
      final message = e is ApiException ? e.message : e.toString();
      final isOos = cartVariantOutOfStockMessage(message);
      final isQuota = !isOos && isSubscriptionQuotaError(message);
      if (isOos) {
        logCartStockOut(
          productId: event.item.productId,
          variantId: event.item.variantId,
          size: event.item.selectedSize,
          message: message,
        );
      }
      if (isQuota) {
        logCartQuota(SubscriptionQuotaDetails.parse(message));
      }
      _emitLogged(
        emit,
        state.copyWith(
          status: CartStatus.loaded,
          errorMessage: isOos ? null : message,
          pendingLineIds: _pendingMinus(key),
          outOfStockLineIds: isOos
              ? {...state.outOfStockLineIds, key}
              : state.outOfStockLineIds,
        ),
        'AddToCart error',
      );
    } finally {
      _inflightLines.remove(key);
      _emitClearPending(emit, key, 'AddToCart done');
      opSw.stop();
      _perf(
        'UI COMPLETE duration=${opSw.elapsedMilliseconds}ms op=ADD line=$key',
      );
    }
  }

  Future<void> _handleAdd(
    AddToCartEvent event,
    Emitter<CartState> emit, {
    required String type,
  }) async {
    debugPrint('===== CART ADD VARIANT =====');
    debugPrint('productId = ${event.item.productId}');
    debugPrint('variantId = ${event.item.variantId}');
    debugPrint('variantName = ${event.item.title}');
    
    final existing = state.lineForProduct(
      event.item.productId,
      variantId: event.item.variantId,
      itemType: type,
    );
    final qty = (existing?.quantity ?? 0) + 1;
    final request = await _buildKitWriteRequest(
      itemType: type,
      targetProductId: event.item.productId,
      targetVariantId: event.item.variantId,
      targetQuantity: qty,
      targetSize: event.item.selectedSize,
      targetCategory: event.item.category,
      targetProductClass: event.item.productClass ?? 'single_item',
      targetProductName: event.item.title,
    );

    await _writeThenGet(
      emit,
      request: request,
      source: 'AddToCart',
      postedType: type,
      productName: event.item.title,
      lineId: _lineId(event.item.productId, event.item.variantId, type),
    );
  }

  CartItem? _line(String itemId) {
    for (final item in state.items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  Future<void> _onRemove(
    RemoveFromCartEvent event,
    Emitter<CartState> emit,
  ) async {
    final item = _line(event.itemId);
    if (item == null) return;
    _desiredQty[item.id] = 0;
    if (_qtyFlushing.contains(item.id)) {
      _perf('DELETE COALESCE to qty=0 line=${item.id}');
      return;
    }
    if (_inflightLines.contains(item.id) ||
        state.pendingLineIds.contains(item.id)) {
      _perf('DELETE SKIP duplicate line=${item.id}');
      return;
    }
    final opSw = Stopwatch()..start();
    _perf('DELETE START line=${item.id} product=${item.title}');
    _inflightLines.add(item.id);
    _emitLogged(
      emit,
      state.copyWith(pendingLineIds: _pendingPlus(item.id)),
      'RemoveFromCart pending',
    );
    try {
      await _enqueueLine(item.id, () => _handleRemove(item.id, emit));
    } catch (e) {
      _emitLogged(
        emit,
        state.copyWith(
          status: CartStatus.loaded,
          errorMessage: e.toString(),
          pendingLineIds: _pendingMinus(item.id),
        ),
        'RemoveFromCart error',
      );
    } finally {
      _inflightLines.remove(item.id);
      _emitClearPending(emit, item.id, 'RemoveFromCart done');
      opSw.stop();
      _perf(
        'UI COMPLETE duration=${opSw.elapsedMilliseconds}ms op=DELETE line=${item.id}',
      );
    }
  }

  Future<void> _handleRemove(String itemId, Emitter<CartState> emit) async {
    final item = _line(itemId);
    if (item == null) return;
    _desiredQty.remove(item.id);
    _perf('UPDATE/POST START op=DELETE line=$itemId');
    
    final request = await _buildKitWriteRequest(
      itemType: item.itemType,
      targetProductId: item.productId,
      targetVariantId: item.variantId,
      targetQuantity: 0,
      targetSize: item.selectedSize,
      targetCategory: item.categoryName,
      targetProductClass: item.productClass ?? 'single_item',
      targetProductName: item.productName,
      lineIdToSkip: item.id,
    );

    await _writeThenGet(
      emit,
      request: request,
      source: 'RemoveFromCart',
      lineId: item.id,
    );
  }

  Future<void> _onSize(
    UpdateCartItemSizeEvent event,
    Emitter<CartState> emit,
  ) async {
    final item = _line(event.itemId);
    if (item == null) return;
    if (_inflightLines.contains(item.id)) return;
    _inflightLines.add(item.id);
    _emitLogged(
      emit,
      state.copyWith(pendingLineIds: _pendingPlus(item.id)),
      'UpdateSize pending',
    );
    try {
      await _enqueueLine(item.id, () => _handleSize(event, emit));
    } catch (e) {
      _emitLogged(
        emit,
        state.copyWith(
          status: CartStatus.loaded,
          errorMessage: e.toString(),
          pendingLineIds: _pendingMinus(item.id),
        ),
        'UpdateSize error',
      );
    } finally {
      _inflightLines.remove(item.id);
      _emitClearPending(emit, item.id, 'UpdateSize done');
    }
  }

  Future<void> _handleSize(
    UpdateCartItemSizeEvent event,
    Emitter<CartState> emit,
  ) async {
    final item = _line(event.itemId);
    if (item == null) return;

    int targetQty = item.quantity;
    String? newVariantId = item.variantId;
    String? newVariantName = item.productName;
    String? oldColor;

    final product = ProductCache.instance.findById(item.productId);
    if (product != null && item.variantId != null) {
      final oldVariant = product.variants.where((v) => v.id == item.variantId).firstOrNull;
      if (oldVariant != null) {
        oldColor = ProductMapper.optionValue(oldVariant, 'Color');
      }

      final newVariant = ProductMapper.matchingVariant(
        variants: product.variants,
        selectedColor: oldColor,
        selectedSize: event.size,
      );

      if (newVariant != null) {
        newVariantId = newVariant.id;
        newVariantName = newVariant.variantName;
        
        if (targetQty > newVariant.stockOnHand && newVariant.stockOnHand > 0) {
          targetQty = newVariant.stockOnHand;
        }

        debugPrint('===== CART SIZE CHANGED =====');
        debugPrint('OLD VARIANT ID = ${item.variantId}');
        debugPrint('SELECTED SIZE = ${event.size}');
        debugPrint('SELECTED COLOR = $oldColor');
        debugPrint('RESOLVED VARIANT ID = ${newVariant.id}');
        debugPrint('RESOLVED VARIANT NAME = ${newVariant.variantName}');
        debugPrint('RESOLVED STOCK = ${newVariant.stockOnHand}');
        debugPrint('==============================');
      }
    }

    final request = await _buildKitWriteRequest(
      itemType: item.itemType,
      targetProductId: item.productId,
      targetVariantId: newVariantId,
      targetQuantity: targetQty,
      targetSize: event.size,
      targetCategory: item.categoryName,
      targetProductClass: item.productClass ?? 'single_item',
      targetProductName: newVariantName,
      lineIdToSkip: item.id,
    );

    _perf('UPDATE/POST START op=SIZE line=${event.itemId} size=${event.size}');
    await _writeThenGet(
      emit,
      request: request,
      source: 'UpdateSize',
      lineId: item.id,
    );
  }

  Future<void> _onUpdateVariant(
    UpdateCartItemVariantEvent event,
    Emitter<CartState> emit,
  ) async {
    final item = _line(event.itemId);
    if (item == null) return;
    if (_inflightLines.contains(item.id)) return;
    _inflightLines.add(item.id);
    _emitLogged(
      emit,
      state.copyWith(pendingLineIds: _pendingPlus(item.id)),
      'UpdateVariant pending',
    );
    try {
      await _enqueueLine(item.id, () => _handleUpdateVariant(event, emit));
    } catch (e) {
      _emitLogged(
        emit,
        state.copyWith(
          status: CartStatus.loaded,
          errorMessage: e.toString(),
          pendingLineIds: _pendingMinus(item.id),
        ),
        'UpdateVariant error',
      );
    } finally {
      _inflightLines.remove(item.id);
      _emitClearPending(emit, item.id, 'UpdateVariant done');
    }
  }

  Future<void> _handleUpdateVariant(
    UpdateCartItemVariantEvent event,
    Emitter<CartState> emit,
  ) async {
    final item = _line(event.itemId);
    if (item == null) return;

    if (item.variantId == event.newVariant.id) return;

    int targetQty = item.quantity;
    if (targetQty > event.newVariant.stockOnHand && event.newVariant.stockOnHand > 0) {
      targetQty = event.newVariant.stockOnHand;
    }
    if (targetQty < 1) targetQty = 1;

    final newSize = ProductMapper.optionValue(event.newVariant, 'Size') ?? item.selectedSize;
    final newColor = ProductMapper.optionValue(event.newVariant, 'Color');

    debugPrint('===== CART VARIANT CHANGE =====');
    debugPrint('PRODUCT ID = ${item.productId}');
    debugPrint('OLD VARIANT ID = ${item.variantId}');
    debugPrint('OLD VARIANT NAME = ${item.productName}');
    debugPrint('SELECTED SIZE = $newSize');
    debugPrint('SELECTED COLOR = $newColor');
    debugPrint('NEW VARIANT ID = ${event.newVariant.id}');
    debugPrint('NEW VARIANT NAME = ${event.newVariant.variantName}');
    debugPrint('NEW STOCK = ${event.newVariant.stockOnHand}');
    debugPrint('CURRENT QTY = ${item.quantity}');
    debugPrint('FINAL QTY = $targetQty');
    debugPrint('===============================');

    final request = await _buildKitWriteRequest(
      itemType: item.itemType,
      targetProductId: item.productId,
      targetVariantId: event.newVariant.id,
      targetQuantity: targetQty,
      targetSize: newSize,
      targetCategory: item.categoryName,
      targetProductClass: item.productClass ?? 'single_item',
      targetProductName: event.newVariant.variantName,
      lineIdToSkip: item.id,
    );

    _perf('UPDATE/POST START op=VARIANT line=${event.itemId}');
    await _writeThenGet(
      emit,
      request: request,
      source: 'UpdateVariant',
      lineId: item.id,
    );
  }

  Future<void> _flushQty(String itemId, Emitter<CartState> emit) async {
    while (true) {
      final item = _line(itemId);
      final desired = _desiredQty[itemId];
      if (item == null || desired == null) return;
      if (desired == item.quantity) {
        _desiredQty.remove(itemId);
        return;
      }
      if (desired <= 0) {
        _desiredQty.remove(itemId);
        await _handleRemove(itemId, emit);
        return;
      }
      final request = await _buildKitWriteRequest(
        itemType: item.itemType,
        targetProductId: item.productId,
        targetVariantId: item.variantId,
        targetQuantity: desired,
        targetSize: item.selectedSize,
        targetCategory: item.categoryName,
        targetProductClass: item.productClass ?? 'single_item',
        targetProductName: item.productName,
        lineIdToSkip: item.id,
      );

      await _writeThenGet(
        emit,
        request: request,
        source: 'UpdateQuantity',
        lineId: itemId,
      );
    }
  }

  Future<void> _onQty(
    UpdateCartItemQuantityEvent event,
    Emitter<CartState> emit,
  ) async {
    final item = _line(event.itemId);
    if (item == null) return;
    if (state.isLinePending(item.id) && !_qtyFlushing.contains(item.id)) {
      return;
    }
    _desiredQty[item.id] = event.quantity;
    _perf('QUANTITY START line=${item.id} desired=${event.quantity}');
    if (_qtyFlushing.contains(item.id)) {
      _perf('QUANTITY COALESCE line=${item.id} desired=${event.quantity}');
      return;
    }
    await _runQtyFlush(item.id, emit);
  }

  Future<void> _onAdjust(
    AdjustCartItemQuantityEvent event,
    Emitter<CartState> emit,
  ) async {
    final item = _line(event.itemId);
    if (item == null || event.delta == 0) return;
    if (state.isLinePending(item.id) && !_qtyFlushing.contains(item.id)) {
      return;
    }
    final next = (_desiredQty[item.id] ?? item.quantity) + event.delta;
    _desiredQty[item.id] = next;
    _perf(
      'QUANTITY START line=${item.id} desired=$next delta=${event.delta}',
    );
    if (_qtyFlushing.contains(item.id)) {
      _perf('QUANTITY COALESCE line=${item.id} desired=$next');
      return;
    }
    await _runQtyFlush(item.id, emit);
  }

  Future<void> _runQtyFlush(String itemId, Emitter<CartState> emit) async {
    final opSw = Stopwatch()..start();
    _qtyFlushing.add(itemId);
    if (!_inflightLines.contains(itemId)) {
      _inflightLines.add(itemId);
      _emitLogged(
        emit,
        state.copyWith(pendingLineIds: _pendingPlus(itemId)),
        'Quantity pending',
      );
    }
    try {
      await _enqueueLine(itemId, () async {
        final desired = _desiredQty[itemId] ?? 0;
        if (desired <= 0) {
          _desiredQty.remove(itemId);
          await _handleRemove(itemId, emit);
          return;
        }
        await _flushQty(itemId, emit);
      });
    } catch (e) {
      _emitLogged(
        emit,
        state.copyWith(
          status: CartStatus.loaded,
          errorMessage: e.toString(),
          pendingLineIds: _pendingMinus(itemId),
        ),
        'UpdateQuantity error',
      );
    } finally {
      _qtyFlushing.remove(itemId);
      _inflightLines.remove(itemId);
      _emitClearPending(emit, itemId, 'Quantity done');
      opSw.stop();
      _perf(
        'UI COMPLETE duration=${opSw.elapsedMilliseconds}ms op=QUANTITY line=$itemId',
      );
    }
  }

  Future<void> _onClear(ClearCartEvent event, Emitter<CartState> emit) async {
    await _enqueue(() async {
      try {
        _emitLogged(
          emit,
          state.copyWith(status: CartStatus.updating),
          'ClearCart',
        );
        for (final item in List<CartItem>.from(state.items)) {
          await _repository.upsert(
            request: CartWriteRequest(
              productId: item.productId,
              variantId: item.variantId,
              quantity: 0,
              itemType: item.itemType,
              productClass: item.productClass ?? 'single_item',
            ),
            requestId: _repository.nextRequestId(),
            source: 'ClearCart',
          );
        }
        await _getAuthoritative(emit, source: 'ClearCart.afterPost');
      } catch (_) {
        try {
          await _getAuthoritative(emit, source: 'ClearCart.error');
        } catch (e, st) {
          _completeRefreshWaiters(state.remote, e, st);
        }
      }
    });
  }

  Future<void> _onClearLocal(
    ClearLocalCartEvent event,
    Emitter<CartState> emit,
  ) async {
    _desiredQty.clear();
    _inflightLines.clear();
    _qtyFlushing.clear();
    _lineOps.clear();
    _latestApplyId = _repository.nextRequestId();
    _emitLogged(
      emit,
      const CartState(status: CartStatus.loaded),
      'ClearLocalCart',
    );
  }

  Future<void> _onClearPaid(
    ClearPaidRentalItemsEvent event,
    Emitter<CartState> emit,
  ) async {
    await _enqueue(() async {
      final paid = List<CartItem>.from(state.paidRentalGarmentItems);
      if (paid.isEmpty) return;
      try {
        for (final item in paid) {
          await _repository.upsert(
            request: CartWriteRequest(
              productId: item.productId,
              variantId: item.variantId,
              quantity: 0,
              itemType: item.itemType,
              productClass: item.productClass ?? 'single_item',
            ),
            requestId: _repository.nextRequestId(),
            source: 'ClearPaidRental',
          );
        }
        await _getAuthoritative(emit, source: 'ClearPaidRental.afterPost');
      } catch (e) {
        _emitLogged(
          emit,
          state.copyWith(status: CartStatus.loaded, errorMessage: e.toString()),
          'ClearPaidRental error',
        );
      }
    });
  }
}

int calculateCurrentSubscriptionGarmentCount(List<CartItem> items) {
  return items.fold<int>(
    0,
    (sum, item) =>
        item.itemType == 'subscription' ? sum + item.quantity : sum,
  );
}
