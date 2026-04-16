import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart'; // Ensure this contains kGreyBg & kPrimaryColor
import 'package:heroicons/heroicons.dart';

class AddCategoryPopup extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const AddCategoryPopup({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<AddCategoryPopup> createState() => _AddCategoryPopupState();
}

class _AddCategoryPopupState extends State<AddCategoryPopup> {
  final TextEditingController _categoryController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final userData = await PermissionHelper.getUserPermissions(widget.uid);
    final role = userData['role'] as String;
    final permissions = userData['permissions'] as Map<String, dynamic>;
    final isAdmin = role.toLowerCase() == 'owner';
    final hasPermission = permissions['addCategory'] == true;

    if (!hasPermission && !isAdmin && mounted) {
      Navigator.pop(context);
      await PermissionHelper.showPermissionDeniedDialog(context);
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    final categoryName = _categoryController.text.trim();
    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_category_name'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final categoriesCollection = await FirestoreService().getStoreCollection('categories');

      // Check if category already exists
      final existingCategory = await categoriesCollection.where('name', isEqualTo: categoryName).get();
      if (existingCategory.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('category_exists'))),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Add new category
      await FirestoreService().addDocument('categories', {
        'name': categoryName,
        'createdAt': FieldValue.serverTimestamp(),
        'ownerUid': widget.uid,
        'ownerEmail': widget.userEmail,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('category_added_success'))),
      );
      Navigator.pop(context, categoryName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('failed_to_save'))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('add_category'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const HeroIcon(HeroIcons.xMark, size: 24, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Input Field
            _buildCategoryInput(),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  context.tr('add'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Custom Input Field ---
  Widget _buildCategoryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<TextEditingValue>(
      valueListenable: _categoryController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
          controller: _categoryController,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          decoration: InputDecoration(
            labelText:'Category Name',
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
            ),
            labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
            floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
          ),
        
);
      },
    ),
        const SizedBox(height: 6),
        Text(
          "e.g. Fruit, Vegetable, Steel, Plastics, etc.",
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),

      ],
    );
  }

}
