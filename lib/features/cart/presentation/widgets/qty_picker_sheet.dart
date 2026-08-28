import 'package:nomowear/core/app_export.dart';

/// Scrollable qty list with a fixed height and a DONE button below.
Future<int?> showQtyPickerSheet(
  BuildContext context, {
  required int currentQty,
  required List<int> options,
}) {
  var selected = currentQty;
  if (options.isNotEmpty && !options.contains(selected)) {
    selected = options.first;
  }

  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: const Color(0xFF050816),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'SELECT QUANTITY',
                    style: CustomTextStyles.montserratBold.copyWith(
                      fontSize: 14,
                      color: AppColours.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    height: 220.h,
                    decoration: BoxDecoration(
                      color: AppColours.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.black.withOpacity(0.08),
                      ),
                      itemBuilder: (context, index) {
                        final qty = options[index];
                        final isActive = qty == selected;
                        return InkWell(
                          onTap: () => setModalState(() => selected = qty),
                          child: Container(
                            height: 44.h,
                            alignment: Alignment.center,
                            color: isActive
                                ? AppColours.primary.withOpacity(0.35)
                                : Colors.transparent,
                            child: Text(
                              'Qty: $qty',
                              style: CustomTextStyles.montserratSemiBold.copyWith(
                                color: Colors.black,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 14.h),
                  SizedBox(
                    width: double.maxFinite,
                    height: 46.h,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFE6C27A),
                              Color(0xFFD9B35F),
                            ],
                          ),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            'DONE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14.fSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
