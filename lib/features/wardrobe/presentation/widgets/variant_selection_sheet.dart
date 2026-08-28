import 'package:flutter/material.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/features/products/data/models/product.dart';
import 'package:nomowear/features/products/data/models/product_variant.dart';
import 'package:nomowear/features/products/data/product_mapper.dart';

class VariantSelectionSheet extends StatefulWidget {
  final Product product;
  final ProductVariant? initialVariant;

  const VariantSelectionSheet({
    Key? key,
    required this.product,
    this.initialVariant,
  }) : super(key: key);

  static Future<ProductVariant?> show(
    BuildContext context, 
    Product product, {
    ProductVariant? initialVariant,
  }) {
    return showModalBottomSheet<ProductVariant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: VariantSelectionSheet(
            product: product,
            initialVariant: initialVariant,
          ),
        ),
      ),
    );
  }

  @override
  State<VariantSelectionSheet> createState() => _VariantSelectionSheetState();
}

class _VariantSelectionSheetState extends State<VariantSelectionSheet> {
  final List<String> _availableColors = [];
  String? _selectedColor;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    _extractColors();
    if (widget.initialVariant != null) {
      _selectedColor = ProductMapper.optionValue(widget.initialVariant!, 'Color');
      _selectedSize = ProductMapper.optionValue(widget.initialVariant!, 'Size');
    }
    if ((_selectedColor == null || _selectedColor!.isEmpty) && _availableColors.isNotEmpty) {
      _selectedColor = _availableColors.first;
    }
  }

  void _extractColors() {
    final Set<String> colorSet = {};
    for (final variant in widget.product.variants) {
      final color = ProductMapper.optionValue(variant, 'Color');
      if (color != null && color.isNotEmpty) {
        colorSet.add(color);
      }
    }
    _availableColors.addAll(colorSet);
  }

  List<String> _getAvailableSizesForColor(String color) {
    final Set<String> sizeSet = {};
    for (final variant in widget.product.variants) {
      final vColor = ProductMapper.optionValue(variant, 'Color');
      if (vColor?.toLowerCase() == color.toLowerCase()) {
        final size = ProductMapper.optionValue(variant, 'Size');
        if (size != null && size.isNotEmpty) {
          sizeSet.add(size);
        }
      }
    }
    // Predefined order for known sizes if desired, otherwise default.
    final ordered = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
    final result = sizeSet.toList();
    result.sort((a, b) {
      final iA = ordered.indexOf(a.toUpperCase());
      final iB = ordered.indexOf(b.toUpperCase());
      if (iA != -1 && iB != -1) return iA.compareTo(iB);
      if (iA != -1) return -1;
      if (iB != -1) return 1;
      return a.compareTo(b);
    });
    return result;
  }

  ProductVariant? _resolveVariant() {
    if (_selectedColor == null || _selectedSize == null) return null;
    return ProductMapper.matchingVariant(
      variants: widget.product.variants,
      selectedColor: _selectedColor,
      selectedSize: _selectedSize!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = _selectedColor != null ? _getAvailableSizesForColor(_selectedColor!) : <String>[];
    if (_selectedSize != null && !sizes.contains(_selectedSize)) {
      _selectedSize = null;
    }
    
    final variant = _resolveVariant();
    final canSubmit = variant != null && variant.stockOnHand > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'SELECT SIZE & VARIANT',
            textAlign: TextAlign.center,
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 14,
              color: AppColours.primary,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            widget.product.productName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.fSize,
            ),
          ),
          SizedBox(height: 24.h),

          // Size Selection
          Text(
            'SIZE${_selectedSize != null ? ': $_selectedSize' : ''}',
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 12,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: sizes.map((s) => _buildChoiceChip(
              text: s,
              isSelected: s == _selectedSize,
              onTap: () {
                setState(() => _selectedSize = s);
              },
            )).toList(),
          ),
          SizedBox(height: 24.h),

          // Color Selection
          Text(
            'COLOR${_selectedColor != null ? ': $_selectedColor' : ''}',
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 12,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: _availableColors.map((c) => _buildChoiceChip(
              text: c,
              isSelected: c == _selectedColor,
              onTap: () {
                setState(() => _selectedColor = c);
              },
            )).toList(),
          ),
          SizedBox(height: 32.h),

          // Summary
          if (variant != null) ...[
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFF16181D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColours.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${variant.actualPrice}',
                    style: CustomTextStyles.montserratBold.copyWith(
                      fontSize: 16,
                      color: AppColours.primary,
                    ),
                  ),
                  Text(
                    '$_selectedSize / $_selectedColor',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.fSize,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
          ],

          // Action Buttons
          SizedBox(
            height: 48.h,
            child: ElevatedButton(
              onPressed: canSubmit ? () {
                debugPrint('===== ADD TO CART VARIANT SELECTION =====');
                debugPrint('PRODUCT ID = ${widget.product.id}');
                debugPrint('SELECTED COLOR = $_selectedColor');
                debugPrint('SELECTED SIZE = $_selectedSize');
                debugPrint('SELECTED VARIANT ID = ${variant.id}');
                debugPrint('SELECTED VARIANT NAME = ${variant.variantName}');
                debugPrint('SELECTED STOCK = ${variant.stockOnHand}');
                debugPrint('==========================================');
                Navigator.pop(context, variant);
              } : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColours.primary,
                disabledBackgroundColor: AppColours.primary.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'ADD TO CART',
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 13,
                  color: canSubmit ? Colors.black : Colors.white24,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 48.h,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColours.primary.withOpacity(0.4)),
                ),
              ),
              child: Text(
                'DONE',
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 13,
                  color: AppColours.primary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColours.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColours.primary : Colors.white24,
          ),
        ),
        child: Text(
          text,
          style: CustomTextStyles.montserratSemiBold.copyWith(
            fontSize: 13,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}
