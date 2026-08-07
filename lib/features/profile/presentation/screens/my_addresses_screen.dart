import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/utils/icon_constant.dart';
import 'package:nomowear/core/utils/size_utils.dart';
import 'package:nomowear/features/profile/domain/saved_address.dart';
import 'package:nomowear/routes/app_routes.dart';
import 'package:nomowear/theme/theme_helper.dart';

class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({super.key});

  @override
  State<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    if (userSavedAddresses.isNotEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await loadSavedAddressesFromProfile();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load addresses.';
      });
    }
  }

  Future<void> _reloadAddressesFromApi() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await loadSavedAddressesFromProfile(forceRefresh: true);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load addresses.';
      });
    }
  }

  void _refresh() => setState(() {});

  Future<void> _openAdd() async {
    final location = await Navigator.pushNamed(
      context,
      AppRoutes.selectAddressScreen,
    );
    if (!mounted || location == null) return;

    final result = await Navigator.pushNamed(
      context,
      AppRoutes.addNewAddressScreen,
      arguments: location is Map ? location : null,
    );
    if (!mounted) return;
    if (result is Map) {
      setState(() => _saving = true);
      try {
        final payload = result.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
        await createAndAppendSavedAddress(payload);
        if (!mounted) return;
        setState(() => _saving = false);
        _refresh();
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message,
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColours.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to save address. Please try again.',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColours.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openEdit(SavedAddress a) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.addNewAddressScreen,
      arguments: a,
    );
    if (!mounted) return;
    if (result is Map) {
      setState(() => _saving = true);
      try {
        final payload = result.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
        await updateSavedAddressById(a.id, payload);
        if (!mounted) return;
        setState(() => _saving = false);
        _refresh();
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message,
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColours.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to update address. Please try again.',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColours.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(SavedAddress a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16181D),
        title: Text(
          'Remove address?',
          style: TextStyle(
            color: AppColours.primary,
            fontSize: 16.fSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '“${a.title}” will be removed from saved addresses.',
          style: TextStyle(color: Colors.white70, fontSize: 14.fSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColours.primary)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _saving = true);
      try {
        await deleteSavedAddressById(a.id);
        if (!mounted) return;
        setState(() => _saving = false);
        _refresh();
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message,
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColours.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to delete address. Please try again.',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColours.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = List<SavedAddress>.from(userSavedAddresses);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: AppColours.primary),
                  ),
                  Expanded(
                    child: Text(
                      'My Addresses',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColours.primary,
                        fontSize: 18.fSize,
                        fontWeight: FontWeight.bold,
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

            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 12.h),
              child: Row(
                children: [
                  Text(
                    'Saved Addresses',
                    style: TextStyle(
                      color: AppColours.primary,
                      fontSize: 15.fSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openAdd,
                    child: Text(
                      '+ Add New Address',
                      style: TextStyle(
                        color: AppColours.primary,
                        fontSize: 14.fSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading || _saving
                  ? Center(
                      child: CircularProgressIndicator(color: AppColours.primary),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14.fSize,
                                ),
                              ),
                              TextButton(
                                onPressed: _reloadAddressesFromApi,
                                child: Text(
                                  'Retry',
                                  style: TextStyle(color: AppColours.primary),
                                ),
                              ),
                            ],
                          ),
                        )
                      : list.isEmpty
                  ? Center(
                      child: Text(
                        'No saved addresses yet.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14.fSize,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 24.h),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final a = list[i];
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.title,
                                      style: TextStyle(
                                        color: AppColours.primary,
                                        fontSize: 16.fSize,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),

                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _openEdit(a),
                                        child: Padding(
                                          padding: EdgeInsets.only(right: 6.w),
                                          child: SvgPicture.asset(
                                            IconConstant.iconEdit,
                                            width: 18.w,
                                            height: 18.w,
                                            colorFilter: const ColorFilter.mode(
                                              AppColours.primary,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                        ),
                                      ),

                                      GestureDetector(
                                        onTap: () => _confirmDelete(a),
                                        child: SvgPicture.asset(
                                          IconConstant.delete2,
                                          width: 18.w,
                                          height: 18.w,
                                          color: AppColours.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 10,),
                              Text(
                                a.addressLines,
                                style: CustomTextStyles.montserratRegular.copyWith(fontSize: 14),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Mobile Number: ${a.mobileDisplay}',
                                style: CustomTextStyles.montserratRegular.copyWith(
                                  fontSize: 12,
                                ),
                              ),

                              SizedBox(height: 14.h),

                              Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColours.primary,
                              ),
                            ],
                          ),
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
