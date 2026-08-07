import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists cart thumbnail URLs chosen at add-time.
///
/// Backend cart responses do not include image URLs, and product primary images
/// often differ from the color variant the user selected. Without this cache,
/// [LoadCartEvent] after restart falls back to the wrong catalog image.
class CartImageCache {
  CartImageCache._();

  static final CartImageCache instance = CartImageCache._()..restore();

  static const _prefsKey = 'cart_item_image_urls_v1';

  final Map<String, String> _images = {};
  bool _didRestore = false;
  Future<void>? _restoreFuture;

  static String keyFor({required String productId, String? variantId}) {
    final variant = variantId?.trim();
    if (variant != null && variant.isNotEmpty) {
      return '${productId.trim()}_$variant';
    }
    return productId.trim();
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

  Future<void> _restoreOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _images.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final url = value?.toString().trim() ?? '';
            if (key.toString().isNotEmpty && url.isNotEmpty) {
              _images[key.toString()] = url;
            }
          });
        }
      } catch (_) {
        // Corrupt cache — start fresh.
      }
    }
    _didRestore = true;
  }

  String? get({required String productId, String? variantId}) {
    final url = _images[keyFor(productId: productId, variantId: variantId)];
    if (url == null || url.isEmpty) return null;
    return url;
  }

  Future<void> remember(
    String imageUrl, {
    required String productId,
    String? variantId,
  }) async {
    final url = imageUrl.trim();
    if (url.isEmpty || productId.trim().isEmpty) return;
    await restore();
    _images[keyFor(productId: productId, variantId: variantId)] = url;
    await _persist();
  }

  Future<void> forget({required String productId, String? variantId}) async {
    await restore();
    _images.remove(keyFor(productId: productId, variantId: variantId));
    await _persist();
  }

  Future<void> clear() async {
    _images.clear();
    _didRestore = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_images));
  }
}
