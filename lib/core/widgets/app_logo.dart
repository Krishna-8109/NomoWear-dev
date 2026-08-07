import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nomowear/core/utils/image_constant.dart';
import 'package:nomowear/core/utils/size_utils.dart';
import 'package:nomowear/theme/theme_helper.dart';

/// NOMOWEAR brand logo (suitcase mark + wordmark + tagline).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.showTagline = true,
  });

  final double? width;
  final double? height;
  final bool showTagline;

  static const double _aspectRatio = 222.41 / 209.59;

  @override
  Widget build(BuildContext context) {
    final logoHeight = height ?? 200.h;
    final logoWidth = width ?? logoHeight * _aspectRatio;
    final markHeight = logoHeight * 0.74;
    final titleSize = logoHeight * 0.15;
    final taglineSize = logoHeight * 0.076;

    return SizedBox(
      width: logoWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: markHeight,
            width: logoWidth,
            child: SvgPicture.asset(
              ImageConstant.imgLogoMark,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: logoHeight * 0.02),
          Text(
            'NOMOWEAR',
            style: GoogleFonts.poppins(
              fontSize: titleSize,
              fontWeight: FontWeight.w500,
              color: AppColours.primary,
              letterSpacing: 0.5,
            ),
          ),
          if (showTagline) ...[
            SizedBox(height: logoHeight * 0.01),
            Text(
              'Travel light, Live easy',
              style: GoogleFonts.poppins(
                fontSize: taglineSize,
                fontWeight: FontWeight.w300,
                color: AppColours.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
