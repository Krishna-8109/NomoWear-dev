import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/features/plans/data/models/plan_category.dart';
import 'package:nomowear/features/plans/data/plan_repository.dart';
import 'package:nomowear/features/subscriptions/data/models/active_subscription.dart';
import 'package:nomowear/features/subscriptions/data/subscription_repository.dart';
import 'package:nomowear/features/subscriptions/presentation/widgets/subscription_plan_card.dart';

class MySubscriptionsScreen extends StatefulWidget {
  const MySubscriptionsScreen({super.key});

  @override
  State<MySubscriptionsScreen> createState() => _MySubscriptionsScreenState();
}

class _MySubscriptionsScreenState extends State<MySubscriptionsScreen> {
  final SubscriptionRepository _repository = SubscriptionRepository();
  final PlanRepository _planRepository = PlanRepository();

  List<ActiveSubscription> _subscriptions = [];
  List<PlanCategory> _categories = [];
  String? _currentSubscriptionId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getMySubscriptions(),
        _planRepository.getPlanCategories().catchError((_) => <PlanCategory>[]),
      ]);

      if (!mounted) return;
      final subscriptions = results[0] as List<ActiveSubscription>;
      final categories = results[1] as List<PlanCategory>;
      final current = ActiveSubscription.pickCurrent(subscriptions);

      setState(() {
        _subscriptions = subscriptions;
        _categories = categories;
        _currentSubscriptionId = current?.id;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _subscriptions = [];
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptions = [];
        _isLoading = false;
        _errorMessage = 'Unable to load subscriptions. Please try again.';
      });
    }
  }

  List<String>? _matchedFeatures(ActiveSubscription subscription) {
    if (_categories.isEmpty) return null;
    final planRef = subscription.planRef.trim().toLowerCase();
    final planName = subscription.planName.trim().toLowerCase();

    for (final category in _categories) {
      for (final plan in category.plans) {
        if (plan.id.toLowerCase() == planRef ||
            plan.planRef.toLowerCase() == planRef ||
            plan.planCode.toLowerCase() == planRef ||
            (planRef.isEmpty && plan.name.toLowerCase() == planName) ||
            plan.name.toLowerCase() == planName) {
          if (plan.features.isNotEmpty) return plan.features;
          if (category.features.isNotEmpty) return category.features;
        }
      }
      if (category.name.toLowerCase().contains(planName) ||
          planName.contains(category.name.toLowerCase())) {
        if (category.features.isNotEmpty) return category.features;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1012),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: AppColours.primary),
                  ),
                  Expanded(
                    child: Text(
                      'Subscriptions',
                      textAlign: TextAlign.center,
                      style: CustomTextStyles.openSansSemiBold.copyWith(
                        fontSize: 18,
                        color: AppColours.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
            Container(
              height: 2,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE6C27A).withOpacity(0.15),
                    const Color(0xFFE6C27A),
                    const Color(0xFFE6C27A).withOpacity(0.15),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.all(20.w),
        child: const MembershipCardShimmer(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: CustomTextStyles.openSansRegular.copyWith(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: _loadSubscriptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColours.primary,
                ),
                child: Text(
                  'Retry',
                  style: CustomTextStyles.openSansSemiBold.copyWith(
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_subscriptions.isEmpty) {
      return Center(
        child: Text(
          'No subscriptions found.',
          style: CustomTextStyles.openSansRegular.copyWith(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColours.primary,
      backgroundColor: const Color(0xFF16181D),
      onRefresh: _loadSubscriptions,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 24.h),
        itemCount: _subscriptions.length,
        separatorBuilder: (_, __) => SizedBox(height: 16.h),
        itemBuilder: (context, index) {
          final subscription = _subscriptions[index];
          final isCurrent = subscription.id == _currentSubscriptionId;
          return SubscriptionPlanCard(
            subscription: subscription,
            showCurrentPlanBadge: isCurrent,
            matchedFeatures: _matchedFeatures(subscription),
            statusLabel: isCurrent
                ? null
                : (subscription.isActive ? 'UPGRADED' : subscription.planStatus),
          );
        },
      ),
    );
  }
}
