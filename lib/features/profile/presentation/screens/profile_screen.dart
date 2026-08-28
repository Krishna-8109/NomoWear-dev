  import 'package:nomowear/core/app_export.dart';
  import 'package:flutter_svg/flutter_svg.dart';
  import 'package:nomowear/core/network/api_exception.dart';
  import 'package:nomowear/core/services/session_cleanup.dart';
  import 'package:nomowear/features/auth/data/models/customer.dart';
  import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';
  import 'package:nomowear/features/profile/presentation/screens/edit_profile_screen.dart';

  class ProfileScreen extends StatefulWidget {
    final bool isTab;
    const ProfileScreen({Key? key, this.isTab = false}) : super(key: key);

    @override
    State<ProfileScreen> createState() => _ProfileScreenState();
  }

  class _ProfileScreenState extends State<ProfileScreen> {
    final ProfileRepository _profileRepository = ProfileRepository();
    Customer? _profile;
    bool _isLoadingProfile = true;

    @override
    void initState() {
      super.initState();
      _loadProfile();
    }

    Future<void> _loadProfile({bool forceRefresh = false}) async {
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

      if (cached != null && mounted) {
        setState(() {
          _profile = cached;
          _isLoadingProfile = false;
        });
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
        if (!mounted) return;
        setState(() => _isLoadingProfile = false);
      } catch (_) {
        if (!mounted) return;
        setState(() => _isLoadingProfile = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      // if (isTab) return _buildProfileContent(context);

      return Scaffold(
        backgroundColor: const Color(0xFF0B0D18),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0D18),
          elevation: 0,
          centerTitle: true,
          title: Text(
            "Profile",
            style: TextStyle(
              color: const Color(0xFFE6C279),
              fontSize: 18.fSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [

              // ✅ YOUR GRADIENT DIVIDER HERE
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

              // ✅ बाकी content scrollable
              Expanded(
                child: _buildProfileContent(context),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildProfileContent(BuildContext context) {
      final menuItems = <({String label, String icon, VoidCallback? onTap})>[
        (
          label: 'Edit Profile',
          icon: IconConstant.iconEdit,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(showSkip: false),
              ),
            );
            if (mounted) _loadProfile(forceRefresh: true);
          },
        ),
        (
          label: 'My orders',
          icon: IconConstant.iconMyOrders,
          onTap: () => Navigator.pushNamed(context, AppRoutes.myOrdersScreen),
        ),
        (
          label: 'Favourites',
          icon: IconConstant.iconFavourites,
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.favoritesScreen);
          },
        ),
        (
          label: 'Subscriptions',
          icon: IconConstant.iconProfileSubscriptions,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.mySubscriptionsScreen),
        ),
        (
        label: 'My Addresses',
        icon: IconConstant.location,
        onTap: () => Navigator.pushNamed(context, AppRoutes.myAddressesScreen),
        ),
        (
          label: 'Help & Support',
          icon: IconConstant.iconHelpSupport,
          onTap: () => Navigator.pushNamed(context, AppRoutes.helpSupportScreen),
        ),
        (
          label: 'About us',
          icon: IconConstant.iconAboutUs,
          onTap: () => Navigator.pushNamed(context, AppRoutes.aboutUsScreen),
        ),
        (
          label: 'Privacy Policy',
          icon: IconConstant.iconPrivacyPolicy,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.privacyPolicyScreen),
        ),
        (
          label: 'Terms & conditions',
          icon: IconConstant.iconTermsConditions,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.termsConditionsScreen),
        ),
        (
          label: 'Delete Account',
          icon: IconConstant.iconDeleteAccount,
          onTap: () => _showDeleteAccountDialog(context),
        ),
      ];

      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 14.h),
              _buildProfileCard(),
              SizedBox(height: 18.h),
              ...menuItems.map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: _buildMenuTile(
                    label: item.label,
                    icon: item.icon,
                    onTap: item.onTap,
                  ),
                ),
              ),
              SizedBox(height: 70.h),
              _buildLogoutButton(context),
              SizedBox(height: 70.h),

            ],
          ),
        ),
      );
    }

    Widget _buildTopDivider() {
      return Container(
        height: 1,
        color: const Color(0xFFE6C279).withOpacity(0.25),
      );
    }

    Widget _buildProfileCard() {
      final name = _profile?.fullName?.trim().isNotEmpty == true
          ? _profile!.fullName!
          : (_profile?.mobile ?? 'Guest');
      final tier = (_profile?.subscriptionTier ?? 'Standard').toUpperCase();
      final photoUrl = _profile?.profilePhoto;

      return Container(
        width: double.maxFinite,
        padding: EdgeInsets.symmetric(vertical: 18.h),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1220),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE6C279).withOpacity(0.6),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            if (_isLoadingProfile)
              const ProfileCardShimmer()
            else ...[
              Container(
                height: 86.h,
                width: 86.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE6C279), width: 1.2),
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.startsWith('http')
                      ? (() {
                          print('PROFILE PROFILE IMAGE URL = $photoUrl');
                          return Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            width: 86.w,
                            height: 86.h,
                            errorBuilder: (_, __, ___) => Image.asset(
                              ImageConstant.homeScreenImg2,
                              fit: BoxFit.cover,
                            ),
                          );
                        })()
                      : (() {
                          print('PROFILE PROFILE IMAGE URL = null (using asset)');
                          return Image.asset(
                            ImageConstant.homeScreenImg2,
                            fit: BoxFit.cover,
                          );
                        })(),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                name,
                style: CustomTextStyles.montserratBold.copyWith(fontSize: 24),
              ),
              if (_profile?.mobile.isNotEmpty == true) ...[
                SizedBox(height: 4.h),
                Text(
                  '+91 ${_profile!.mobile}',
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 12,
                    color: AppColours.hintcolor,
                  ),
                ),
              ],
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6C279).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE6C279).withOpacity(0.45),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$tier MEMBER',
                  style: TextStyle(
                    color: const Color(0xFFE6C279),
                    fontSize: 10.fSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildMenuTile({
      required String label,
      required String icon,
      required VoidCallback? onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: double.maxFinite,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE6C279), width: 0.9),
            color: const Color(0xFF0E1220),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                icon,
                height: 24.w,
                width: 24.w,
                color: const Color(0xFFE6C279),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  label,
                  style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 14),
                ),
              ),
              Icon(Icons.chevron_right, color: const Color(0xFFE6C279), size: 18),
            ],
          ),
        ),
      );
    }

    Widget _buildLogoutButton(BuildContext context) {
      return Center(
        child: SizedBox(
          width: 280.w,
          height: 56.h,
          child: OutlinedButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: SvgPicture.asset(
              IconConstant.iconLogout,
              height: 16.w,
              width: 16.w,
              color: const Color(0xFFE6C279),
            ),
            label: Text(
              'LOGOUT',
              style: CustomTextStyles.openSansBold.copyWith(color: AppColours.primary,fontSize: 14,letterSpacing: 1.4),
            ),

            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: const Color(0xFFE6C279).withOpacity(0.8),
                width: 1,
              ),
              backgroundColor: const Color(0xFFE6C27A).withOpacity(0.1),            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      );
    }

    void _showLogoutDialog(BuildContext context) {
      _showProfileConfirmDialog(
        context: context,
        icon: IconConstant.iconLogout,
        message: 'Are you sure you want to logout ?',
        onConfirm: () async {
          // Wipe tokens, caches, orders/addresses, image cache + Cart/Favorites.
          await SessionCleanup.clearUserSessionAndBlocs(context);
          if (!context.mounted) return;
          // Clear nav stack so back cannot return to authenticated screens.
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.loginScreen,
            (route) => false,
          );
        },
      );
    }

    void _showDeleteAccountDialog(BuildContext context) {
      _showProfileConfirmDialog(
        context: context,
        icon: IconConstant.iconDeleteAccount,
        message: 'Are you sure you want to delete your account ?',
        onConfirm: () async {
          // Same full local wipe as logout so no previous-user data remains.
          await SessionCleanup.clearUserSessionAndBlocs(context);
          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.loginScreen,
            (route) => false,
          );
        },
      );
    }

    void _showProfileConfirmDialog({
      required BuildContext context,
      required String icon,
      required String message,
      required VoidCallback onConfirm,
    }) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.8),
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: const Color(0xFF16181D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    icon,
                    height: 32.w,
                    width: 32.w,
                    color: AppColours.primary,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    message,
                    style: CustomTextStyles.montserratBold.copyWith(
                      fontSize: 14,
                      color: AppColours.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32.h),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48.h,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3E7D3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide.none,
                            ),
                            child: Text(
                              'Back',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14.fSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: SizedBox(
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              onConfirm();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColours.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Yes, Confirm',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14.fSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
