import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/translations.dart';
import '../utils/shop_utils.dart';
import '../utils/subscription_utils.dart';
import '../utils/ad_manager.dart'; // অ্যাড ম্যানেজার ইমপোর্ট
import '../widgets/custom_banner_ad.dart'; // ব্যানার অ্যাড উইজেট ইমপোর্ট
import 'subscription_screen.dart';

class ProductsScreen extends StatefulWidget {
  final bool showLowStockOnly;
  const ProductsScreen({super.key, this.showLowStockOnly = false});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _discountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _sizeController = TextEditingController();
  final _unitController = TextEditingController();
  final _lowStockLimitController = TextEditingController();

  final List<String> _categoryList = [
    AppTranslations.get('cat_grocery'),
    AppTranslations.get('cat_beverage'),
    AppTranslations.get('cat_biscuits'),
    AppTranslations.get('cat_cosmetics'),
    AppTranslations.get('cat_baby'),
    AppTranslations.get('cat_vegetables'),
    AppTranslations.get('cat_frozen'),
    AppTranslations.get('cat_stationery'),
    AppTranslations.get('cat_household'),
    'Fashion (Adult)',
    'Fashion (Kids)',
    AppTranslations.get('others'),
  ];

  List<String> _allAvailableCategories = [];
  final List<String> _unitList = ['Pcs', 'Kg', 'Gram', 'Litre', 'Ml', 'Packet', 'Box', 'Dozen'];

  String _calculatedDiscountText = '';
  bool _isSaving = false;
  late String _selectedCategoryFilter;
  String _discountType = '%';

  File? _imageFile;
  String? _imageBase64String;

  // পারমিশন ভেরিয়েবল
  bool _canManageProducts = true;
  bool _isCheckingPermission = true;
  String _shopId = '';

  @override
  void initState() {
    super.initState();
    _selectedCategoryFilter = widget.showLowStockOnly ? 'Low Stock' : AppTranslations.get('all');
    _allAvailableCategories = List.from(_categoryList);
    _priceController.addListener(_calculateDiscountAmount);
    _discountController.addListener(_calculateDiscountAmount);
    _initializeData();
  }

  Future<void> _initializeData() async {
    _shopId = await ShopUtils.getShopId();
    await _checkStaffPermissions();
  }

  Future<void> _checkStaffPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    String role = prefs.getString('role') ?? 'admin';

