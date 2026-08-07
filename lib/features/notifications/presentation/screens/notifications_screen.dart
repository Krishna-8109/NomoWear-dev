import 'package:nomowear/core/app_export.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notifications = <({String title, String subtitle, String time})>[
      (
        title: 'Order Shipped',
        subtitle: 'Your has been dispatched today',
        time: '2 hr ago',
      ),
      (
        title: 'Membership Expiring',
        subtitle: 'Your membership is expiring soon, explore all plans',
        time: '1 day ago',
      ),
      (
        title: 'Order Delivered',
        subtitle: 'Your has been delivered',
        time: '5 days ago',
      ),
      (
        title: 'Order Arriving',
        subtitle: 'Delivery partner is on the way',
        time: '13/03/2026',
      ),
      (
        title: 'Prime Membership',
        subtitle: 'Your membership purchase is successful, Explore benfits',
        time: '29/04/2026',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFE6C279).withOpacity(0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: const Color(0xFFE6C279),
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: TextAlign.center,
                      style: CustomTextStyles.openSansBold.copyWith(fontSize: 16,color: AppColours.primary),
                    ),
                  ),
                  SizedBox(width: 20.w),
                ],
              ),
            ),
            Container(
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
            SizedBox(height: 28,),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 20.h),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => SizedBox(height: 16.h),
                itemBuilder: (_, index) {
                  final item = notifications[index];

                  return Column(
                    children: [

                      /// CONTENT
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: CustomTextStyles.openSansSemiBold.copyWith(
                                    fontSize: 16,
                                  ),
                                ),

                                SizedBox(height: 10.h),

                                Text(
                                  item.subtitle,
                                  style: CustomTextStyles.openSansRegular.copyWith(
                                    fontSize: 12,
                                    height: 22.75 / 12,
                                    letterSpacing: 0,
                                    color: const Color(0xFFD0C5B4),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 10.w),

                          Text(
                            item.time,
                            style: CustomTextStyles.openSansRegular.copyWith(
                              fontSize: 12,
                              color: AppColours.hintcolor,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 14.h),

                      /// BOTTOM LINE
                      Divider(
                        color: const Color(0xFFE6C279).withOpacity(0.4),
                        thickness: 0.8,
                        height: 1,
                      ),
                    ],
                  );
                },
              ),
            ),

          ],
        ),
      ),
    );
  }
}
