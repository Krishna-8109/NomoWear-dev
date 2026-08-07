import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:nomowear/features/cart/data/cart_image_cache.dart';
import 'package:nomowear/features/cart/data/cart_repository.dart';
import 'package:nomowear/features/cart/data/models/remote_cart.dart';
import 'package:nomowear/features/cart/presentation/utils/cart_limits.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/products/data/models/product.dart';
import 'package:nomowear/features/products/data/models/product_variant.dart';
import 'package:nomowear/features/products/data/product_cache.dart';
import 'package:nomowear/features/products/data/product_catalog.dart';
import 'package:nomowear/features/subscriptions/data/subscription_cache.dart';

/// Process cart mutation events one-at-a-time so optimistic qty never races.
EventTransformer<E> _sequential<E>() {
  return (events, mapper) => events.asyncExpand(mapper);
}

// TODO(CART_DEBUG): Remove this flag and all `_cartDebug` calls after verification.
const bool _kCartDebugLogs = true;

void _cartDebug(String message) {
  if (_kCartDebugLogs && kDebugMode) {
    debugPrint('[CART_DEBUG] $message');
  }
}

String _cartItemIds(Iterable<CartItem> items) =>
    items.map((e) => '${e.productId}|${e.variantId ?? '-'}|qty=${e.quantity}').join(', ');

String _remoteItemIds(Iterable<RemoteCartItem> items) =>
    items.map((e) => '${e.productId}|${e.variantId ?? '-'}|qty=${e.quantity}').join(', ');


// ─────────────────────────── Model ────────────────────────────────
class CartItem extends Equatable {
  final String id;
  final String productId;
  final String? variantId;
  final String title;
  final String imageUrl;
  final String? price;
  String selectedSize;
  int quantity;
  final bool isEssential;
  final String? category;

  CartItem({
    required this.id,
    String? productId,
    this.variantId,
    required this.title,
    required this.imageUrl,
    this.price,
    this.selectedSize = 'M',
    this.quantity = 1,
    this.isEssential = false,
    this.category,
  }) : productId = productId ?? _resolveProductId(id, variantId);

  CartItem copyWith({
    String? selectedSize,
    int? quantity,
  }) {
    return CartItem(
      id: id,
      productId: productId,
      variantId: variantId,
      title: title,
      imageUrl: imageUrl,
      price: price,
      selectedSize: selectedSize ?? this.selectedSize,
      quantity: quantity ?? this.quantity,
      isEssential: isEssential,
      category: category,
    );
  }

  static String _resolveProductId(String id, String? variantId) {
    final variant = variantId?.trim();
    if (variant != null &&
        variant.isNotEmpty &&
        id.endsWith('_$variant')) {
      return id.substring(0, id.length - variant.length - 1);
    }
    return id;
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        variantId,
        title,
        imageUrl,
        price,
        selectedSize,
        quantity,
        isEssential,
        category,
      ];
}

// ─────────────────────────── Events ───────────────────────────────
abstract class CartEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadCartEvent extends CartEvent {
  final bool forceRefresh;
  LoadCartEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class AddToCartEvent extends CartEvent {
  final CartItem item;
  AddToCartEvent(this.item);
  @override
  List<Object?> get props => [item];
}

class RemoveFromCartEvent extends CartEvent {
  final String itemId;
  RemoveFromCartEvent(this.itemId);
  @override
  List<Object?> get props => [itemId];
}

class UpdateCartItemSizeEvent extends CartEvent {
  final String itemId;
  final String size;
  UpdateCartItemSizeEvent(this.itemId, this.size);
  @override
  List<Object?> get props => [itemId, size];
}

class UpdateCartItemQuantityEvent extends CartEvent {
  final String itemId;
  final int quantity;
  UpdateCartItemQuantityEvent(this.itemId, this.quantity);
  @override
  List<Object?> get props => [itemId, quantity];
}

/// Relative qty change from listing/details steppers (avoids stale absolute qty).
class AdjustCartItemQuantityEvent extends CartEvent {
  final String itemId;
  final int delta;
  AdjustCartItemQuantityEvent(this.itemId, {required this.delta});
  @override
  List<Object?> get props => [itemId, delta];
}

/// Applies a POST /cart response after async sync (may run after the mutation handler).
class ApplyRemoteCartEvent extends CartEvent {
  final RemoteCart remote;
  final int seq;
  final CartState? preserveKitFrom;

