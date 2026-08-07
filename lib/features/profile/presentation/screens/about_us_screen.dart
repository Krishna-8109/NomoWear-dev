import 'package:flutter/material.dart';
import 'package:nomowear/core/app_export.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({Key? key}) : super(key: key);

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
          "About us",
          style: TextStyle(
            color: AppColours.primary,
            fontSize: 18.fSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child:    Container(
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
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: const Color(0xFF16181D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColours.primary.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "About us",
                  style: CustomTextStyles.montserratBold.copyWith(fontSize: 14),
                ),
                SizedBox(height: 16.h),
                Text(
                  "Welcome to Nomowear, your go-to app for clothing rentals and purchases! We aim to revolutionize the way you shop for fashion by connecting you with a diverse range of stylish outfits, whether you're looking to rent for a special occasion or buy your next wardrobe staple.\n\nAt Nomowear, we understand the challenges of finding the perfect outfit, which is why we've created a user-friendly platform that simplifies the process. Our mission is to provide a seamless experience for fashion enthusiasts, ensuring you have access to trendy clothing options at your fingertips.\n\nExplore our extensive collection featuring everything from casual wear to elegant dresses, all available for rental or purchase. With high-quality images, detailed descriptions, and a secure transaction process, you can shop with confidence knowing you're getting the best.\n\nJoin our growing community of fashion lovers who have embraced Nomowear for their clothing needs. Experience the convenience of renting and buying stylish outfits, and elevate your wardrobe today!",
                  style: CustomTextStyles.montserratMedium.copyWith(fontSize: 14),

                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
