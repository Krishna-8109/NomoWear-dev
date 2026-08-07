import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/services/session_cleanup.dart';
import 'package:nomowear/core/utils/image_constant.dart';
import 'package:nomowear/features/auth/presentation/bloc/splash_bloc.dart';
import 'package:nomowear/features/auth/presentation/bloc/splash_event.dart';
import 'package:nomowear/features/auth/presentation/bloc/splash_state.dart';

/// Matches native Android splash (`splash_background` in colors.xml).
const Color _splashBackground = Color(0xFF0F1012);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static Widget builder(BuildContext context) {
    return BlocProvider(
      create: (_) => SplashBloc()..add(LoadSplashEvent()),
      child: const SplashScreen(),
    );
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const double _logoAspectRatio = 222.41 / 190;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage(ImageConstant.imgSplashBrand),
        context,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final logoHeight = screenHeight > 0
        ? (screenHeight * 0.26).clamp(160.0, 240.0)
        : 215.0;
    final logoWidth = logoHeight * _logoAspectRatio;

    return BlocListener<SplashBloc, SplashState>(
      listener: (context, state) {
        if (state is SplashLoaded) {
          final goHome = state.destination == SplashDestination.home;
          // Ensure root Blocs do not keep a previous user's cart/wishlist.
          if (!goHome) {
            SessionCleanup.resetAppBlocs(context);
          }
          final route =
              goHome ? AppRoutes.homeScreen : AppRoutes.loginScreen;
          // Remove entire stack so authenticated screens are unreachable.
          Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
        }
      },
      child: Scaffold(
        backgroundColor: _splashBackground,
        body: Center(
          child: Image.asset(
            ImageConstant.imgSplashBrand,
            width: logoWidth,
            height: logoHeight,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
