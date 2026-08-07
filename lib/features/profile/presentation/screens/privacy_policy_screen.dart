import 'package:flutter/material.dart';
import 'package:nomowear/core/app_export.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

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
          "Privacy Policy",
          style: CustomTextStyles.montserratBold.copyWith(fontSize: 16,color: AppColours.primary),

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
                  "Privacy Policy",
                  style: CustomTextStyles.montserratBold.copyWith(fontSize: 14),

                ),
                SizedBox(height: 16.h),
                Text(
                  "At Nomowear, we value your privacy and are committed to protecting your personal information. This Privacy Policy outlines how we collect, use, and safeguard your data when you use our clothing rental and purchase services.\n\nWe collect information that you provide directly to us, such as your name, email address, and payment details, to facilitate your transactions and enhance your shopping experience. We may also gather data on how you interact with our app to improve our services and tailor our offerings to your preferences.\n\nYour information is stored securely and is only accessible to authorized personnel. We do not sell or share your personal data with third parties without your consent, except as required by law or to fulfill your requests.\n\nBy using Nomowear, you agree to the terms outlined in this Privacy Policy. We encourage you to review this policy periodically for any updates. Your trust is important to us, and we are dedicated to ensuring your privacy while you enjoy our fashion services.",
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
