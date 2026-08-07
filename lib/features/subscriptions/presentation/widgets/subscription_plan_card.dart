import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/features/subscriptions/data/models/active_subscription.dart';

class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({
    super.key,
    required this.subscription,
    this.showCurrentPlanBadge = false,
    this.statusLabel,
  });

  final ActiveSubscription subscription;
  final bool showCurrentPlanBadge;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColours.primary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  subscription.displayTitle,
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 16,
                    color: AppColours.primary,
                    letterSpacing: 0.6,
                    height: 1.3,
                  ),
                ),
              ),
              if (!showCurrentPlanBadge &&
                  (statusLabel ?? subscription.planStatus).isNotEmpty)
                _statusChip(statusLabel ?? subscription.planStatus),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            subscription.formattedPrice,
            style: CustomTextStyles.openSansSemiBold.copyWith(
              fontSize: 20,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          if (subscription.expiryLabel.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              subscription.expiryLabel,
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 12,
                color: Colors.white54,
                height: 1.3,
              ),
            ),
          ],
          SizedBox(height: 18.h),
          Divider(
            color: AppColours.primary.withOpacity(0.35),
            thickness: 0.5,
            height: 0.5,
          ),
          SizedBox(height: 18.h),
          ...subscription.features.map(_featureRow),
          if (showCurrentPlanBadge) ...[
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  disabledForegroundColor: AppColours.primary,
                  side: BorderSide(color: AppColours.primary, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'CURRENT PLAN',
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 14,
                    color: AppColours.primary,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toUpperCase();
    final isActive = normalized == 'ACTIVE';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isActive
            ? AppColours.primary.withOpacity(0.15)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive
              ? AppColours.primary.withOpacity(0.5)
              : Colors.white24,
        ),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: isActive ? AppColours.primary : Colors.white54,
          fontSize: 9.fSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _featureRow(String feature) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: Icon(
              Icons.check,
              color: AppColours.primary,
              size: 16,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              feature,
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 14,
                color: AppColours.secondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
