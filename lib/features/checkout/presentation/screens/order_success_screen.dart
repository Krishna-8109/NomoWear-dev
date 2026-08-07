import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nomowear/core/app_export.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final String orderIdDisplay;

  const OrderSuccessScreen({
    Key? key,
    this.orderId = "#NMW-829410",
    String? orderIdDisplay,
  })  : orderIdDisplay = orderIdDisplay ?? orderId,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10), // darker premium background
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 180.h),

              /// 🔥 Success Icon with Glow
              SvgPicture.asset(
                IconConstant.success, // if you have constant

              ),

              /// 🔥 SUCCESS TEXT
              Text(
                "SUCCESS!",
                style: CustomTextStyles.montserratBold.copyWith(fontSize: 20,letterSpacing: 1.5),
              ),

              SizedBox(height: 12.h),

              /// Subtitle
              Text(
                "Your order has been placed successfully!",
                textAlign: TextAlign.center,
                style: CustomTextStyles.openSansRegular.copyWith(fontSize: 14),
              ),
              SizedBox(height: 12.h),


              /// 🔥 Order ID Card (Glass effect)
              Container(
                width: double.maxFinite,
                padding: EdgeInsets.symmetric(vertical: 22.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D21).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "ORDER ID",
                      style: CustomTextStyles.openSansRegular.copyWith(fontSize: 12,letterSpacing: 1.2),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      orderIdDisplay,
                      style: CustomTextStyles.openSansBold.copyWith(fontSize: 20,color: AppColours.primary,letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),


                 SizedBox(height: 40,),
              /// 🔥 TRACK ORDER (Gradient Button)
              Container(
                width: double.maxFinite,
                height: 54.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColours.primary.withOpacity(0.9),
                      AppColours.primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.orderTrackingScreen,
                      arguments: orderId,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "TRACK ORDER",
                    style: CustomTextStyles.montserratBold.copyWith(fontSize: 14,color: Colors.black),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              /// 🔥 BACK BUTTON (Outlined Gold)
              SizedBox(
                width: double.maxFinite,
                height: 54.h,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.homeScreen,
                          (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColours.primary.withOpacity(0.3),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "BACK TO HOMESCREEN",
                    style: CustomTextStyles.montserratBold.copyWith(fontSize: 14,letterSpacing: 1),
                  ),
                ),
              ),

              SizedBox(height: 48.h),
            ],
          ),
        ),
      ),
    );
  }
}