    if (role == 'staff') {
      bool canProduct = prefs.getBool('can_product_list') ?? true;
      setState(() {
        _canManageProducts = canProduct;
        _isCheckingPermission = false;
      });
    } else {
      setState(() {
        _canManageProducts = true;
        _isCheckingPermission = false;
      });
    }
  }

  void _calculateDiscountAmount() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final inputVal = double.tryParse(_discountController.text) ?? 0.0;

    if (price > 0 && inputVal > 0) {
      if (_discountType == '%') {
        final discountAmount = (price * inputVal) / 100;
        setState(() {
          _calculatedDiscountText = '$inputVal% (${discountAmount.toStringAsFixed(0)}tk)';
        });
      } else {
        final percent = (inputVal / price) * 100;
        setState(() {
          _calculatedDiscountText = '${percent.toStringAsFixed(1)}% (${inputVal.toStringAsFixed(0)}tk)';
        });
      }
    } else {
      setState(() {
        _calculatedDiscountText = '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _discountController.dispose();
    _categoryController.dispose();
    _sizeController.dispose();
    _unitController.dispose();
    _lowStockLimitController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function dialogSetState) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 500, // রেজোলিউশন কমিয়ে সাইজ ১০০কেবি-র নিচে রাখা
      maxHeight: 500,
    );
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      
      // যদি সাইজ ১০০কেবি-র বেশি হয়, তবে আমরা maxWidth/Height আরও কমিয়ে আনতে পারি
      // বর্তমানে ৫০০x৫০০ এবং ৫০ কোয়ালিটি ১০০কেবি-র অনেক নিচেই থাকবে।
      
      String base64String = base64Encode(imageBytes);

      dialogSetState(() {
        _imageFile = imageFile;
        _imageBase64String = base64String;
      });
    }
  }

  Future<void> _captureImage(Function dialogSetState) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 500,
      maxHeight: 500,
    );
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);

      dialogSetState(() {
        _imageFile = File(pickedFile.path);
        _imageBase64String = base64String;
      });
    }
  }

  void _showImageSourceDialog(Function dialogSetState) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.get('select_image_source')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0D47A1)),
              title: Text(AppTranslations.get('take_photo')),
              onTap: () {
                Navigator.pop(dialogContext);
                _captureImage(dialogSetState);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF0D47A1)),
              title: Text(AppTranslations.get('choose_from_gallery')),
              onTap: () {
                Navigator.pop(dialogContext);
                _pickImage(dialogSetState);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openBarcodeScanner() {
    bool isScanned = false;
    final MobileScannerController controller = MobileScannerController();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (scannerContext) => Scaffold(
          appBar: AppBar(
            title: Text(AppTranslations.get('scan_barcode'), style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF0D47A1),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.flash_on),
                onPressed: () => controller.toggleTorch(),
              ),
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.cameraswitch),
                onPressed: () => controller.switchCamera(),
              ),
            ],
          ),
          body: MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (isScanned) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  isScanned = true;
                  SystemSound.play(SystemSoundType.click);
                  HapticFeedback.mediumImpact();

                  setState(() {
                    _barcodeController.text = barcode.rawValue!.trim();
                  });

                  if (scannerContext.mounted) {
                    Navigator.pop(scannerContext);
                  }
                  break;
                }
              }
            },
          ),
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _showProductDialog({DocumentSnapshot? doc}) {
    _imageFile = null;
    if (doc != null) {
      final data = doc.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _priceController.text = (data['price'] ?? '').toString();
      _costPriceController.text = (data['costPrice'] ?? '').toString();
      _stockController.text = (data['stock'] ?? '').toString();
      _barcodeController.text = data['barcode'] ?? '';
      _discountController.text = (data['discount'] ?? '').toString();
      _discountType = data['discountType'] ?? '%';
      _categoryController.text = data['category'] ?? '';
      _sizeController.text = data['size'] ?? '';
      _unitController.text = data['unit'] ?? 'Pcs';
      _lowStockLimitController.text = (data['lowStockLimit'] ?? '5').toString();
      _imageBase64String = data['imageBase64'] ?? '';
    } else {
      _nameController.clear();
      _priceController.clear();
      _costPriceController.clear();
      _stockController.clear();
      _barcodeController.clear();
      _discountController.clear();
      _discountType = '%';
      _categoryController.clear();
      _sizeController.clear();
      _unitController.text = 'Pcs';
      _lowStockLimitController.text = '5';
      _calculatedDiscountText = '';
      _imageBase64String = '';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          bool isFashionCategory = _categoryController.text.toLowerCase().contains('fashion');

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(doc == null ? AppTranslations.get('add_new_product') : AppTranslations.get('edit_product'), textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showImageSourceDialog(dialogSetState),
                    child: Container(
                      height: 90,
                      width: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0D47A1), width: 2),
                      ),
                      child: _imageFile != null
                          ? ClipOval(child: Image.file(_imageFile!, fit: BoxFit.cover))
                          : (_imageBase64String != null && _imageBase64String!.isNotEmpty)
                          ? ClipOval(
                        child: Image.memory(
                          base64Decode(_imageBase64String!),
                          fit: BoxFit.cover,
                        ),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt, color: Color(0xFF0D47A1), size: 30),
                          const SizedBox(height: 2),
                          Text(AppTranslations.get('add_image'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: AppTranslations.get('product_name')),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: isFashionCategory ? 3 : 5,
                        child: Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return _allAvailableCategories;
                            }
                            return _allAvailableCategories.where((String option) {
                              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            dialogSetState(() {
                              _categoryController.text = selection;
                              if (!selection.toLowerCase().contains('fashion')) {
                                _sizeController.clear();
                              }
                            });
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            if (controller.text.isEmpty && _categoryController.text.isNotEmpty) {
                              controller.text = _categoryController.text;
                            }
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (val) {
                                dialogSetState(() {
                                  _categoryController.text = val;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: AppTranslations.get('category'),
                                hintText: AppTranslations.get('select_or_type'),
                              ),
                            );
                          },
                        ),
                      ),
                      if (isFashionCategory) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _sizeController,
                            decoration: const InputDecoration(
                              labelText: 'সাইজ',
                              hintText: 'S/M/L/34',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: AppTranslations.get('price')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return _unitList;
                            }
                            return _unitList.where((String option) {
                              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            _unitController.text = selection;
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            if (controller.text.isEmpty && _unitController.text.isNotEmpty) {
                              controller.text = _unitController.text;
                            }
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (val) => _unitController.text = val,
                              decoration: InputDecoration(
                                labelText: AppTranslations.get('unit'),
                                hintText: AppTranslations.get('unit_hint'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _costPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: AppTranslations.get('cost_price')),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          onTap: () async {
                            if (!(await SubscriptionUtils.isPremium())) {
                              if (!mounted) return;
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                            }
                          },
                          onChanged: (val) {
                            dialogSetState(() {});
                          },
                          decoration: InputDecoration(
                            labelText: '${AppTranslations.get('discount')} ($_discountType)',
                            prefixIcon: SubscriptionUtils.premiumIcon(),
                            hintText: _discountType == '%' ? 'যেমন: 10' : 'যেমন: 50',
                            helperText: _calculatedDiscountText.isNotEmpty
                                ? 'হিসাব: $_calculatedDiscountText'
                                : null,
                            helperStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _discountType,
                          decoration: InputDecoration(labelText: AppTranslations.get('type')),
                          items: [
                            DropdownMenuItem(value: '%', child: Text('${AppTranslations.get('percent')} (%)')),
                            DropdownMenuItem(value: '৳', child: Text('${AppTranslations.get('taka')} (৳)')),
                          ],
                          onTap: () async {
                            if (!(await SubscriptionUtils.isPremium())) {
                              if (!mounted) return;
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                            }
                          },
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              dialogSetState(() {
                                _discountType = newValue;
                              });
                              _calculateDiscountAmount();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: AppTranslations.get('stock')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _lowStockLimitController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppTranslations.get('low_stock_limit'),
                      hintText: 'Default: 5',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcodeController,
                          decoration: InputDecoration(labelText: AppTranslations.get('barcode')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          if (await SubscriptionUtils.isPremium()) {
                            _openBarcodeScanner();
                          } else {
                            if (!mounted) return;
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                          }
                        },
                        icon: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            const Icon(Icons.camera_alt, color: Colors.white),
                            SubscriptionUtils.premiumIcon(),
                          ],
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(dialogContext),
                child: Text(AppTranslations.get('cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
                onPressed: _isSaving ? null : () async {
                  if (_shopId.isEmpty) return;

                  final name = _nameController.text.trim();
                  final category = _categoryController.text.trim();
                  final size = _sizeController.text.trim();
                  final unit = _unitController.text.trim();
                  final price = double.tryParse(_priceController.text) ?? 0.0;
                  final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
                  final stock = double.tryParse(_stockController.text) ?? 0.0;
                  final lowStockLimit = double.tryParse(_lowStockLimitController.text) ?? 5.0;
                  final barcode = _barcodeController.text.trim();
                  final discount = double.tryParse(_discountController.text) ?? 0.0;

                  if (name.isEmpty) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(AppTranslations.get('product_name_required'))),
                      );
                    }
                    return;
                  }

                  dialogSetState(() => _isSaving = true);
                  setState(() => _isSaving = true);

                  try {
                    final productsRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(_shopId)
                        .collection('products');

                    if (barcode.isNotEmpty) {
                      final existingBarcodeQuery = await productsRef
                          .where('barcode', isEqualTo: barcode)
                          .get();

                      bool isDuplicate = false;
                      for (var document in existingBarcodeQuery.docs) {
                        if (doc == null || document.id != doc.id) {
                          isDuplicate = true;
                          break;
                        }
                      }

                      if (isDuplicate) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(AppTranslations.get('duplicate_barcode_msg')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        dialogSetState(() => _isSaving = false);
                        setState(() => _isSaving = false);
                        return;
                      }
                    }

                    final productData = {
                      'name': name,
                      'category': category.isEmpty ? AppTranslations.get('others') : category,
                      'size': size,
                      'unit': unit.isEmpty ? 'Pcs' : unit,
                      'price': price,
                      'costPrice': costPrice,
                      'stock': stock,
                      'lowStockLimit': lowStockLimit,
                      'barcode': barcode,
                      'discount': discount,
                      'discountType': _discountType,
                      'imageBase64': _imageBase64String ?? '',
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (doc == null) {
                      // নতুন প্রোডাক্ট অ্যাড করার সময় অ্যাড চেক
                      AdManager.checkAndShowProductAd(() async {
                        productData['createdAt'] = FieldValue.serverTimestamp();
                        await productsRef.add(productData);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppTranslations.get('product_saved_msg')), backgroundColor: Colors.green),
                          );
                        }
                      });
                    } else {
                      await productsRef.doc(doc.id).update(productData);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppTranslations.get('product_saved_msg')), backgroundColor: Colors.green),
                        );
                      }
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(AppTranslations.get('error_msg').replaceAll('@error', e.toString())), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (dialogContext.mounted) {
                      dialogSetState(() => _isSaving = false);
                    }
                    if (mounted) {
                      setState(() => _isSaving = false);
                    }
                  }
                },
                child: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : Text(AppTranslations.get('save'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _verifyPinAndDelete(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('app_pin') ?? '1234';

    final pinController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.get('security_pin')),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: InputDecoration(labelText: AppTranslations.get('enter_app_pin')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppTranslations.get('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (pinController.text.trim() == savedPin) {
                Navigator.pop(dialogContext);
                if (_shopId.isEmpty) return;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_shopId)
                    .collection('products')
                    .doc(productId)
                    .delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('product_deleted_msg')), backgroundColor: Colors.red),
                  );
                }
              } else {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('invalid_pin_msg')), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(AppTranslations.get('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _verifyPinAndCategoryDelete(String cat) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('app_pin') ?? '1234';
    final pinController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.get('security_pin')),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: InputDecoration(labelText: AppTranslations.get('category_delete_pin_msg')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppTranslations.get('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (pinController.text.trim() == savedPin) {
                Navigator.pop(dialogContext);
                setState(() {
                  _categoryList.remove(cat);
                  _allAvailableCategories.remove(cat);
                  if (_selectedCategoryFilter == cat) {
                    _selectedCategoryFilter = AppTranslations.get('all');
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppTranslations.get('category_deleted_msg')), backgroundColor: Colors.red),
                );
              } else {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('invalid_pin_msg')), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(AppTranslations.get('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_isCheckingPermission) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1))),
      );
    }

    if (!_canManageProducts) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppTranslations.get('product_management'), style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF0D47A1),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              AppTranslations.get('no_access_msg'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('product_management'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _shopId.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_shopId)
            .collection('products')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProducts = snapshot.data!.docs;

          final Map<String, int> categoryCounts = {};
          for (var cat in _categoryList) {
            categoryCounts[cat] = 0;
          }

          for (var doc in allProducts) {
            final data = doc.data() as Map<String, dynamic>;
            final cat = data['category'];
            if (cat != null && cat.toString().trim().isNotEmpty) {
              final catStr = cat.toString().trim();
              categoryCounts[catStr] = (categoryCounts[catStr] ?? 0) + 1;
            }
          }

          final Set<String> dynamicCategories = {};
          final sortedCategoriesByUsage = categoryCounts.keys.toList()
            ..sort((a, b) => (categoryCounts[b] ?? 0).compareTo(categoryCounts[a] ?? 0));

          for (var cat in sortedCategoriesByUsage) {
            dynamicCategories.add(cat);
          }
          for (var doc in allProducts) {
            final data = doc.data() as Map<String, dynamic>;
            final cat = data['category'];
            if (cat != null && cat.toString().trim().isNotEmpty) {
              dynamicCategories.add(cat.toString().trim());
            }
          }
          _allAvailableCategories = dynamicCategories.toList();

          double totalCostPrice = 0.0;
          double totalSaleValue = 0.0;

          for (var doc in allProducts) {
            final data = doc.data() as Map<String, dynamic>;
            final stock = double.tryParse((data['stock'] ?? 0).toString()) ?? 0.0;
            final costPrice = double.tryParse((data['costPrice'] ?? 0).toString()) ?? 0.0;
            final price = double.tryParse((data['price'] ?? 0).toString()) ?? 0.0;
            final discount = double.tryParse((data['discount'] ?? 0).toString()) ?? 0.0;
            final discountType = data['discountType'] ?? '%';

            double effectivePrice = price;
            if (discount > 0) {
              if (discountType == '%') {
                effectivePrice = price - ((price * discount) / 100);
              } else {
                effectivePrice = price - discount;
              }
              if (effectivePrice < 0) effectivePrice = 0;
            }

            totalCostPrice += (costPrice * stock);
            totalSaleValue += (effectivePrice * stock);
          }

          double totalProfit = totalSaleValue - totalCostPrice;

          final products = allProducts.where((doc) {
            if (_selectedCategoryFilter == AppTranslations.get('all')) return true;
            final data = doc.data() as Map<String, dynamic>;
            if (_selectedCategoryFilter == 'Low Stock') {
              double stock = double.tryParse((data['stock'] ?? 0).toString()) ?? 0.0;
              double limit = double.tryParse((data['lowStockLimit'] ?? 5).toString()) ?? 5.0;
              return stock <= limit;
            }
            return data['category'] == _selectedCategoryFilter;
          }).toList();

          return Column(
            children: [
              const CustomBannerAd(),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.grey.shade100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(AppTranslations.get('all')),
                        selected: _selectedCategoryFilter == AppTranslations.get('all'),
                        onSelected: (selected) {
                          setState(() => _selectedCategoryFilter = AppTranslations.get('all'));
                        },
                      ),
                    ),
                    ..._allAvailableCategories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onLongPress: () {
                            _verifyPinAndCategoryDelete(cat);
                          },
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: _selectedCategoryFilter == cat,
                            onSelected: (selected) {
                              setState(() => _selectedCategoryFilter = cat);
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(AppTranslations.get('total_purchase'), '৳${totalCostPrice.toStringAsFixed(0)}', Colors.white),
                    Container(height: 30, width: 1, color: Colors.white54),
                    _buildSummaryItem(AppTranslations.get('will_be_sold'), '৳${totalSaleValue.toStringAsFixed(0)}', Colors.white),
                    Container(height: 30, width: 1, color: Colors.white54),
                    _buildSummaryItem(AppTranslations.get('will_be_profit'), '৳${totalProfit.toStringAsFixed(0)}', Colors.greenAccent),
                  ],
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? Center(child: Text(AppTranslations.get('no_product_found_cat')))
                    : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final doc = products[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final discountVal = double.tryParse((data['discount'] ?? 0).toString()) ?? 0.0;
                    final discountType = data['discountType'] ?? '%';
                    final price = double.tryParse((data['price'] ?? 0).toString()) ?? 0.0;
                    final unit = data['unit'] ?? 'Pcs';
                    final category = data['category'] ?? AppTranslations.get('others');
                    final size = data['size'] ?? '';
                    final imageBase64 = data['imageBase64'] ?? '';

                    String discountDisplay = '';
                    if (discountVal > 0) {
                      if (discountType == '%') {
                        final amt = (price * discountVal) / 100;
                        discountDisplay = '| ${AppTranslations.get('discount')}: $discountVal% (${amt.toStringAsFixed(0)}tk)';
                      } else {
                        final pct = price > 0 ? (discountVal / price) * 100 : 0.0;
                        discountDisplay = '| ${AppTranslations.get('discount')}: ${pct.toStringAsFixed(1)}% (${discountVal.toStringAsFixed(0)}tk)';
                      }
                    }

                    String sizeDisplay = size.isNotEmpty ? ' | ${AppTranslations.get('size') ?? 'Size'}: $size' : '';

                    final double stock = double.tryParse((data['stock'] ?? 0).toString()) ?? 0.0;
                    final double limit = double.tryParse((data['lowStockLimit'] ?? 5).toString()) ?? 5.0;
                    bool isLowStock = stock <= limit;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isLowStock ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageBase64.isNotEmpty
                              ? Image.memory(
                            base64Decode(imageBase64),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image_not_supported, color: Colors.grey),
                              );
                            },
                          )
                              : Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                        title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${AppTranslations.get('category')}: $category$sizeDisplay\n${AppTranslations.get('price')}: ৳$price / $unit $discountDisplay\n${AppTranslations.get('stock')}: ${data['stock']} $unit | ${AppTranslations.get('barcode')}: ${data['barcode'] ?? AppTranslations.get('none')}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showProductDialog(doc: doc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _verifyPinAndDelete(doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0D47A1),
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}