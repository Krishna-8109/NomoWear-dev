import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/cart/presentation/widgets/wardrobe_limit_dialog.dart';
import 'package:nomowear/features/favorites/presentation/bloc/favorites_bloc.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final favoritesState = context.read<FavoritesBloc>().state;
      if (favoritesState.items.isEmpty) {
        context.read<FavoritesBloc>().add(LoadWishlistEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1012),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColours.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Favorites",
          style: TextStyle(
            color: AppColours.primary,
            fontSize: 18.fSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          BlocBuilder<CartBloc, CartState>(
            builder: (context, cartState) {
              final count = cartState.totalItems;
              return GestureDetector(

                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.homeScreen, (route) => false, arguments: 2);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.shopping_cart_outlined, color: AppColours.primary),
                      if (count > 0)
                        Positioned(
                          top: 8,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColours.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10.fSize,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child:             Container(
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

        ),
      ),
      body: SafeArea(
        child: BlocConsumer<FavoritesBloc, FavoritesState>(
          listenWhen: (previous, current) =>
              current.errorMessage != null &&
              current.errorMessage != previous.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage;
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  message,
                  style: CustomTextStyles.openSansSemiBold.copyWith(
                    color: Colors.black,
                    fontSize: 10,
                  ),
                ),
                backgroundColor: AppColours.primary,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          builder: (context, state) {
            if (state.isLoading && state.items.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColours.primary),
              );
            }

            return RefreshIndicator(
              color: AppColours.primary,
              backgroundColor: const Color(0xFF0F1012),
              onRefresh: () async {
                context.read<FavoritesBloc>().add(
                      LoadWishlistEvent(forceRefresh: true),
                    );
                await context.read<FavoritesBloc>().stream.firstWhere(
                      (next) => !next.isLoading,
                    );
              },
              child: state.items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_border,
                              color: AppColours.primary.withOpacity(0.4),
                              size: 60,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              "No favorites yet",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16.fSize,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 90.w,
                        height: 100.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColours.primary.withOpacity(0.5)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ProductImage(
                          imageUrl: item.imageUrl,
                          width: 90.w,
                          height: 100.h,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                color: AppColours.primary,
                                fontSize: 14.fSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.fSize,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                SizedBox(
                                  height: 32.h,
                                  width: 129.w,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      final cartItem = CartItem(
                                        id: item.id,
                                        productId: item.id,
                                        title: item.title,
                                        imageUrl: item.imageUrl,
                                        price: item.subtitle,
                                        isEssential: false,
                                      );
                                      // Uses shared cart guards (UUID, wardrobe limit,
                                      // non-sub single-category restriction).
                                      final added = tryAddToCart(context, cartItem);
                                      if (!added) return;

                                      context
                                          .read<FavoritesBloc>()
                                          .add(RemoveFavoriteEvent(item.id));

                                      ScaffoldMessenger.of(context)
                                          .clearSnackBars();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${item.title} moved to cart',
                                            style: CustomTextStyles
                                                .openSansSemiBold
                                                .copyWith(
                                              color: Colors.black,
                                              fontSize: 10,
                                            ),
                                          ),
                                          backgroundColor: AppColours.primary,
                                          duration: const Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColours.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      "Move to cart",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10.fSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Spacer(),
                                IconButton(
                                  onPressed: () {
                                    context.read<FavoritesBloc>().add(RemoveFavoriteEvent(item.id));
                                  },
                                  icon: SvgPicture.asset(
                                    IconConstant.delete2,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            );
          },
        ),
      ),
    );
  }
}
