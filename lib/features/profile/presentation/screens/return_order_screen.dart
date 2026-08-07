import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/features/orders/data/order_repository.dart';
import 'package:nomowear/features/orders/data/pending_return_store.dart';
import 'package:nomowear/features/profile/domain/saved_address.dart';
import 'package:nomowear/features/profile/domain/user_order.dart';

class ReturnOrderScreen extends StatefulWidget {
  const ReturnOrderScreen({
    super.key,
    required this.orderId,
    this.orderNumber,
  });

  final String orderId;
  final String? orderNumber;

  @override
  State<ReturnOrderScreen> createState() => _ReturnOrderScreenState();
}

class _ReturnOrderScreenState extends State<ReturnOrderScreen> {
  static const _pickupSlots = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
  ];

  final OrderRepository _orderRepository = OrderRepository();
  final TextEditingController _noteController = TextEditingController();

  List<SavedAddress> _addresses = [];
  bool _loadingAddresses = true;
  bool _submitting = false;
  String? _addressesError;
  String? _selectedAddressId;
  DateTime? _pickupDate;
  String? _pickupTime;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _loadingAddresses = true;
      _addressesError = null;
    });

    try {
      await loadSavedAddressesFromProfile(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _addresses = List<SavedAddress>.from(userSavedAddresses);
        _loadingAddresses = false;
        if (_addresses.isNotEmpty) {
          _selectedAddressId = _addresses.first.id;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _addresses = List<SavedAddress>.from(userSavedAddresses);
        _loadingAddresses = false;
        _addressesError = e.message;
        if (_addresses.isNotEmpty) {
          _selectedAddressId = _addresses.first.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addresses = List<SavedAddress>.from(userSavedAddresses);
        _loadingAddresses = false;
        _addressesError = 'Unable to load addresses.';
        if (_addresses.isNotEmpty) {
          _selectedAddressId = _addresses.first.id;
        }
      });
    }
  }

  String get _apiPickupDate {
    final date = _pickupDate;
    if (date == null) return '';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String get _pickupDateLabel {
    final date = _pickupDate;
    if (date == null) return 'Select pickup date';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _pickupDate ?? now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColours.primary,
              onPrimary: Colors.black,
              surface: Color(0xFF16181D),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _pickupDate = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final addressId = _selectedAddressId?.trim() ?? '';
    if (addressId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup address.')),
      );
      return;
    }
    if (_pickupDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup date.')),
      );
      return;
    }
    if (_pickupTime == null || _pickupTime!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup time.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await _orderRepository.requestReturn(
        orderId: widget.orderId,
        addressId: addressId,
        pickupDate: _apiPickupDate,
        pickupTime: _pickupTime!,
        note: _noteController.text,
      );

      await PendingReturnStore.instance.mark(widget.orderId);
      markUserOrderReturnSubmitted(widget.orderId);

      if (!mounted) return;
      setState(() => _submitting = false);

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF16181D),
          title: Text(
            result.waitlisted ? 'Return Waitlisted' : 'Return Requested',
            style: TextStyle(
              color: AppColours.primary,
              fontSize: 16.fSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            result.message,
            style: TextStyle(color: Colors.white70, fontSize: 14.fSize),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'OK',
                style: TextStyle(color: AppColours.primary),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit return request. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderLabel = widget.orderNumber?.trim().isNotEmpty == true
        ? widget.orderNumber!
        : widget.orderId;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1012),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColours.primary),
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Return Order',
          style: TextStyle(
            color: AppColours.primary,
            fontSize: 18.fSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
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
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDER: $orderLabel',
                      style: CustomTextStyles.openSansSemiBold.copyWith(
                        fontSize: 12,
                        color: AppColours.primary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'PICKUP ADDRESS',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 12,
                        color: AppColours.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _buildAddressSection(),
                    SizedBox(height: 24.h),
                    Text(
                      'PICKUP DATE',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 12,
                        color: AppColours.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _selectorTile(
                      icon: Icons.calendar_today_outlined,
                      label: _pickupDateLabel,
                      onTap: _submitting ? null : _pickDate,
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'PICKUP TIME',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 12,
                        color: AppColours.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: _pickupSlots.map((slot) {
                        final selected = _pickupTime == slot;
                        return ChoiceChip(
                          label: Text(slot),
                          selected: selected,
                          onSelected: _submitting
                              ? null
                              : (_) => setState(() => _pickupTime = slot),
                          selectedColor: AppColours.primary,
                          backgroundColor: const Color(0xFF16181D),
                          labelStyle: TextStyle(
                            color: selected ? Colors.black : Colors.white70,
                            fontSize: 12.fSize,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColours.primary
                                : AppColours.primary.withOpacity(0.35),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'NOTE (OPTIONAL)',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 12,
                        color: AppColours.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _noteController,
                      enabled: !_submitting,
                      maxLines: 4,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.fSize,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a note for pickup',
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 13.fSize,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF16181D),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColours.primary.withOpacity(0.35),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColours.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
              child: SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColours.primary,
                    disabledBackgroundColor:
                        AppColours.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        )
                      : Text(
                          'SUBMIT RETURN REQUEST',
                          style: CustomTextStyles.montserratBold.copyWith(
                            fontSize: 14,
                            color: Colors.black,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    if (_loadingAddresses) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          child: CircularProgressIndicator(color: AppColours.primary),
        ),
      );
    }

    if (_addresses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF16181D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColours.primary.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Text(
              _addressesError ?? 'No saved addresses found.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13.fSize),
            ),
            SizedBox(height: 12.h),
            TextButton(
              onPressed: () async {
                await Navigator.pushNamed(
                  context,
                  AppRoutes.addNewAddressScreen,
                );
                await _loadAddresses();
              },
              child: Text(
                'Add Address',
                style: TextStyle(color: AppColours.primary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _addresses.map((address) {
        final selected = address.id == _selectedAddressId;
        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: InkWell(
            onTap: _submitting
                ? null
                : () => setState(() => _selectedAddressId = address.id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFF16181D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColours.primary
                      : AppColours.primary.withOpacity(0.3),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: AppColours.primary,
                    size: 20,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.title,
                          style: CustomTextStyles.openSansSemiBold.copyWith(
                            fontSize: 14,
                            color: AppColours.primary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          address.addressLines,
                          style: CustomTextStyles.openSansRegular.copyWith(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _selectorTile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFF16181D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColours.primary.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColours.primary, size: 18),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label,
                style: CustomTextStyles.openSansSemiBold.copyWith(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColours.primary),
          ],
        ),
      ),
    );
  }
}