  ApplyRemoteCartEvent({
    required this.remote,
    required this.seq,
    this.preserveKitFrom,
  });

  @override
  List<Object?> get props => [remote, seq, preserveKitFrom];
}

class ClearCartEvent extends CartEvent {}

/// Resets local cart UI/state only (no remote API). Used on logout / APK update.
class ClearLocalCartEvent extends CartEvent {}

class SetWardrobeKitDaysEvent extends CartEvent {
  final int kitDays;
  SetWardrobeKitDaysEvent(this.kitDays);
  @override
  List<Object?> get props => [kitDays];
}

class SetWardrobeKitEvent extends CartEvent {
  final String kitId;
  final String? wardrobeKitProductId;
  final int kitDays;
  final String kitName;
  final int maxGarments;
  final String kitPrice;
  /// Home wardrobe category lock key (e.g. "Comfort Wardrobe").
  final String? wardrobeCategory;

  SetWardrobeKitEvent({
    required this.kitId,
    this.wardrobeKitProductId,
    required this.kitDays,
    required this.kitName,
    required this.maxGarments,
    required this.kitPrice,
    this.wardrobeCategory,
  });

  @override
  List<Object?> get props => [
        kitId,
        wardrobeKitProductId,
        kitDays,
        kitName,
        maxGarments,
        kitPrice,
        wardrobeCategory,
      ];
}

/// Locks non-sub flow to one home wardrobe category before garments are added.
class LockWardrobeCategoryEvent extends CartEvent {
  final String wardrobeCategory;

  LockWardrobeCategoryEvent(this.wardrobeCategory);

  @override
  List<Object?> get props => [wardrobeCategory];
}

// ─────────────────────────── State ────────────────────────────────
class CartState extends Equatable {
  final List<CartItem> items;
  final int wardrobeKitDays;
  final String? wardrobeKitId;
  final String? wardrobeKitProductId;
  final String wardrobeKitName;
  final int wardrobeKitMaxGarments;
  final String? wardrobeKitPrice;
  /// Locked home wardrobe category for non-sub single-category rule.
  final String? wardrobeCategory;
  final bool isSyncing;

  const CartState({
    this.items = const [],
    this.wardrobeKitDays = 1,
    this.wardrobeKitId,
    this.wardrobeKitProductId,
    this.wardrobeKitName = '',
    this.wardrobeKitMaxGarments = 0,
    this.wardrobeKitPrice,
    this.wardrobeCategory,
    this.isSyncing = false,
  });

  int get totalItems => items.fold(0, (sum, e) => sum + e.quantity);

  List<CartItem> get wardrobeItems =>
      items.where((e) => !e.isEssential).toList();

  List<CartItem> get essentialItems =>
      items.where((e) => e.isEssential).toList();

  /// Non-subscription wardrobe kit: essentials are shown under the wardrobe
  /// section (SELECTED GARMENTS), not as a separate ESSENTIAL WEAR block.
  /// Subscription kit bookings and essentials-only carts are unchanged.
  bool get shouldGroupEssentialsUnderWardrobe {
    if (wardrobeItems.isEmpty) return false;
    if (CheckoutSession.instance.useSubscriptionBooking) return false;
    return true;
  }

  /// Items rendered in the wardrobe / SELECTED GARMENTS UI.
  List<CartItem> get groupedWardrobeItems {
    if (!shouldGroupEssentialsUnderWardrobe) return wardrobeItems;
    return [...wardrobeItems, ...essentialItems];
  }

  /// Items rendered in the standalone ESSENTIAL WEAR section.
  List<CartItem> get groupedEssentialItems {
    if (shouldGroupEssentialsUnderWardrobe) return const [];
    return essentialItems;
  }

  String get wardrobeKitTitle => wardrobeKitName.isNotEmpty
      ? wardrobeKitName
      : '$wardrobeKitDays Day wardrobe kit';

  static const Map<int, int> maxGarmentsByKitDays = {
    1: 4,
    3: 8,
    5: 8,
    7: 10,
  };

