import 'package:flutter/foundation.dart';
import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/core/utils/api_id_utils.dart';
import 'package:nomowear/features/cart/data/models/remote_cart.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';

// TODO(CART_DEBUG): Remove after verification.
const bool _kCartDebugLogs = true;

void _cartRepoDebug(String message) {
  if (_kCartDebugLogs && kDebugMode) {
    debugPrint('[CART_DEBUG] $message');
  }
}

class CartRepository {
  CartRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
    ProfileRepository? profileRepository,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage(),
        _profileRepository = profileRepository ?? ProfileRepository();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;
  final ProfileRepository _profileRepository;

  Future<RemoteCart> getCart() async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.get(
      ApiConstants.cartPath,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load cart',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      return const RemoteCart(id: '', items: []);
    }

    final remote = RemoteCart.fromJson(data);
    _cartRepoDebug(
      'Repo GET /cart parsed — count=${remote.items.length} '
      'ids=[${remote.items.map((e) => '${e.productId}|${e.variantId ?? '-'}').join(', ')}]',
    );
    return remote;
  }

  Future<RemoteCart> upsertItem({
    required CartItem item,
    required CartState cartState,
    int? quantity,
  }) async {
    if (!isApiUuid(item.productId)) {
      throw const ApiException(
        'Invalid product in cart. Remove it and add items from the catalog again.',
      );
    }

    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final body = <String, dynamic>{
      'productId': item.productId,
      'quantity': quantity ?? item.quantity,
    };

    final variantId = item.variantId?.trim();
    if (variantId != null && variantId.isNotEmpty && isApiUuid(variantId)) {
      body['variantId'] = variantId;
    }

    final size = item.selectedSize.trim();
    if (size.isNotEmpty) {
      body['size'] = size;
    }

    final kitDetails = await _buildKitDetails(
      item: item,
      cartState: cartState,
    );
    if (kitDetails != null && kitDetails.isNotEmpty) {
      body['kitDetails'] = kitDetails;
    }

    if (kitDetails != null) {
      final kitProductId = cartState.wardrobeKitProductId?.trim();
      body['product_class'] = kitProductId != null && item.productId == kitProductId
          ? 'wardrobe_kit'
          : 'single_item';
    } else if (item.isEssential) {
      body['product_class'] = 'single_item';
    }

    final json = await _apiClient.post(
      ApiConstants.cartPath,
      body,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to update cart',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid cart response');
    }

    final remote = RemoteCart.fromJson(data);
    _cartRepoDebug(
      'Repo POST /cart parsed — count=${remote.items.length} '
      'ids=[${remote.items.map((e) => '${e.productId}|${e.variantId ?? '-'}').join(', ')}] '
      'upserted=${item.productId}',
    );
    return remote;
  }

  Future<RemoteCart> removeItem({
    required CartItem item,
    required CartState cartState,
  }) {
    return upsertItem(item: item, cartState: cartState, quantity: 0);
  }

  /// Clears all items from the server cart after a successful order.
  Future<void> clearRemoteCart(CartState cartState) async {
    final remote = await getCart();
    if (remote.items.isEmpty) return;

    for (final remoteItem in remote.items) {
      final item = CartItem(
        id: remoteItem.variantId != null && remoteItem.variantId!.isNotEmpty
            ? '${remoteItem.productId}_${remoteItem.variantId}'
            : remoteItem.productId,
        productId: remoteItem.productId,
        variantId: remoteItem.variantId,
        title: remoteItem.productName,
        imageUrl: '',
      );
      await upsertItem(item: item, cartState: cartState, quantity: 0);
    }
  }

  Future<RemoteCart> syncCartState(CartState cartState) async {
    RemoteCart? latest;
    for (final item in cartState.items) {
      latest = await upsertItem(item: item, cartState: cartState);
    }
    return latest ?? await getCart();
  }

  Future<RemoteCart> ensureCartReady(
    CartState cartState, {
    bool requireWardrobeKitDetails = false,
  }) async {
    final invalidItems = cartState.items
        .where((item) => !isApiUuid(item.productId))
        .toList();
    if (invalidItems.isNotEmpty) {
      throw const ApiException(
        'Some cart items are invalid. Remove them and add products from the catalog again.',
      );
    }

    // Fast path for checkout: cart mutations are already synced by CartBloc
    // on add/size/qty updates, so avoid re-posting every item here.
    final remote = await getCart();
    if (!remote.isEmpty) return remote;

    // Fallback sync only when server cart is unexpectedly empty.
    if (cartState.items.isNotEmpty) {
      var synced = await syncCartState(cartState);
      if (requireWardrobeKitDetails && cartState.wardrobeItems.isNotEmpty) {
        synced = await _ensureWardrobeKitCheckoutOnServer(cartState, synced);
      }
      if (!synced.isEmpty) return synced;
    }
    return remote;
  }

  Future<RemoteCart> _ensureWardrobeKitCheckoutOnServer(
    CartState cartState,
    RemoteCart synced,
  ) async {
    RemoteCart? latest = synced;

    final kitProductId = cartState.wardrobeKitProductId?.trim();
    if (kitProductId != null && isApiUuid(kitProductId)) {
      latest = await upsertItem(
        item: CartItem(
          id: kitProductId,
          productId: kitProductId,
          title: cartState.wardrobeKitName.isNotEmpty
              ? cartState.wardrobeKitName
              : 'Wardrobe Kit',
          imageUrl: '',
          quantity: 1,
          isEssential: false,
        ),
        cartState: cartState,
      );
    }

    for (final item in cartState.wardrobeItems) {
      latest = await upsertItem(item: item, cartState: cartState);
    }

    final refreshed = latest ?? await getCart();
    final hasKitProduct = kitProductId != null &&
        refreshed.items.any((item) => item.productId == kitProductId);
    final hasKitGarments =
        refreshed.items.any((item) => item.kitDetails != null);

    if (!hasKitProduct && !hasKitGarments) {
      throw const ApiException(
        'Wardrobe kit could not be prepared for checkout. Please go back, '
        'reselect your kit and delivery details, then try again.',
      );
    }
    return refreshed;
  }

  Future<Map<String, dynamic>?> _buildKitDetails({
    required CartItem item,
    required CartState cartState,
  }) async {
    if (item.isEssential) return null;

    final session = CheckoutSession.instance;
    var customer = ProfileCache.instance.customer;
    try {
      customer ??= await _profileRepository.getProfile();
    } catch (_) {
      customer = ProfileCache.instance.customer;
    }

    final addressId = _resolveAddressId(session, customer);

    final details = RemoteCartKitDetails(
      gender: session.gender ?? 'male',
      bodyType: session.bodyType ?? 'regular',
      kitType: session.kitType ??
          (cartState.wardrobeKitName.isNotEmpty
              ? cartState.wardrobeKitName.toLowerCase()
              : 'standard'),
      deliveryDate: session.apiDeliveryDate,
      deliveryTime: session.deliveryTime,
      customerAddressId: addressId,
      height: customer?.height,
      weight: customer?.weight,
      wardrobeKitId: cartState.wardrobeKitId,
      wardrobeKitProductId: cartState.wardrobeKitProductId,
      durationDays: cartState.wardrobeKitDays,
    );

    final json = details.toJson();
    return json.isEmpty ? null : json;
  }

  String? _resolveAddressId(dynamic session, dynamic customer) {
    var addressId = session.addressId?.toString().trim();
    if (addressId != null && addressId.isNotEmpty) return addressId;

    for (final address in customer?.addresses ?? const []) {
      final id = address.id?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }
}
