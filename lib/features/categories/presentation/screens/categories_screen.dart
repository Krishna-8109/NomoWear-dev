import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nomowear/core/app_export.dart';

class CategoriesScreen extends StatelessWidget {
  final bool isTab;
  const CategoriesScreen({Key? key, this.isTab = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1012),

      // ✅ AppBar ALWAYS visible
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1012),
        elevation: 0,
        centerTitle: true,

        // 🔥 Back button only if NOT tab
        leading: isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),

        title: Text(
          "Categories",
          style: CustomTextStyles.openSansSemiBold.copyWith(color: AppColours.primary,fontSize: 16),
        ),

        // 🔥 Custom Gradient Divider
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
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
        ),
      ),

      body: SafeArea(child: _buildMainContent(context)),
    );
  }

  // ================= MAIN CONTENT =================
  Widget _buildMainContent(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 28.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection("Men", [
                  _item("T-Shirts", IconConstant.iconTShirts),
                  _item("Shirts", IconConstant.iconShirts),
                  _item("Kurtas", IconConstant.iconKurtas),
                  _item("Jeans", IconConstant.iconJeans),
                  _item("Trousers", IconConstant.iconTrousers),
                ]),

                _buildSection("Women", [
                  _item("T-Shirts", IconConstant.iconWTShirts),
                  _item("Shirts", IconConstant.iconWShirts),
                  _item("Sarees", IconConstant.iconSarees),
                  _item("Kurtis", IconConstant.iconWKurtis),
                  _item("Jeans", IconConstant.iconWJeans),
                ]),

                _buildSection("Kids", [
                  _item("Girls", IconConstant.iconKGirls),
                  _item("Boys", IconConstant.iconKBoys),
                ]),

                _buildSection("Essentials", [
                  _item("Socks", IconConstant.iconSocks),
                  _item("Innerwear", IconConstant.iconInnerwear),
                  _item("Accessories", IconConstant.iconAccessories),
                  _item("Kerchiefs", IconConstant.iconKerchiefs),
                  _item("Boxers", IconConstant.iconBoxers),
                ]),
              ],
            ),
          ),
        ),

        // ✅ Bottom nav only when NOT tab
        if (!isTab) _buildBottomNav(context),
      ],
    );
  }

  // ================= SECTION =================
  Widget _buildSection(String title, List<Widget> items) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 🔥 Title + Gradient Line (Same Row)
          Row(
            children: [
              Text(
                title,
                style: CustomTextStyles.openSansBold.copyWith(fontSize: 16,color: AppColours.primary),
              ),

              SizedBox(width: 10.w),

              // 🔥 Expanded Gradient Line
              Expanded(
                child: Container(
                  height: 2,
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
              ),
            ],
          ),

          SizedBox(height: 18.h),

          // 🔥 Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
            children: items,
          ),
        ],
      ),
    );
  }
  // ================= ITEM =================
  Widget _item(String title, String iconPath) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColours.primary, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            iconPath,
            height: 28,
            width: 28,
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: CustomTextStyles.openSansBold.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ================= BOTTOM NAV =================
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 80.h,
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            Icons.home_filled,
            "Home",
            false,
            AppRoutes.homeScreen,
          ),
          _buildNavItem(
            context,
            Icons.grid_view,
            "Categories",
            true,
            AppRoutes.categoriesScreen,
          ),
          _buildNavItem(
            context,
            Icons.shopping_cart_outlined,
            "Cart",
            false,
            "",
          ),
          _buildNavItem(
            context,
            Icons.stars_outlined,
            "Subscription",
            false,
            "",
          ),
          _buildNavItem(context, Icons.person_outline, "Profile", false, ""),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive,
    String route,
  ) {
    return GestureDetector(
      onTap: () {
        if (!isActive && route.isNotEmpty) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? AppColours.primary : Colors.grey,
            size: 24,
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColours.primary : Colors.grey,
              fontSize: 10.fSize,
            ),
          ),
        ],
      ),
    );
  }
}
