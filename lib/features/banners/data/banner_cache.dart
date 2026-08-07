import 'package:nomowear/features/banners/data/models/promo_banner.dart';

class BannerCache {
  BannerCache._();

  static final BannerCache instance = BannerCache._();

  List<PromoBanner>? _banners;

  List<PromoBanner>? get banners => _banners;

  void set(List<PromoBanner> banners) {
    _banners = List.unmodifiable(banners);
  }

  void clear() {
    _banners = null;
  }
}