  int get maxWardrobeGarments => wardrobeKitMaxGarments > 0
      ? wardrobeKitMaxGarments
      : maxGarmentsByKitDays[wardrobeKitDays] ?? 4;

  int get wardrobeGarmentCount =>
      wardrobeItems.fold<int>(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;

  /// Resolves the cart line for a catalog product.
  /// Prefers an exact variant match, then falls back to any line for [productId]
  /// so listing/details UI stays in sync after remote cart reconcile.
  CartItem? lineForProduct(String? productId, {String? variantId}) {
    final pid = productId?.trim() ?? '';
    if (pid.isEmpty) return null;

    final vid = variantId?.trim();
    if (vid != null && vid.isNotEmpty) {
      for (final item in items) {
        if (item.productId == pid && item.variantId == vid) return item;
        if (item.id == '${pid}_$vid') return item;
      }
    }

    for (final item in items) {
      if (item.productId == pid) return item;
    }
    return null;
  }

  /// Quantity shown on product cards for [productId] (optionally a variant).
  int quantityForProduct(String? productId, {String? variantId}) {
    final pid = productId?.trim() ?? '';
    if (pid.isEmpty) return 0;

    final vid = variantId?.trim();
    if (vid != null && vid.isNotEmpty) {
      final exactQty = items
          .where(
            (item) =>
                item.productId == pid &&
                (item.variantId == vid || item.id == '${pid}_$vid'),
          )
          .fold<int>(0, (sum, item) => sum + item.quantity);
      if (exactQty > 0) return exactQty;
    }

    return items
        .where((item) => item.productId == pid)
        .fold<int>(0, (sum, item) => sum + item.quantity);
  }

  CartState copyWith({
    List<CartItem>? items,
    int? wardrobeKitDays,
    String? wardrobeKitId,
    String? wardrobeKitProductId,
    String? wardrobeKitName,
    int? wardrobeKitMaxGarments,
    String? wardrobeKitPrice,
    String? wardrobeCategory,
    bool? isSyncing,
    bool clearWardrobeKit = false,
  }) {
    return CartState(
      items: items ?? this.items,
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
      wardrobeCategory: clearWardrobeKit
          ? null
          : wardrobeCategory ?? this.wardrobeCategory,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  List<Object?> get props => [
        items,
        wardrobeKitDays,
        wardrobeKitId,
        wardrobeKitProductId,
        wardrobeKitName,
        wardrobeKitMaxGarments,
        wardrobeKitPrice,
        wardrobeCategory,
        isSyncing,
      ];
}

// ─────────────────────────── Bloc ─────────────────────────────────
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc({CartRepository? repository})
      : _repository = repository ?? CartRepository(),
        super(const CartState()) {
    on<LoadCartEvent>(_onLoadCart, transformer: _sequential());
    on<AddToCartEvent>(_onAddToCart, transformer: _sequential());
    on<RemoveFromCartEvent>(_onRemoveFromCart, transformer: _sequential());
    on<UpdateCartItemSizeEvent>(_onUpdateSize, transformer: _sequential());
    on<UpdateCartItemQuantityEvent>(
      _onUpdateQuantity,
      transformer: _sequential(),
    );
    on<AdjustCartItemQuantityEvent>(
      _onAdjustQuantity,
      transformer: _sequential(),
    );
    on<ApplyRemoteCartEvent>(_onApplyRemoteCart, transformer: _sequential());
    on<ClearCartEvent>(_onClearCart, transformer: _sequential());
    on<ClearLocalCartEvent>(_onClearLocalCart, transformer: _sequential());
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
      ));
    });
    on<LockWardrobeCategoryEvent>((event, emit) {
      final category = event.wardrobeCategory.trim();
      if (category.isEmpty) return;
      emit(state.copyWith(wardrobeCategory: category));
    });
  }

  final CartRepository _repository;
  Future<void>? _loadCartFuture;

  /// Bumped on every local mutation / clear so stale POST responses are ignored.
  int _mutationSeq = 0;

  /// Serializes network upserts so only the latest intent is applied.
  Future<void> _syncChain = Future<void>.value();

  Future<void> _onLoadCart(LoadCartEvent event, Emitter<CartState> emit) async {
    // Let in-flight POST reconciles finish so GET does not race them.
    await _syncChain.catchError((_) {});

    // Reuse existing in-memory cart when revisiting screens.
    if (!event.forceRefresh && state.items.isNotEmpty) return;
    if (_loadCartFuture != null) {
      await _loadCartFuture;
      return;
    }

    _loadCartFuture = _loadCartOnce(emit);
    try {
      await _loadCartFuture;
    } finally {
      _loadCartFuture = null;
    }
  }

  Future<void> _loadCartOnce(Emitter<CartState> emit) async {
    try {
      _cartDebug(
        'LoadCart START — local count=${state.items.length} '
        'ids=[${_cartItemIds(state.items)}]',
      );
      await CartImageCache.instance.restore();
      final remote = await _repository.getCart();
      _cartDebug(
        'GET /cart response — count=${remote.items.length} '
        'ids=[${_remoteItemIds(remote.items)}]',
      );
      if (remote.items.isEmpty) {
        // Keep non-sub category lock from session/kit setup even when cart
        // has no garments yet (user may still be on screenshot / listing).
        emit(state.copyWith(items: const []));
        await CartImageCache.instance.clear();
        _cartDebug('LoadCart DONE — local emptied (remote empty)');
        return;
      }

      final remoteMerged = remote.items
          .map((item) => _mapRemoteItem(item, state.items))
          .toList();
      // Treat server cart as source-of-truth on load to avoid stale local ghost items.
      // Re-apply non-sub category lock from session / inferred items after cold start.
      final restoredCategory = state.wardrobeCategory ??
          CheckoutSession.instance.wardrobeCategory ??
          CartLimits.lockedWardrobeCategory(
            state.copyWith(items: remoteMerged),
          );

      final kitMeta = _kitDetailsFromRemote(remote.items);
      final restoredKitDays = kitMeta?.durationDays ??
          (state.wardrobeKitDays > 0 ? state.wardrobeKitDays : null);
      final restoredKitId = kitMeta?.wardrobeKitId ?? state.wardrobeKitId;
      final restoredKitProductId =
          kitMeta?.wardrobeKitProductId ?? state.wardrobeKitProductId;
      final restoredKitName = (state.wardrobeKitName.trim().isNotEmpty)
          ? state.wardrobeKitName
          : (kitMeta?.kitType != null && kitMeta!.kitType!.trim().isNotEmpty
              ? _titleCaseKitName(kitMeta.kitType!)
              : null);

      emit(state.copyWith(
        items: remoteMerged,
        wardrobeCategory: restoredCategory,
        wardrobeKitDays: restoredKitDays,
        wardrobeKitId: restoredKitId,
        wardrobeKitProductId: restoredKitProductId,
        wardrobeKitName: restoredKitName,
      ));
      _cartDebug(
        'LoadCart DONE — final local count=${remoteMerged.length} '
        'ids=[${_cartItemIds(remoteMerged)}] '
        'groupEssentials=${state.copyWith(items: remoteMerged).shouldGroupEssentialsUnderWardrobe}',
      );
    } catch (e) {
      _cartDebug('LoadCart FAILED — keeping local state. error=$e');
      // Keep local cart when remote fetch fails.
    }
  }

  Future<void> _onAddToCart(
    AddToCartEvent event,
    Emitter<CartState> emit,
  ) async {
    _cartDebug(
      'AddToCart BEFORE — local count=${state.items.length} '
      'ids=[${_cartItemIds(state.items)}] '
      'adding=${event.item.productId}',
    );

    // Safety net: non-subscribers cannot mix wardrobe categories in one cart.
    // UI should already block via tryAddToCart; this prevents direct AddToCartEvent bypass.
    if (CartLimits.wouldViolateSingleCategoryRule(
      state,
      incomingCategory: event.item.category,
      isEssential: event.item.isEssential,
    )) {
      _cartDebug('AddToCart BLOCKED — single-category rule');
      return;
    }

    if (!event.item.isEssential) {
      final nextCount = _countAfterAdding(state, event.item);
      final maxAllowed = CartLimits.effectiveMaxWardrobeGarments(state);
      if (nextCount > maxAllowed) {
        _cartDebug(
          'AddToCart BLOCKED — wardrobe garment limit '
          'next=$nextCount max=$maxAllowed '
          'kitMax=${state.maxWardrobeGarments} '
          'subRemaining=${SubscriptionCache.instance.remainingGarmentsBalance}',
        );
        return;
      }
    }

    final existing = state.items.indexWhere(
      (e) => _isSameCartLine(e, event.item),
    );
    final updatedList = List<CartItem>.from(state.items);
    late CartItem syncedItem;
    if (existing >= 0) {
      syncedItem = updatedList[existing]
          .copyWith(quantity: updatedList[existing].quantity + 1);
      updatedList[existing] = syncedItem;
    } else {
      syncedItem = event.item;
      updatedList.add(syncedItem);
    }

    // Lock the wardrobe category on first non-essential add (non-sub rule).
    final shouldLockCategory = !event.item.isEssential &&
        (state.wardrobeCategory == null ||
            state.wardrobeCategory!.trim().isEmpty) &&
        (event.item.category?.trim().isNotEmpty ?? false);

    final newState = state.copyWith(
      items: updatedList,
      wardrobeCategory:
          shouldLockCategory ? event.item.category : state.wardrobeCategory,
    );
    emit(newState);
    _cartDebug(
      'AddToCart AFTER optimistic emit — local count=${newState.items.length} '
      'ids=[${_cartItemIds(newState.items)}]',
    );
    await CartImageCache.instance.remember(
      syncedItem.imageUrl,
      productId: syncedItem.productId,
      variantId: syncedItem.variantId,
    );
    _enqueueSync(syncedItem);
  }

  Future<void> _onRemoveFromCart(
    RemoveFromCartEvent event,
    Emitter<CartState> emit,
  ) async {
    final removed = _findLineById(event.itemId);
    if (removed == null) return;

    final updatedList =
        state.items.where((e) => e.id != removed.id).toList();
    await CartImageCache.instance.forget(
      productId: removed.productId,
      variantId: removed.variantId,
    );
    late CartState optimistic;
    if (updatedList.isEmpty) {
      optimistic = const CartState();
      emit(optimistic);
      await CartImageCache.instance.clear();
      CheckoutSession.instance.clearWardrobeCategoryLock();
    } else {
      final next = state.copyWith(items: updatedList);
      final hasWardrobe = next.wardrobeItems.isNotEmpty;
      optimistic = hasWardrobe
          ? next
          : next.copyWith(clearWardrobeKit: true);
      emit(optimistic);
      if (!hasWardrobe) {
        CheckoutSession.instance.clearWardrobeCategoryLock();
      }
    }
    // Use pre-remove snapshot for kitDetails payload on qty=0 upsert.
    _enqueueSync(
      removed.copyWith(quantity: 0),
      quantityOverride: 0,
      preserveKitFrom: optimistic,
    );
  }

  Future<void> _onUpdateSize(
    UpdateCartItemSizeEvent event,
    Emitter<CartState> emit,
  ) async {
    final current = _findLineById(event.itemId);
    if (current == null) return;

    final updatedList = state.items.map((e) {
      if (e.id == current.id) return e.copyWith(selectedSize: event.size);
      return e;
    }).toList();
    final newState = state.copyWith(items: updatedList);
    emit(newState);
    final item = updatedList.firstWhere((e) => e.id == current.id);
    _enqueueSync(item);
  }

  Future<void> _onAdjustQuantity(
    AdjustCartItemQuantityEvent event,
    Emitter<CartState> emit,
  ) async {
    final current = _findLineById(event.itemId);
    if (current == null || event.delta == 0) return;

    final nextQty = current.quantity + event.delta;
    if (nextQty <= 0) {
      await _onRemoveFromCart(RemoveFromCartEvent(current.id), emit);
      return;
    }
    await _onUpdateQuantity(
      UpdateCartItemQuantityEvent(current.id, nextQty),
      emit,
    );
  }

  Future<void> _onUpdateQuantity(
    UpdateCartItemQuantityEvent event,
    Emitter<CartState> emit,
  ) async {
    final current = _findLineById(event.itemId);
    if (current == null) return;

    if (event.quantity <= 0) {
      await _onRemoveFromCart(RemoveFromCartEvent(current.id), emit);
      return;
    }

    if (!current.isEssential && event.quantity > current.quantity) {
      final nextWardrobeCount =
          state.wardrobeGarmentCount + (event.quantity - current.quantity);
      final maxAllowed = CartLimits.effectiveMaxWardrobeGarments(state);
      if (nextWardrobeCount > maxAllowed) {
        _cartDebug(
          'UpdateQuantity BLOCKED — wardrobe garment limit '
          'next=$nextWardrobeCount max=$maxAllowed',
        );
        return;
      }
    }

    final updatedList = state.items.map((e) {
      if (e.id == current.id) return e.copyWith(quantity: event.quantity);
      return e;
    }).toList();
    final newState = state.copyWith(items: updatedList);
    emit(newState);
    final item = updatedList.firstWhere((e) => e.id == current.id);
    _enqueueSync(item);
  }

  Future<void> _onClearCart(ClearCartEvent event, Emitter<CartState> emit) async {
    _mutationSeq++;
    final snapshot = state;
    emit(const CartState());
    await CartImageCache.instance.clear();
    CheckoutSession.instance.clearWardrobeCategoryLock();
    try {
      await _repository.clearRemoteCart(snapshot);
    } catch (_) {
      // Local cart is already cleared; server sync can retry later.
    }
  }

  /// Local-only wipe so previous user's cart never remains after logout/update.
  Future<void> _onClearLocalCart(
    ClearLocalCartEvent event,
    Emitter<CartState> emit,
  ) async {
    _mutationSeq++;
    emit(const CartState());
    await CartImageCache.instance.clear();
    CheckoutSession.instance.clearWardrobeCategoryLock();
  }

  Future<void> _onApplyRemoteCart(
    ApplyRemoteCartEvent event,
    Emitter<CartState> emit,
  ) async {
    if (event.seq != _mutationSeq) {
      _cartDebug(
        'ApplyRemoteCart SKIPPED — stale seq=${event.seq} current=$_mutationSeq',
      );
      return;
    }

    final remote = event.remote;
    _cartDebug(
      'ApplyRemoteCart — count=${remote.items.length} '
      'ids=[${_remoteItemIds(remote.items)}]',
    );

    // Cart was cleared while this sync was in flight.
    if (state.isEmpty && remote.items.isNotEmpty) {
      _cartDebug('ApplyRemoteCart SKIPPED — local cart already cleared');
      return;
    }

    final metadataSource = event.preserveKitFrom ?? state;
    final mapped = remote.items
        .map((e) => _mapRemoteItem(e, state.items))
        .toList();

    if (mapped.isEmpty) {
      emit(const CartState());
      _cartDebug('AFTER reconcile from POST — local emptied (remote empty)');
      return;
    }

    final hasWardrobe = mapped.any((e) => !e.isEssential) ||
        (metadataSource.wardrobeKitId?.trim().isNotEmpty ?? false) ||
        (metadataSource.wardrobeCategory?.trim().isNotEmpty ?? false);
    final nextState = hasWardrobe
        ? metadataSource.copyWith(items: mapped)
        : metadataSource.copyWith(items: mapped, clearWardrobeKit: true);

    if (state.isEmpty && nextState.items.isNotEmpty) {
      _cartDebug(
        'ApplyRemoteCart SKIPPED after map — local cart cleared',
      );
      return;
    }

    if (event.seq != _mutationSeq) {
      _cartDebug(
        'ApplyRemoteCart SKIPPED before emit — superseded seq=${event.seq}',
      );
      return;
    }

    emit(nextState);
    _cartDebug(
      'AFTER reconcile from POST — local count=${nextState.items.length} '
      'ids=[${_cartItemIds(nextState.items)}] '
      'postCount=${remote.items.length} '
      'mismatch=${nextState.items.length != remote.items.length}',
    );
  }

  /// Queues a POST /cart without blocking the next optimistic mutation.
  void _enqueueSync(
    CartItem item, {
    int? quantityOverride,
    CartState? preserveKitFrom,
  }) {
    final seq = ++_mutationSeq;
    _syncChain = _syncChain.catchError((_) {}).then((_) async {
      if (seq != _mutationSeq) {
        _cartDebug(
          'POST /cart skipped before send — seq=$seq current=$_mutationSeq',
        );
        return;
      }

      var toSend = item;
      var qty = quantityOverride;
      if (quantityOverride == null) {
        final live = _findLineMatching(item);
        if (live == null) {
          toSend = item.copyWith(quantity: 0);
          qty = 0;
        } else {
          toSend = live;
          qty = live.quantity;
        }
      }

      try {
        final remote = await _repository.upsertItem(
          item: toSend,
          cartState: preserveKitFrom ?? state,
          quantity: qty,
        );
        if (seq != _mutationSeq) {
          _cartDebug(
            'POST /cart response ignored — seq=$seq current=$_mutationSeq',
          );
          return;
        }
        add(
          ApplyRemoteCartEvent(
            remote: remote,
            seq: seq,
            preserveKitFrom: preserveKitFrom,
          ),
        );
      } catch (e) {
        _cartDebug(
          'POST /cart FAILED — keeping optimistic local state. error=$e',
        );
      }
    });
  }

  CartItem? _findLineById(String itemId) {
    final id = itemId.trim();
    if (id.isEmpty) return null;

    for (final item in state.items) {
      if (item.id == id) return item;
    }
    for (final item in state.items) {
      if (item.productId == id) return item;
      final vid = item.variantId?.trim();
      if (vid != null && vid.isNotEmpty && id == '${item.productId}_$vid') {
        return item;
      }
    }
    return null;
  }

  CartItem? _findLineMatching(CartItem target) {
    for (final item in state.items) {
      if (_isSameCartLine(item, target)) return item;
    }
    return null;
  }

  CartItem? _findLocalForRemote(
    RemoteCartItem remote,
    List<CartItem> existing,
  ) {
    final pid = remote.productId.trim();
    if (pid.isEmpty) return null;

    final remoteVariant = remote.variantId?.trim();
    if (remoteVariant != null && remoteVariant.isNotEmpty) {
      for (final item in existing) {
        if (item.productId == pid && item.variantId == remoteVariant) {
          return item;
        }
        if (item.id == '${pid}_$remoteVariant') return item;
      }
    }

    final byProduct =
        existing.where((item) => item.productId == pid).toList(growable: false);
    if (byProduct.isEmpty) return null;
    // Remote often omits/changes variantId after POST; keep the local line so
    // listing cards that key off productId_variantId stay matched.
    if (byProduct.length == 1 ||
        remoteVariant == null ||
        remoteVariant.isEmpty) {
      return byProduct.first;
    }
    return byProduct.first;
  }

  /// True when [a] and [b] represent the same cart line across optimistic/remote ids.
  bool _isSameCartLine(CartItem a, CartItem b) {
    if (a.id == b.id) return true;
    if (a.productId.trim() != b.productId.trim()) return false;
    final av = a.variantId?.trim();
    final bv = b.variantId?.trim();
    if (av != null && av.isNotEmpty && bv != null && bv.isNotEmpty) {
      return av == bv;
    }
    // Missing variant on either side — treat same product as same line.
    return true;
  }

  CartItem _mapRemoteItem(RemoteCartItem remote, List<CartItem> existing) {
    final local = _findLocalForRemote(remote, existing);
    final resolvedVariantId =
        (remote.variantId != null && remote.variantId!.trim().isNotEmpty)
            ? remote.variantId!.trim()
            : local?.variantId;

    final cachedProduct = ProductCache.instance.findById(remote.productId);
    final imageUrl = _resolveCartImageUrl(
      productId: remote.productId,
      variantId: resolvedVariantId,
      localImageUrl: local?.imageUrl,
      product: cachedProduct,
    );

    final fallbackCategory = cachedProduct?.categoryName;

    final fallback = local ??
        CartItem(
          id: remote.productId,
          productId: remote.productId,
          variantId: resolvedVariantId,
          title: remote.productName,
          imageUrl: imageUrl,
          category: fallbackCategory,
        );

    final id = resolvedVariantId != null && resolvedVariantId.isNotEmpty
        ? '${remote.productId}_$resolvedVariantId'
        : (local?.id ?? remote.productId);

    if (imageUrl.isNotEmpty) {
      // Fire-and-forget: keep cold-start thumbnails aligned with last known URL.
      CartImageCache.instance.remember(
        imageUrl,
        productId: remote.productId,
        variantId: resolvedVariantId,
      );
    }

    return CartItem(
      id: id,
      productId: remote.productId,
      variantId: resolvedVariantId,
      title: remote.productName,
      imageUrl: imageUrl,
      price: _formatRemoteUnitPrice(remote.unitPrice),
      selectedSize: fallback.selectedSize,
      quantity: remote.quantity,
      isEssential: _resolveIsEssential(
        local: local,
        remote: remote,
        product: cachedProduct,
      ),
      // Preserve wardrobe category for non-sub single-category lock across reloads.
      category: (fallback.category != null &&
              fallback.category!.trim().isNotEmpty)
          ? fallback.category
          : fallbackCategory,
    );
  }

  bool _resolveIsEssential({
    required CartItem? local,
    required RemoteCartItem remote,
    Product? product,
  }) {
    if (local != null) return local.isEssential;
    // Kit-linked lines are wardrobe garments.
    if (remote.kitDetails != null) return false;
    if (product != null) {
      if (ProductCatalog.isDirectPurchaseProduct(product)) return true;
      if (product.isWardrobeKit) return false;
      // Catalog single_item under a home wardrobe category is a garment.
      return false;
    }
    // Without catalog, prefer wardrobe so category lock still applies.
    return false;
  }

  String _formatRemoteUnitPrice(num unitPrice) {
    if (unitPrice == unitPrice.roundToDouble()) {
      return unitPrice.round().toString();
    }
    return unitPrice.toString();
  }

  RemoteCartKitDetails? _kitDetailsFromRemote(List<RemoteCartItem> items) {
    for (final item in items) {
      if (item.kitDetails != null) return item.kitDetails;
    }
    return null;
  }

  String _titleCaseKitName(String raw) {
    final cleaned = raw.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return cleaned;
    return cleaned
        .split(RegExp(r'\s+'))
        .map((part) {
          if (part.isEmpty) return part;
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  /// Resolve thumbnail for a remote cart line.
  ///
  /// Priority: in-memory local → persisted add-time URL → variant image →
  /// same-color sibling variant → product primary / first gallery image.
  String _resolveCartImageUrl({
    required String productId,
    String? variantId,
    String? localImageUrl,
    Product? product,
  }) {
    final local = localImageUrl?.trim() ?? '';
    if (local.isNotEmpty) return local;

    final remembered = CartImageCache.instance.get(
      productId: productId,
      variantId: variantId,
    );
    if (remembered != null && remembered.isNotEmpty) return remembered;

    if (product == null) return '';

    ProductVariant? matched;
    final vid = variantId?.trim();
    if (vid != null && vid.isNotEmpty) {
      for (final variant in product.variants) {
        if (variant.id == vid) {
          matched = variant;
          break;
        }
      }
    }

    final fromVariant = matched?.primaryImageUrl?.trim() ?? '';
    if (fromVariant.isNotEmpty) return fromVariant;

    if (matched != null) {
      final color = _variantOption(matched.options, 'Color');
      if (color != null && color.isNotEmpty) {
        for (final variant in product.variants) {
          final otherColor = _variantOption(variant.options, 'Color');
          if (otherColor == null ||
              otherColor.toUpperCase() != color.toUpperCase()) {
            continue;
          }
          final url = variant.primaryImageUrl?.trim() ?? '';
          if (url.isNotEmpty) return url;
        }
      }
    }

    final primary = product.primaryImageUrl?.trim() ?? '';
    if (primary.isNotEmpty) return primary;
    if (product.imageUrls.isNotEmpty) {
      return product.imageUrls.first.trim();
    }
    return '';
  }

  String? _variantOption(Map<String, String> options, String key) {
    for (final entry in options.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        final value = entry.value.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  static int _countAfterAdding(CartState state, CartItem item) {
    final existing = state.lineForProduct(
      item.productId,
      variantId: item.variantId,
    );
    if (existing != null) {
      return state.wardrobeGarmentCount + 1;
    }
    return state.wardrobeGarmentCount + item.quantity;
  }
}
