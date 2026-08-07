import 'package:flutter/material.dart';
import 'package:nomowear/core/app_export.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({Key? key}) : super(key: key);

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
          "Terms & conditions",
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
              border: Border.all(color: AppColours.primary, width: 1.5),
            ),
            child: Text(
              "1. Acceptance of Terms\n"
              "By creating an account, renting or purchasing products, or using our platform, you confirm that you have read, understood, and agreed to these Terms and Conditions, along with our Privacy Policy and Cancellation & Return Policy.\n\n"
              "2. Services Offered\n"
              "[Your Company Name] provides a platform for users to rent and purchase clothing, accessories, and fashion essentials. Our offerings may include casual wear, premium wear, occasion wear, and essentials for men, women, and kids. Products are supplied either directly by us or through verified brand and vendor partners.\n\n"
              "3. User Responsibilities\n"
              "• Users must provide accurate, complete, and up-to-date information while placing orders or renting products.\n"
              "• Customers are responsible for the proper use and care of rented items and must return them in the same condition (excluding normal wear and tear).\n"
              "• Any damage, loss, or theft of rented products may result in additional charges.\n"
              "• Misuse of the platform, fraudulent transactions, or policy violations may lead to account suspension or legal action.\n\n"
              "4. Orders, Rentals, and Payments\n"
              "• Product prices, rental fees, security deposits (if applicable), and delivery charges are displayed on the app and may vary based on product, duration, and location.\n"
              "• Payments can be made online via secure payment gateways, wallets, or other available methods.\n"
              "• For rentals, the booking is confirmed only after successful payment and order confirmation.\n"
              "• Security deposits (if applicable) will be refunded after successful return and quality check of the product.\n\n"
              "5. Cancellations, Returns, and Refunds\n"
              "• Order cancellations, returns, and refunds are governed by our Cancellation & Return Policy.\n"
              "• Rental cancellations may be subject to time-based charges.\n"
              "• Refunds (if applicable) will be processed within 5-10 business days to the original payment method.\n"
              "• Items must be returned within the agreed rental period to avoid late fees.\n\n"
              "6. Product Usage and Liability\n"
              "• Users must handle all rented or purchased items responsibly and follow care instructions provided with the product.\n"
              "• [Your Company Name] is not liable for issues arising from incorrect sizing, improper usage, or failure to follow garment care instructions.\n"
              "• We are not responsible for delays caused by factors beyond our control (logistics delays, weather conditions, etc.).\n"
              "• Any complaints regarding product quality, fit, or service must be reported within 24 hours of delivery.",
              style: CustomTextStyles.openSansRegular.copyWith(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
