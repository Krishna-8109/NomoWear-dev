import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/features/profile/data/profile_completion_helper.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';
import 'package:nomowear/features/profile/presentation/screens/edit_profile_screen.dart';

class ProfileOrderGuard {
  ProfileOrderGuard._();

  static Future<bool> ensureCompleteProfile(BuildContext context) async {
    try {
      final profile = await ProfileRepository().getProfile();
      if (ProfileCompletionHelper.isProfileComplete(profile)) {
        return true;
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to verify profile. Please try again.'),
          ),
        );
      }
      return false;
    }

    if (!context.mounted) return false;

    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D21),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColours.primary.withValues(alpha: 0.4)),
        ),
        title: Text(
          'Complete your profile',
          style: CustomTextStyles.montserratBold.copyWith(
            color: AppColours.primary,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Please complete your profile details before placing an order.',
          style: CustomTextStyles.openSansRegular.copyWith(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white54, fontSize: 14.fSize),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Complete Profile',
              style: TextStyle(
                color: AppColours.primary,
                fontSize: 14.fSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldComplete != true || !context.mounted) return false;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(
          showSkip: false,
          popOnSave: true,
        ),
      ),
    );

    if (saved == true) return true;

    if (!context.mounted) return false;

    try {
      final updated = await ProfileRepository().getProfile(forceRefresh: true);
      return ProfileCompletionHelper.isProfileComplete(updated);
    } catch (_) {
      return false;
    }
  }
}
