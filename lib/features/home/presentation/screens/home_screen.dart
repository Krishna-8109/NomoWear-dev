import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/features/home/presentation/bloc/home_bloc.dart';
import 'package:nomowear/features/categories/presentation/screens/categories_screen.dart';
import 'package:nomowear/features/home/presentation/screens/subscription_tab_widget.dart';
import 'package:nomowear/features/subscriptions/presentation/bloc/subscription_bloc.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/auth/data/models/customer.dart';
import 'package:nomowear/features/banners/data/banner_cache.dart';
import 'package:nomowear/features/banners/data/banner_repository.dart';
import 'package:nomowear/features/banners/data/models/promo_banner.dart';
import 'package:nomowear/features/products/data/models/product.dart';
import 'package:nomowear/features/products/data/product_catalog.dart';
import 'package:nomowear/features/products/data/product_cache.dart';
import 'package:nomowear/features/products/data/product_repository.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';
import 'package:nomowear/features/profile/presentation/screens/profile_screen.dart';
import 'package:nomowear/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:nomowear/features/cart/presentation/screens/cart_screen.dart';
import 'package:nomowear/features/checkout/presentation/utils/wardrobe_booking_flow.dart';
import 'custom_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const HomeScreen({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<Map<String, String>> _fallbackBannerSlides = [
    {
      'title': 'Welcome to NOMOWEAR',
      'subtitle': 'Discover the Curated Wardrobe for Your\nEvery Journey',
      'image': ImageConstant.homeScreenImg6,
    },
    {
      'title': 'Premium Looks, On Demand',
      'subtitle': 'Curated outfits for work, events,\nand special days',
      'image': ImageConstant.homeScreenImg2,
    },
    {
      'title': 'Style Made Effortless',
      'subtitle':
          'Choose, rent, and wear with confidence\nfor every occasion',
      'image': ImageConstant.homeScreenImg4,
    },
  ];

  int _currentSlide = 0;
  final PageController _pageController = PageController(viewportFraction: 1.0);
  Timer? _timer;

  late HomeBloc _homeBloc;
  late SubscriptionBloc _subscriptionBloc;

  final ProfileRepository _profileRepository = ProfileRepository();
  final ProductRepository _productRepository = ProductRepository();
  final BannerRepository _bannerRepository = BannerRepository();
  final AuthStorage _authStorage = AuthStorage();
  Customer? _profile;
  bool _isLoadingProfile = true;

  List<PromoBanner> _banners = [];
  bool _isLoadingBanners = true;

  List<Product> _wardrobeProducts = [];
  Product? _essentialsProduct;
  bool _isLoadingProducts = true;

  /// Guards against overlapping pull-to-refresh / concurrent refreshes.
  bool _isRefreshingHome = false;

  int get _bannerSlideCount =>
      _banners.isNotEmpty ? _banners.length : _fallbackBannerSlides.length;

  Widget _buildSubscriptionContent(int tabIndex) {
    return const SubscriptionTabWidget();
  }
  @override
  void initState() {
    super.initState();
    _homeBloc = HomeBloc(initialBottomNavIndex: widget.initialTabIndex);
    _subscriptionBloc = SubscriptionBloc()
      ..add(LoadActiveSubscriptionEvent());
    _loadProfile();
    _loadProducts();
    _loadBanners();
  }

  Future<void> _loadProfile({
    bool forceRefresh = false,
    bool propagateError = false,
  }) async {
    final cached = ProfileCache.instance.customer;
    if (cached != null && !forceRefresh) {
      if (mounted) {
        setState(() {
          _profile = cached;
          _isLoadingProfile = false;
        });
      }
      return;
    }

    final token = await _authStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final profile = await _profileRepository.getProfile(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    } on ApiException {
      if (mounted) setState(() => _isLoadingProfile = false);
      if (propagateError) rethrow;
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
      if (propagateError) rethrow;
    }
  }

  Future<void> _loadProducts({
    bool forceRefresh = false,
    bool propagateError = false,
  }) async {
    if (!forceRefresh) {
      final cached = ProductCache.instance.products;
      if (cached != null) {
        _applyProducts(cached);
        if (mounted) setState(() => _isLoadingProducts = false);
        return;
      }
    }

    final token = await _authStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoadingProducts = false);
      return;
    }

    try {
      final products = await _productRepository.getProducts(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      _applyProducts(products);
      setState(() => _isLoadingProducts = false);
    } on ApiException {
      if (!mounted) return;
      setState(() => _isLoadingProducts = false);
      if (propagateError) rethrow;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProducts = false);
      if (propagateError) rethrow;
    }
  }

  void _applyProducts(List<Product> products) {
    _wardrobeProducts = ProductCatalog.homeWardrobeCards(products);
    _essentialsProduct = ProductCatalog.essentialsWardrobeProduct(products);
  }

  Future<void> _loadBanners({
    bool forceRefresh = false,
    bool propagateError = false,
  }) async {
    // Skip memory cache when refreshing so admin updates are visible immediately.
    if (!forceRefresh) {
      final cached = BannerCache.instance.banners;
      if (cached != null) {
        if (mounted) {
          setState(() {
            _banners = cached;
            _isLoadingBanners = false;
          });
        }
        _startAutoSlider();
        return;
      }
    }

    final token = await _authStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoadingBanners = false);
      _startAutoSlider();
      return;
    }

    try {
      final banners = await _bannerRepository.getBanners(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _banners = banners;
        _isLoadingBanners = false;
        if (_currentSlide >= _bannerSlideCount) {
          _currentSlide = 0;
        }
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _isLoadingBanners = false);
      if (propagateError) rethrow;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingBanners = false);
      if (propagateError) rethrow;
    }
    _startAutoSlider();
  }

  /// Pull-to-refresh: re-fetch all Home tab APIs in parallel, then stop indicator.
  Future<void> _onHomePullToRefresh() async {
    if (_isRefreshingHome) return;
    _isRefreshingHome = true;

    try {
      // Profile header, wardrobe/essentials products, and promo banners.
      // (Notifications count / categories APIs are not part of this Home tab.)
      final errors = <Object>[];
      await Future.wait([
        _runHomeRefreshTask(
          () => _loadProfile(forceRefresh: true, propagateError: true),
          errors,
        ),
        _runHomeRefreshTask(
          () => _loadProducts(forceRefresh: true, propagateError: true),
          errors,
        ),
        _runHomeRefreshTask(
          () => _loadBanners(forceRefresh: true, propagateError: true),
          errors,
        ),
      ]);

      if (!mounted || errors.isEmpty) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_homeRefreshErrorMessage(errors)),
            backgroundColor: const Color(0xFF2A2D36),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      _isRefreshingHome = false;
    }
  }

  Future<void> _runHomeRefreshTask(
    Future<void> Function() task,
    List<Object> errors,
  ) async {
    try {
      await task();
    } catch (error) {
      errors.add(error);
    }
  }

  String _homeRefreshErrorMessage(List<Object> errors) {
    for (final error in errors) {
      final text = error is ApiException ? error.message : error.toString();
      final lower = text.toLowerCase();
      if (lower.contains('network') ||
          lower.contains('connect') ||
          lower.contains('socket') ||
          lower.contains('offline') ||
          lower.contains('failed host lookup')) {
        return 'No Internet Connection';
      }
    }

    for (final error in errors) {
      if (error is ApiException && error.message.trim().isNotEmpty) {
        return error.message;
      }
    }

    return 'Unable to refresh. Please try again.';
  }

  void _startAutoSlider() {
    _timer?.cancel();
    if (_bannerSlideCount <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_pageController.hasClients) return;

      var nextPage = _currentSlide + 1;
      if (nextPage >= _bannerSlideCount) {
        nextPage = 0;
      }
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _subscriptionBloc.close();
    _homeBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _subscriptionBloc,
      child: BlocProvider.value(
        value: _homeBloc,
        child: BlocListener<HomeBloc, HomeState>(
          listenWhen: (previous, current) =>
              current.bottomNavIndex != previous.bottomNavIndex,
          listener: (_, state) {
            // Reuse loaded data when switching tabs; no forced API reload here.
            // Subscription tab itself handles subscription reload on first entry.
          },
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              return Scaffold(
                backgroundColor: const Color(0xFF0F1012),
                body: SafeArea(
                  child: Column(
                    children: [
                      Expanded(child: _buildBody(state.bottomNavIndex)),
                      CustomBottomNav(currentIndex: state.bottomNavIndex),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(int index) {
    return IndexedStack(
      index: index,
      children: [
        _buildHomeContent(),
        const CategoriesScreen(isTab: true),
        const CartScreen(),
        _buildSubscriptionContent(index),
        const ProfileScreen(isTab: true),
      ],
    );
  }

  Widget _buildHomeContent() {
    // RefreshIndicator needs a scrollable child; AlwaysScrollable lets pull
    // work even when content is shorter than the viewport.
    return RefreshIndicator(
      color: AppColours.primary,
      backgroundColor: const Color(0xFF16181D),
      displacement: 40,
      onRefresh: _onHomePullToRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20.h),
              _buildHeader(),
              SizedBox(height: 16.h),
              Container(
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
              ),
              SizedBox(height: 16.h),

              _buildBannerSlider(),
              SizedBox(height: 32.h),
              Text(
                "Choose Your Wardrobe",
                style: CustomTextStyles.montserratBold.copyWith(fontSize: 20),
              ),
              SizedBox(height: 20.h),
              _buildWardrobeGrid(),
              SizedBox(height: 24.h),
              _buildEssentialsBanner(),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          children: [
            SizedBox(height: 20.h),
            Text(
              "Categories",
              style: TextStyle(
                color: AppColours.primary,
                fontSize: 20.fSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Divider(color: AppColours.primary.withOpacity(0.2)),
            SizedBox(height: 24.h),
            Text(
              "Choose Your Wardrobe",
              style: TextStyle(
                color: AppColours.secondary,
                fontSize: 20.fSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24.h),
            _buildWardrobeGrid(),
            SizedBox(height: 24.h),
            _buildEssentialsBanner(),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_isLoadingProfile && _profile == null) {
      return const HomeHeaderShimmer();
    }

    final displayName = _profile?.fullName?.trim().isNotEmpty == true
        ? _profile!.fullName!
        : (_profile?.mobile ?? 'Guest');
    final photoUrl = _profile?.profilePhoto;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              height: 48.h,
              width: 48.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColours.primary, width: 1.5),
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl.startsWith('http')
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        width: 48.w,
                        height: 48.h,
                        errorBuilder: (_, __, ___) => Image.asset(
                          ImageConstant.homeScreenImg2,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        ImageConstant.homeScreenImg2,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "WELCOME",
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 12,
                    color: AppColours.primary,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  displayName,
                  style: CustomTextStyles.montserratBold.copyWith(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // GestureDetector(
            //   onTap: () => Navigator.pushNamed(context, AppRoutes.favoritesScreen),
            //   child: Container(
            //     padding: EdgeInsets.all(10.w),
            //     decoration: BoxDecoration(
            //       color: const Color(0xFF1A1D21),
            //       shape: BoxShape.circle,
            //       border: Border.all(color: Colors.white10),
            //     ),
            //     child: Icon(Icons.favorite_border, color: AppColours.primary, size: 24),
            //   ),
            // ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              child:SvgPicture.asset(IconConstant.notification)
              ),

          ],
        ),
      ],
    );
  }

  Widget _buildBannerSlider() {
    if (_isLoadingBanners) {
      return const BannerShimmer();
    }

    final useApiBanners = _banners.isNotEmpty;
    final slideCount = _bannerSlideCount;

    return SizedBox(
      height: 180.h,
      width: double.maxFinite,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentSlide = index;
          });
        },
        itemCount: slideCount,
        itemBuilder: (context, index) {
          if (useApiBanners) {
            final banner = _banners[index];
            return _buildBannerSlide(
              title: banner.title,
              subtitle: banner.description ?? '',
              imageUrl: banner.imageUrl,
              index: index,
              totalSlides: slideCount,
              isNetworkImage: true,
            );
          }

          final slide = _fallbackBannerSlides[index];
          return _buildBannerSlide(
            title: slide['title']!,
            subtitle: slide['subtitle']!,
            imageUrl: slide['image']!,
            index: index,
            totalSlides: slideCount,
            isNetworkImage: false,
          );
        },
      ),
    );
  }

  Widget _buildBannerSlide({
    required String title,
    required String subtitle,
    required String imageUrl,
    required int index,
    required int totalSlides,
    bool isNetworkImage = false,
  }) {
    return Container(
      width: 380.w,
      margin: EdgeInsets.only(right: 10.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6C279), width: 0.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isNetworkImage)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  ImageConstant.homeScreenImg6,
                  fit: BoxFit.cover,
                ),
              )
            else
              Image.asset(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            Container(
              color: Colors.black.withOpacity(0.35),
            ),
            Padding(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              style: CustomTextStyles.montserratBold.copyWith(fontSize: 20),
            ),

            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 12,
                color: AppColours.primary,
              ),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE6C279),
                minimumSize: Size(138.w, 54.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
              ),
              child: Text(
                "EXPLORE NOW",
                style: CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 12,
                  color: AppColours.black,
                ),
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalSlides,
                (dotIndex) => Container(
                  width: dotIndex == _currentSlide ? 18.w : 7.w,
                  height: 6.h,
                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: dotIndex == _currentSlide
                        ? const Color(0xFFE6C279)
                        : Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWardrobeGrid() {
    if (_isLoadingProducts) {
      return const WardrobeGridShimmer();
    }

    if (_wardrobeProducts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Text(
          'No wardrobes available right now.',
          textAlign: TextAlign.center,
          style: CustomTextStyles.openSansRegular.copyWith(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < _wardrobeProducts.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: 24.h));
      rows.add(
        Row(
          children: [
            Expanded(child: _buildWardrobeCard(_wardrobeProducts[i])),
            if (i + 1 < _wardrobeProducts.length) ...[
              SizedBox(width: 20.w),
              Expanded(child: _buildWardrobeCard(_wardrobeProducts[i + 1])),
            ] else
              Expanded(child: SizedBox(height: 180.h)),
          ],
        ),
      );
    }

    return Column(children: rows);
  }

  bool _isKidsWardrobe(Product product) {
    if (ProductCatalog.isKidsProduct(product)) return true;
    final name = product.productName.toLowerCase();
    final category = (product.categoryName ?? '').toLowerCase();
    return name.contains('kids') || category.contains('kids');
  }

  String _wardrobeButtonLabel(Product product) {
    return _isKidsWardrobe(product) ? 'BUY' : 'CHOOSE';
  }

  String _wardrobeCardTitle(Product product) {
    if (ProductCatalog.isKidsProduct(product)) return 'Kids Wardrobe';
    for (final key in ProductCatalog.homeWardrobeKeys) {
      if (product.productName == key) return key;
      if (product.categoryName == key) return key;
    }
    return product.productName;
  }

  String _wardrobeCardSubtitle(Product product) {
    final title = _wardrobeCardTitle(product);
    switch (title) {
      case 'Comfort Wardrobe':
        return 'Daily comfort · Travel · Lounge';
      case 'Professional Wardrobe':
        return 'Luxury · Occasion · Signature';
      case 'Premium Wardrobe':
        return 'Luxury · Parties · Special';
      case 'Kids Wardrobe':
        return 'Daily comfort · Travel · Lounge';
      default:
        return product.categoryName ?? '';
    }
  }

  Widget _buildWardrobeCard(Product product) {
    final title = _wardrobeCardTitle(product);
    final subtitle = _wardrobeCardSubtitle(product);
    final imageUrl = _isKidsWardrobe(product)
        ? (product.primaryImageUrl ?? ImageConstant.kidsWearImg1)
        : (product.primaryImageUrl ?? ImageConstant.homeScreenImg2);
    final buttonLabel = _wardrobeButtonLabel(product);

    return GestureDetector(
      onTap: () => _openWardrobe(product),

      child: Container(
        height: 180.h,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColours.primary.withOpacity(0.55),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFCFAF6E).withOpacity(0.12),
              blurRadius: 6,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    )
                  : Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: CustomTextStyles.openSansRegular.copyWith(
                        fontSize: 8,
                        color: AppColours.primary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      height: 28.h,
                      width: 80.w,
                      child: ElevatedButton(
                        onPressed: () => _openWardrobe(product),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColours.primary,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          buttonLabel,
                          style: CustomTextStyles.openSansSemiBold.copyWith(
                            color: AppColours.black,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWardrobe(Product product) {
    final categoryName = _wardrobeCardTitle(product);
    WardrobeBookingFlow.handleHomeProductChoose(
      context,
      product: product,
      wardrobeCategory: categoryName,
      isKidsCard: _isKidsWardrobe(product),
    );
  }

  void _openEssentialsWardrobe() {
    WardrobeBookingFlow.openEssentialsFlow(context);
  }

  Widget _buildEssentialsBanner() {
    if (_isLoadingProducts) {
      return const EssentialsBannerShimmer();
    }

    final essentials = _essentialsProduct;
    final title = essentials?.productName ?? 'Essentials Wardrobe';
    final imageUrl = essentials?.primaryImageUrl;

    return GestureDetector(
      onTap: _openEssentialsWardrobe,
      child: Container(
        width: double.maxFinite,
        height: 180.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColours.primary, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE6C279).withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
          image: imageUrl == null
              ? DecorationImage(
                  image: AssetImage(ImageConstant.homeScreenImg6),
                  fit: BoxFit.cover,
                )
              : null,
        ),

        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              if (imageUrl != null)
                Positioned.fill(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      ImageConstant.homeScreenImg6,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              /// 🔥 Bottom gradient (correct)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              /// 🔥 Content aligned to bottom
              Positioned(
                left: 16.w,
                right: 16.w,
                bottom: 14.h,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [

                    /// Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: AppColours.secondary,
                              fontSize: 16.fSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            essentials?.categoryName ??
                                'Comfort • Daily wear • Must haves',
                            style: CustomTextStyles.openSansRegular.copyWith(
                              fontSize: 8,
                              color: AppColours.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// Button
                    SizedBox(
                      height: 30.h,
                      child: ElevatedButton(
                        onPressed: _openEssentialsWardrobe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColours.primary,
                          padding: EdgeInsets.symmetric(horizontal: 40.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "BUY",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11.fSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

