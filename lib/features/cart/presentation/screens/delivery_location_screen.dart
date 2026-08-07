import 'package:nomowear/core/app_export.dart';

class DeliveryLocationScreen extends StatefulWidget {
  const DeliveryLocationScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryLocationScreen> createState() => _DeliveryLocationScreenState();
}

class _DeliveryLocationScreenState extends State<DeliveryLocationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _flatController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _showManualForm = false;
  String? _selectedAddress;

  final List<Map<String, dynamic>> _recentAddresses = [
    {
      'label': 'Home',
      'icon': Icons.home_outlined,
      'address': '42, Rose Garden Apartments, MG Road',
      'city': 'Bengaluru, Karnataka - 560001',
    },
    {
      'label': 'Office',
      'icon': Icons.work_outline,
      'address': 'Level 3, Prestige Tech Park, Whitefield',
      'city': 'Bengaluru, Karnataka - 560066',
    },
    {
      'label': 'Other',
      'icon': Icons.location_on_outlined,
      'address': '8B, Palm Grove, Jubilee Hills',
      'city': 'Hyderabad, Telangana - 500033',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _flatController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _selectAddress(String fullAddress) {
    setState(() {
      _selectedAddress = fullAddress;
    });
    Navigator.pop(context, fullAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1012),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20.h),
                      _buildSearchBar(),
                      SizedBox(height: 24.h),
                      _buildUseCurrentLocation(),
                      SizedBox(height: 24.h),
                      _buildEnterManuallyButton(),
                      if (_showManualForm) ...[
                        SizedBox(height: 20.h),
                        _buildManualForm(),
                      ],
                      SizedBox(height: 24.h),
                      if (!_showManualForm) ...[
                        _buildSectionLabel('RECENT ADDRESSES'),
                        SizedBox(height: 12.h),
                        ..._recentAddresses.map((addr) => _buildAddressCard(addr)),
                      ],
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
              if (_showManualForm) _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColours.primary.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 40.h,
              width: 40.w,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D21),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColours.primary,
                size: 16,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Text(
            'Delivery Location',
            style: TextStyle(
              color: AppColours.primary,
              fontSize: 18.fSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColours.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColours.primary.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: AppColours.primary, size: 22),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white, fontSize: 14.fSize),
              decoration: InputDecoration(
                hintText: 'Search for area, street, city...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13.fSize),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {});
              },
              child: Icon(Icons.close, color: Colors.white38, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildUseCurrentLocation() {
    return GestureDetector(
      onTap: () {
        // Simulate fetching location
        _selectAddress('Current Location, Bengaluru, Karnataka - 560001');
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColours.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColours.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              height: 44.h,
              width: 44.w,
              decoration: BoxDecoration(
                color: AppColours.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.my_location_rounded,
                color: AppColours.primary,
                size: 22,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use Current Location',
                    style: TextStyle(
                      color: AppColours.primary,
                      fontSize: 14.fSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Enable GPS to auto-detect your location',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11.fSize,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColours.primary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterManuallyButton() {
    return GestureDetector(
      onTap: () => setState(() => _showManualForm = !_showManualForm),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF16181D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              height: 44.h,
              width: 44.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_location_alt_outlined, color: Colors.white70, size: 22),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter Address Manually',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.fSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Type your flat, street, city & pincode',
                    style: TextStyle(color: Colors.white38, fontSize: 11.fSize),
                  ),
                ],
              ),
            ),
            Icon(
              _showManualForm ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white38,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualForm() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColours.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField(
            controller: _flatController,
            label: 'FLAT / HOUSE NO.',
            hint: 'e.g., 42B, 3rd Floor',
            icon: Icons.home_outlined,
          ),
          SizedBox(height: 16.h),
          _buildFormField(
            controller: _areaController,
            label: 'AREA / STREET',
            hint: 'e.g., MG Road, Koramangala',
            icon: Icons.map_outlined,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  controller: _cityController,
                  label: 'CITY',
                  hint: 'e.g., Bengaluru',
                  icon: Icons.location_city_outlined,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildFormField(
                  controller: _pincodeController,
                  label: 'PINCODE',
                  hint: 'e.g., 560001',
                  icon: Icons.pin_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildAddressTypeRow(),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColours.primary,
            fontSize: 9.fSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: Colors.white, fontSize: 13.fSize),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white24, fontSize: 12.fSize),
            prefixIcon: Icon(icon, color: AppColours.primary.withOpacity(0.6), size: 18),
            filled: true,
            fillColor: const Color(0xFF1A1D21),
            contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColours.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  String _selectedType = 'Home';
  final List<Map<String, dynamic>> _addressTypes = [
    {'label': 'Home', 'icon': Icons.home_outlined},
    {'label': 'Work', 'icon': Icons.work_outline},
    {'label': 'Other', 'icon': Icons.add_location_alt_outlined},
  ];

  Widget _buildAddressTypeRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADDRESS TYPE',
          style: TextStyle(
            color: AppColours.primary,
            fontSize: 9.fSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: _addressTypes.map((type) {
            final isActive = _selectedType == type['label'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedType = type['label']),
                child: Container(
                  margin: EdgeInsets.only(right: type['label'] != 'Other' ? 8.w : 0),
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isActive ? AppColours.primary.withOpacity(0.12) : const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive ? AppColours.primary : Colors.white12,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        color: isActive ? AppColours.primary : Colors.white54,
                        size: 16,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        type['label'] as String,
                        style: TextStyle(
                          color: isActive ? AppColours.primary : Colors.white54,
                          fontSize: 11.fSize,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppColours.primary,
        fontSize: 10.fSize,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> addr) {
    return GestureDetector(
      onTap: () => _selectAddress('${addr['address']}, ${addr['city']}'),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF16181D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 42.h,
              width: 42.w,
              decoration: BoxDecoration(
                color: AppColours.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColours.primary.withOpacity(0.2)),
              ),
              child: Icon(
                addr['icon'] as IconData,
                color: AppColours.primary,
                size: 20,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    addr['label'] as String,
                    style: TextStyle(
                      color: AppColours.primary,
                      fontSize: 12.fSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    addr['address'] as String,
                    style: TextStyle(color: Colors.white, fontSize: 13.fSize, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    addr['city'] as String,
                    style: TextStyle(color: Colors.white54, fontSize: 11.fSize),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Container(
        width: double.maxFinite,
        height: 54.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [AppColours.primary.withOpacity(0.85), AppColours.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColours.primary.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            final flat = _flatController.text.trim();
            final area = _areaController.text.trim();
            final city = _cityController.text.trim();
            final pin = _pincodeController.text.trim();

            if (flat.isEmpty || area.isEmpty || city.isEmpty || pin.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Please fill in all address fields.',
                    style: TextStyle(color: Colors.black),
                  ),
                  backgroundColor: AppColours.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              return;
            }

            _selectAddress('$flat, $area, $city - $pin');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            'SAVE ADDRESS',
            style: TextStyle(
              color: Colors.black,
              fontSize: 15.fSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
