import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTranslations {
  static String currentLanguage = 'bn';

  static final Map<String, Map<String, String>> _localizedValues = {
    'app_name': {
      'en': 'Amar Dokan',
      'bn': 'আমার দোকান',
    },
    'dashboard': {
      'en': 'Dashboard',
      'bn': 'ড্যাশবোর্ড',
    },
    'products': {
      'en': 'Products',
      'bn': 'পণ্য তালিকা',
    },
    'pos': {
      'en': 'POS',
      'bn': 'বিক্রি করুন',
    },
    'hisab': {
      'en': 'Accounts',
      'bn': 'হিসাব কিতাব',
    },
    'customers': {
      'en': 'Customers',
      'bn': 'কাস্টমার',
    },
    'staff': {
      'en': 'Staff Management',
      'bn': 'স্টাফ ম্যানেজমেন্ট',
    },
    'settings': {
      'en': 'Settings',
      'bn': 'সেটিংস',
    },
    'owner': {
      'en': 'Owner',
      'bn': 'মালিক',
    },
    'menu_choose': {
      'en': 'Choose Menu:',
      'bn': 'মেনু বেছে নিন:',
    },
    'app_settings': {
      'en': 'App Settings',
      'bn': 'অ্যাপ সেটিংস',
    },
    'profile_shop_info': {
      'en': 'Profile & Shop Info',
      'bn': 'প্রোফাইল ও দোকান তথ্য',
    },
    'owner_name': {
      'en': 'Owner Name',
      'bn': 'মালিকের নাম',
    },
    'shop_name': {
      'en': 'Shop Name',
      'bn': 'দোকানের নাম',
    },
    'mobile': {
      'en': 'Mobile Number',
      'bn': 'মোবাইল নম্বর',
    },
    'address': {
      'en': 'Address',
      'bn': 'দোকানের ঠিকানা',
    },
    'footer_note': {
      'en': 'Footer Note',
      'bn': 'মেমোর নিচের নোট',
    },
    'security_settings': {
      'en': 'Security Settings',
      'bn': 'নিরাপত্তা সেটিংস',
    },
    'change_pin': {
      'en': 'Change App PIN',
      'bn': 'অ্যাপের পিন কোড পরিবর্তন',
    },
    'fingerprint': {
      'en': 'Fingerprint Unlock',
      'bn': 'ফিঙ্গারপ্রিন্ট আনলক',
    },
    'save_settings': {
      'en': 'Save Settings',
      'bn': 'সেটিং সেভ করুন',
    },
    'logout': {
      'en': 'Logout',
      'bn': 'লগআউট করুন',
    },
    'language': {
      'en': 'Language',
      'bn': 'ভাষা',
    },
    'select_language': {
      'en': 'Select Language',
      'bn': 'ভাষা নির্বাচন করুন',
    },
    // Product Screen
    'product_management': {
      'en': 'Product Management',
      'bn': 'পণ্য ম্যানেজমেন্ট',
    },
    'add_new_product': {
      'en': 'Add New Product',
      'bn': 'নতুন পণ্য যোগ করুন',
    },
    'edit_product': {
      'en': 'Edit Product',
      'bn': 'পণ্য এডিট করুন',
    },
    'product_name': {
      'en': 'Product Name',
      'bn': 'পণ্যের নাম',
    },
    'category': {
      'en': 'Category',
      'bn': 'ক্যাটাগরি',
    },
    'price': {
      'en': 'Sale Price',
      'bn': 'বিক্রয় মূল্য (Price)',
    },
    'cost_price': {
      'en': 'Cost Price',
      'bn': 'ক্রয় মূল্য (Cost Price)',
    },
    'stock': {
      'en': 'Stock',
      'bn': 'স্টক পরিমাণ (Stock)',
    },
    'barcode': {
      'en': 'Barcode',
      'bn': 'বারকোড (Barcode)',
    },
    'discount': {
      'en': 'Discount',
      'bn': 'ডিসকাউন্ট',
    },
    'save': {
      'en': 'Save',
      'bn': 'সংরক্ষণ করুন',
    },
    'cancel': {
      'en': 'Cancel',
      'bn': 'বাতিল',
    },
    'all': {
      'en': 'All',
      'bn': 'সব',
    },
    'login': {
      'en': 'Login',
      'bn': 'লগইন',
    },
    'register': {
      'en': 'Register',
      'bn': 'নিবন্ধন করুন',
    },
    'email': {
      'en': 'Email',
      'bn': 'ইমেইল',
    },
    'password': {
      'en': 'Password',
      'bn': 'পাসওয়ার্ড',
    },
    'dont_have_account': {
      'en': 'Don\'t have an account?',
      'bn': 'অ্যাকাউন্ট নেই?',
    },
    'already_have_account': {
      'en': 'Already have an account?',
      'bn': 'ইতিমধ্যে অ্যাকাউন্ট আছে?',
    },
    'total_purchase': {
      'en': 'Total Purchase',
      'bn': 'মোট ক্রয়',
    },
    'will_be_sold': {
      'en': 'Will be Sold',
      'bn': 'বিক্রি হবে',
    },
    'will_be_profit': {
      'en': 'Will be Profit',
      'bn': 'লাভ হবে',
    },
    'search_product': {
      'en': 'Search by product name or barcode...',
      'bn': 'পণ্যের নাম বা বারকোড দিয়ে খুঁজুন...',
    },
    'cart': {
      'en': 'Cart',
      'bn': 'কার্ট',
    },
    'payment_info': {
      'en': 'Payment & Summary',
      'bn': 'পেমেন্ট ও হিসাব বিবরণী',
    },
    'confirm_sale': {
      'en': 'Confirm Sale',
      'bn': 'বিক্রি কনফার্ম করুন',
    },
    'total_amount': {
      'en': 'Total Amount',
      'bn': 'মোট টাকা',
    },
    'cash': {
      'en': 'Cash',
      'bn': 'নগদ',
    },
    'due': {
      'en': 'Due',
      'bn': 'বাকি',
    },
    'customer_info': {
      'en': 'Customer Info (Optional)',
      'bn': 'কাস্টমার তথ্য যোগ করুন (ঐচ্ছিক)',
    },
    'customer_list': {
      'en': 'Customer List',
      'bn': 'কাস্টমার তালিকা',
    },
    'today_total_baki': {
      'en': 'Today\'s Total Due',
      'bn': 'আজকের মোট বাকি',
    },
    'today_total_jama': {
      'en': 'Today\'s Total Collection',
      'bn': 'আজকের মোট জমা',
    },
    'search_customer_hint': {
      'en': 'Search customer (name or phone)...',
      'bn': 'কাস্টমার খুঁজুন (নাম বা ফোন দিয়ে)...',
    },
    'no_customer_found': {
      'en': 'No customer found!',
      'bn': 'কোনো কাস্টমার পাওয়া যায়নি!',
    },
    'add_customer': {
      'en': 'Add New Customer',
      'bn': 'নতুন কাস্টমার যোগ করুন',
    },
    'customer_name': {
      'en': 'Customer Name',
      'bn': 'কাস্টমারের নাম',
    },
    'phone': {
      'en': 'Phone',
      'bn': 'ফোন',
    },
    'update': {
      'en': 'Update',
      'bn': 'আপডেট করুন',
    },
    'delete': {
      'en': 'Delete',
      'bn': 'ডিলিট করুন',
    },
    'accounts_summary': {
      'en': 'Accounts Summary',
      'bn': 'হিসাব কিতাব সারসংক্ষেপ',
    },
    'total_sales': {
      'en': 'Total Sales',
      'bn': 'মোট বিক্রি',
    },
    'total_profit': {
      'en': 'Total Profit',
      'bn': 'মোট লাভ',
    },
    'daily_report': {
      'en': 'Daily Report',
      'bn': 'দৈনিক হিসাব',
    },
    'monthly_report': {
      'en': 'Monthly Report',
      'bn': 'মাসিক হিসাব',
    },
    'employee': {
      'en': 'Employees',
      'bn': 'কর্মচারী',
    },
    'add_employee': {
      'en': 'Add Employee',
      'bn': 'কর্মচারী যোগ করুন',
    },
    'add_expense': {
      'en': 'Add Expense',
      'bn': 'খরচ যোগ করুন',
    },
    'expense_salary': {
      'en': 'Expense / Salary',
      'bn': 'খরচ / বেতন',
    },
    'salary': {
      'en': 'Salary',
      'bn': 'বেতন',
    },
    'edit_info': {
      'en': 'Edit Info',
      'bn': 'এডিট তথ্য',
    },
    'pay_salary': {
      'en': 'Pay Salary',
      'bn': 'বেতন প্রদান করুন',
    },
    'security_pin': {
      'en': 'Security PIN',
      'bn': 'সিকিউরিটি পিন',
    },
    'enter_pin': {
      'en': 'Enter your PIN',
      'bn': 'আপনার পিন লিখুন',
    },
    'confirm': {
      'en': 'Confirm',
      'bn': 'নিশ্চিত করুন',
    },
    'sales_history': {
      'en': 'Sales History',
      'bn': 'বিক্রির ইতিহাস',
    },
    'no_record_found': {
      'en': 'No record found',
      'bn': 'কোনো রেকর্ড পাওয়া যায়নি',
    },
    'added_by': {
      'en': 'Added by',
      'bn': 'যুক্ত করেছেন',
    },
    'time': {
      'en': 'Time',
      'bn': 'সময়',
    },
    'date': {
      'en': 'Date',
      'bn': 'তারিখ',
    },
    'no_permission': {
      'en': 'Sorry, you do not have permission to access this section!',
      'bn': 'দুঃখিত, আপনার এই সেকশনটি অ্যাক্সেস করার অনুমতি নেই!',
    },
    'today_summary': {
      'en': 'Today\'s Summary',
      'bn': 'আজকের সারসংক্ষেপ',
    },
    'history': {
      'en': 'History',
      'bn': 'ইতিহাস',
    },
    'edit': {
      'en': 'Edit',
      'bn': 'এডিট',
    },
    'size': {
      'en': 'Size',
      'bn': 'সাইজ',
    },
    'no_stock_msg': {
      'en': 'No more stock available!',
      'bn': 'স্টকে আর পণ্য নেই!',
    },
    'stock_out_msg': {
      'en': 'Product is out of stock!',
      'bn': 'পণ্যটি স্টক আউট!',
    },
    'stock_limit_msg': {
      'en': 'Cannot add more than stock limit!',
      'bn': 'স্টক লিমিটের বেশি যোগ করা যাবে না!',
    },
    'change_qty': {
      'en': 'Change Quantity/Measure',
      'bn': 'পরিমাণ বা পরিমাপ পরিবর্তন করুন',
    },
    'qty_hint': {
      'en': 'Quantity (e.g. 1, 0.5)',
      'bn': 'পরিমাণ (যেমন: 1, 0.5, 2.5)',
    },
    'invalid_qty_msg': {
      'en': 'Enter valid quantity within stock limit!',
      'bn': 'সঠিক পরিমাণ বা স্টক লিমিটের মধ্যে দিন!',
    },
    'edit_discount': {
      'en': 'Edit Discount (% or Tk)',
      'bn': 'ডিসকাউন্ট এডিট করুন (% বা টাকা)',
    },
    'discount_percent': {
      'en': 'Discount Percent (%)',
      'bn': 'ডিসকাউন্ট পারসেন্ট (%)',
    },
    'discount_tk': {
      'en': 'Discount Amount (Tk)',
      'bn': 'ডিসকাউন্ট টাকা (Tk)',
    },
    'invalid_discount_msg': {
      'en': 'Enter valid discount between 0 and 100!',
      'bn': '০ থেকে ১০০ এর মধ্যে সঠিক ডিসকাউন্ট দিন!',
    },
    'due_sale_required_msg': {
      'en': 'Customer name, phone, and address are required for due sales!',
      'bn': 'বাকি বিক্রির ক্ষেত্রে কাস্টমারের নাম, মোবাইল নম্বর এবং ঠিকানা অবশ্যই দিতে হবে!',
    },
    'sale_confirmation': {
      'en': 'Sale Confirmation',
      'bn': 'বিক্রি কনফার্মেশন',
    },
    'sale_confirm_question': {
      'en': 'Are you sure you want to complete this sale?',
      'bn': 'আপনি কি নিশ্চিতভাবে এই বিক্রিটি সম্পন্ন করতে চান?',
    },
    'sale_success': {
      'en': 'Sale Successful!',
      'bn': 'বিক্রি সফল হয়েছে!',
    },
    'print_share_question': {
      'en': 'Do you want to share or print the bill?',
      'bn': 'আপনি কি বিলটি শেয়ার বা প্রিন্ট করতে চান?',
    },
    'share': {
      'en': 'Share',
      'bn': 'শেয়ার',
    },
    'print': {
      'en': 'Print',
      'bn': 'প্রিন্ট',
    },
    'hide_profit': {
      'en': 'Hide Profit',
      'bn': 'প্রফিট লুকান',
    },
    'show_profit': {
      'en': 'Show Profit',
      'bn': 'প্রফিট দেখুন',
    },
    'qty_price_header': {
      'en': 'Qty / Price',
      'bn': 'পরিমাণ / মূল্য',
    },
    'empty_cart_msg': {
      'en': 'No items added to cart',
      'bn': 'কোনো পণ্য কার্টে যোগ করা হয়নি',
    },
    'add_discount': {
      'en': 'Add Discount',
      'bn': 'ডিসকাউন্ট যোগ করুন',
    },
    'payment_type': {
      'en': 'Payment Type',
      'bn': 'পেমেন্ট টাইপ',
    },
    'default': {
      'en': 'Default',
      'bn': 'ডিফল্ট',
    },
    'enter_cash_paid': {
      'en': 'Enter cash paid',
      'bn': 'নগদ টাকা লিখুন',
    },
    'confirm_sale_btn': {
      'en': 'Confirm Sale (Update Stock & Accounts)',
      'bn': 'বিক্রি কনফার্ম করুন (স্টক ও হিসাব আপডেট)',
    },
    'barcode_box_hint': {
      'en': 'Hold barcode inside the box',
      'bn': 'বক্সের ভেতরে বারকোডটি ধরুন',
    },
    'no_image': {
      'en': 'No Image',
      'bn': 'ছবি নেই',
    },
    'login_title': {
      'en': 'Log in to your account',
      'bn': 'আপনার অ্যাকাউন্টে প্রবেশ করুন',
    },
    'register_title': {
      'en': 'Open a new business account',
      'bn': 'নতুন ব্যবসার অ্যাকাউন্ট খুলুন',
    },
    'invalid_login_msg': {
      'en': 'Enter correct mobile number and 4-digit PIN!',
      'bn': 'সঠিক মোবাইল নম্বর এবং ৪ ডিজিটের পিন দিন!',
    },
    'user_not_found': {
      'en': 'No account registered with this mobile number!',
      'bn': 'এই মোবাইল নম্বর দিয়ে কোনো অ্যাকাউন্ট রেজিস্টার্ড নেই!',
    },
    'wrong_pin': {
      'en': 'Wrong PIN provided!',
      'bn': 'ভুল পিন দিয়েছেন!',
    },
    'required_fields_msg': {
      'en': 'Shop name, owner name, and mobile number are required!',
      'bn': 'দোকানের নাম, মালিকের নাম এবং মোবাইল নম্বর আবশ্যক!',
    },
    'pin_mismatch_msg': {
      'en': 'PIN must be 4 digits and both PINs must match!',
      'bn': 'পিন ৪ ডিজিটের হতে হবে এবং পিন দুটি মিলতে হবে!',
    },
    'phone_exists_msg': {
      'en': 'An account already exists with this mobile number!',
      'bn': 'এই মোবাইল নম্বর দিয়ে ইতিমধ্যে একটি অ্যাকাউন্ট রয়েছে!',
    },
    'account_created_msg': {
      'en': 'Account created successfully!',
      'bn': 'অ্যাকাউন্ট সফলভাবে তৈরি হয়েছে!',
    },
    'new_account_question': {
      'en': 'Want to open a new account? Sign Up',
      'bn': 'নতুন অ্যাকাউন্ট খুলতে চান? সাইন আপ করুন',
    },
    'already_have_account_question': {
      'en': 'Already have an account? Login',
      'bn': 'আগে থেকেই অ্যাকাউন্ট আছে? লগইন করুন',
    },
    'staff_login_btn': {
      'en': 'Login as Staff',
      'bn': 'স্টাফ হিসেবে লগইন করুন',
    },
    'remember_phone': {
      'en': 'Remember number',
      'bn': 'নম্বর মনে রাখুন',
    },
    'biometric': {
      'en': 'Biometric',
      'bn': 'বায়োমেট্রিক',
    },
    'staff_added_msg': {
      'en': 'Staff and permissions added successfully!',
      'bn': 'স্টাফ এবং পারমিশন সফলভাবে যোগ করা হয়েছে!',
    },
    'staff_updated_msg': {
      'en': 'Staff info updated successfully!',
      'bn': 'স্টাফের তথ্য সফলভাবে আপডেট করা হয়েছে!',
    },
    'edit_staff_access': {
      'en': 'Edit Staff Info & Access',
      'bn': 'স্টাফের তথ্য ও অ্যাক্সেস পরিবর্তন',
    },
    'new_staff_access': {
      'en': 'New Staff & Access Control',
      'bn': 'নতুন স্টাফ ও অ্যাক্সেস কন্ট্রোল',
    },
    'staff_name': {
      'en': 'Staff Name',
      'bn': 'স্টাফের নাম',
    },
    'name_required': {
      'en': 'Please enter name',
      'bn': 'নাম লিখুন',
    },
    'username_login': {
      'en': 'Username (for login)',
      'bn': 'ইউজারনেম (লগইনের জন্য)',
    },
    'username_required': {
      'en': 'Please enter username',
      'bn': 'ইউজারনেম লিখুন',
    },
    'password_pin': {
      'en': 'Password or PIN',
      'bn': 'পাসওয়ার্ড বা পিন',
    },
    'password_required': {
      'en': 'Please enter password',
      'bn': 'পাসওয়ার্ড দিন',
    },
    'feature_permissions': {
      'en': 'Feature Access Permissions:',
      'bn': 'ফিচার এক্সেস পারমিশন:',
    },
    'product_list_perm': {
      'en': 'Product List',
      'bn': 'পণ্য তালিকা',
    },
    'pos_sale_perm': {
      'en': 'POS Sale',
      'bn': 'বিক্রি করুন',
    },
    'accounts_perm': {
      'en': 'Accounts',
      'bn': 'হিসাব কিতাব',
    },
    'customer_perm': {
      'en': 'Customer',
      'bn': 'কাস্টমার',
    },
    'delete_confirm_title': {
      'en': 'Are you sure?',
      'bn': 'নিশ্চিত করুন',
    },
    'delete_staff_msg': {
      'en': 'Do you want to delete this staff?',
      'bn': 'আপনি কি এই স্টাফকে মুছে ফেলতে চান?',
    },
    'no': {
      'en': 'No',
      'bn': 'না',
    },
    'yes': {
      'en': 'Yes',
      'bn': 'হ্যাঁ',
    },
    'yes_delete': {
      'en': 'Yes, Delete',
      'bn': 'হ্যাঁ, ডিলিট',
    },
    'staff_deleted_msg': {
      'en': 'Staff deleted successfully!',
      'bn': 'স্টাফ সফলভাবে মুছে ফেলা হয়েছে!',
    },
    'add_new_staff': {
      'en': 'Add New Staff',
      'bn': 'নতুন স্টাফ যোগ করুন',
    },
    'no_staff_added': {
      'en': 'No staff added!',
      'bn': 'কোনো স্টাফ যোগ করা হয়নি!',
    },
    'access': {
      'en': 'Access',
      'bn': 'অ্যাক্সেস',
    },
    'receive_payment': {
      'en': 'Receive Payment (Jama)',
      'bn': 'টাকা গ্রহণ (জমা)',
    },
    'add_new_due': {
      'en': 'Add New Due',
      'bn': 'নতুন বাকি যুক্ত করুন',
    },
    'current_total_due': {
      'en': 'Current Total Due',
      'bn': 'বর্তমান মোট বাকি',
    },
    'amount_tk': {
      'en': 'Amount (৳)',
      'bn': 'টাকার পরিমাণ (৳)',
    },
    'description_optional': {
      'en': 'Description / Note (Optional)',
      'bn': 'বিবরণ / নোট (ঐচ্ছিক)',
    },
    'payment_received': {
      'en': 'Payment Received',
      'bn': 'টাকা পরিশোধ',
    },
    'new_due': {
      'en': 'New Due',
      'bn': 'নতুন বাকি',
    },
    'total_due': {
      'en': 'Total Due',
      'bn': 'মোট বাকি',
    },
    'call': {
      'en': 'Call',
      'bn': 'কল দিন',
    },
    'sms_reminder': {
      'en': 'SMS Reminder',
      'bn': 'SMS তাগাদা',
    },
    'jama_cash': {
      'en': 'Cash Receive',
      'bn': 'টাকা জমা নিন',
    },
    'add_due': {
      'en': 'Add Due',
      'bn': 'বাকি যোগ করুন',
    },
    'transaction_history_ledger': {
      'en': 'Transaction History (Ledger)',
      'bn': 'লেনদেনের ইতিহাস (Ledger)',
    },
    'no_transaction_history': {
      'en': 'No transaction history.',
      'bn': 'কোনো লেনদেনের ইতিহাস নেই।',
    },
    'jama_given': {
      'en': 'Payment Given',
      'bn': 'জমা দেওয়া হয়েছে',
    },
    'baki_taken': {
      'en': 'Due Taken',
      'bn': 'বাকি নেওয়া হয়েছে',
    },
    'change_date': {
      'en': 'Change Date',
      'bn': 'তারিখ পরিবর্তন',
    },
    'not_logged_in': {
      'en': 'Not logged in',
      'bn': 'লগইন করা নেই',
    },
    'no_sales_found': {
      'en': 'No sales records found',
      'bn': 'কোনো বিক্রির হিসাব পাওয়া যায়নি',
    },
    'no_sales_in_range': {
      'en': 'No sales in this range',
      'bn': 'এই সময়ের মধ্যে কোনো বিক্রি নেই',
    },
    'sale_amount': {
      'en': 'Sale Amount',
      'bn': 'বিক্রি পরিমাণ',
    },
    'profit': {
      'en': 'Profit',
      'bn': 'লাভ',
    },
    'qty_price': {
      'en': 'Qty: @qty | Unit Price: Tk @price',
      'bn': 'পরিমাণ: @qty | একক মূল্য: Tk @price',
    },
    'due_reminder_msg': {
      'en': 'Dear @name, your current due amount at "@shop" is ৳@due. Please arrange for payment. Thank you.',
      'bn': 'প্রিয় @name, "@shop" এ আপনার বর্তমান বাকির পরিমাণ ৳@due। দ্রুত পরিশোধ করার জন্য অনুরোধ করা হচ্ছে। ধন্যবাদ।',
    },
    'staff_login_success': {
      'en': 'Staff login successful!',
      'bn': 'স্টাফ লগইন সফল হয়েছে!',
    },
    'invalid_staff_login': {
      'en': 'Invalid Shop ID, Username or Password!',
      'bn': 'ভুল শপ আইডি, ইউজারনেম অথবা পাসওয়ার্ড!',
    },
    'shop_staff_portal': {
      'en': 'Shop Staff Portal',
      'bn': 'দোকানের স্টাফ পোর্টাল',
    },
    'shop_id_admin': {
      'en': 'Shop ID (Admin UID)',
      'bn': 'দোকানের আইডি (Admin UID)',
    },
    'shop_id_required': {
      'en': 'Enter Shop ID',
      'bn': 'দোকানের আইডি দিন',
    },
    'optional': {
      'en': 'Optional',
      'bn': 'ঐচ্ছিক',
    },
    'biometric_not_supported': {
      'en': 'Biometric not supported on this device!',
      'bn': 'এই ডিভাইসে ফিঙ্গারপ্রিন্ট সুবিধা সমর্থিত নয়!',
    },
    'biometric_reason': {
      'en': 'Scan your fingerprint to enter Dashboard',
      'bn': 'ড্যাশবোর্ডে প্রবেশ করতে আপনার ফিঙ্গারপ্রিন্ট দিন',
    },
    'mobile_required': {
      'en': 'Please enter mobile number',
      'bn': 'মোবাইল নম্বর লিখুন',
    },
    'select_image_source': {
      'en': 'Select Image Source',
      'bn': 'ছবির উৎস সিলেক্ট করুন',
    },
    'take_photo': {
      'en': 'Take Photo',
      'bn': 'ক্যামেরা দিয়ে তুলুন',
    },
    'choose_from_gallery': {
      'en': 'Choose from Gallery',
      'bn': 'গ্যালারি থেকে নিন',
    },
    'scan_barcode': {
      'en': 'Scan Barcode',
      'bn': 'বারকোড স্ক্যান করুন',
    },
    'add_image': {
      'en': 'Add Image',
      'bn': 'ছবি দিন',
    },
    'select_or_type': {
      'en': 'Select or Type',
      'bn': 'সিলেক্ট বা টাইপ করুন',
    },
    'unit': {
      'en': 'Unit',
      'bn': 'ইউনিট',
    },
    'unit_hint': {
      'en': 'Pcs/Kg',
      'bn': 'Pcs/Kg',
    },
    'type': {
      'en': 'Type',
      'bn': 'টাইপ',
    },
    'percent': {
      'en': 'Percent',
      'bn': 'পারসেন্ট',
    },
    'taka': {
      'en': 'Taka',
      'bn': 'টাকা',
    },
    'product_name_required': {
      'en': 'Please enter product name!',
      'bn': 'অনুগ্রহ করে পণ্যের নাম লিখুন!',
    },
    'duplicate_barcode_msg': {
      'en': 'This barcode is already used in another product!',
      'bn': 'এই বারকোডটি ইতিমধ্যে অন্য একটি পণ্যে ব্যবহার করা হয়েছে!',
    },
    'product_saved_msg': {
      'en': 'Product saved successfully!',
      'bn': 'পণ্য সফলভাবে সংরক্ষিত হয়েছে!',
    },
    'error_msg': {
      'en': 'An error occurred: @error',
      'bn': 'ত্রুটি দেখা দিয়েছে: @error',
    },
    'enter_app_pin': {
      'en': 'Enter your App PIN',
      'bn': 'আপনার পিন কোড লিখুন',
    },
    'product_deleted_msg': {
      'en': 'Product deleted successfully!',
      'bn': 'পণ্য সফলভাবে মুছে ফেলা হয়েছে!',
    },
    'invalid_pin_msg': {
      'en': 'Invalid PIN Code!',
      'bn': 'ভুল পিন কোড!',
    },
    'category_delete_pin_msg': {
      'en': 'Enter PIN to delete category',
      'bn': 'ক্যাটাগরি মুছতে পিন লিখুন',
    },
    'category_deleted_msg': {
      'en': 'Category deleted successfully!',
      'bn': 'ক্যাটাগরি সফলভাবে মুছে ফেলা হয়েছে!',
    },
    'no_access_msg': {
      'en': 'Sorry! You do not have access to manage products.',
      'bn': 'দুঃখিত! এই পেজটি বা পণ্য ম্যানেজ করার এক্সেস আপনার অ্যাকাউন্টে নেই।',
    },
    'no_product_found_cat': {
      'en': 'No product found in this category.',
      'bn': 'এই ক্যাটাগরিতে কোনো পণ্য পাওয়া যায়নি।',
    },
    'none': {
      'en': 'None',
      'bn': 'নেই',
    },
    'others': {
      'en': 'Others',
      'bn': 'অন্যান্য',
    },
    'cat_grocery': {
      'en': 'Grocery',
      'bn': 'মুদি মাল',
    },
    'cat_beverage': {
      'en': 'Beverage',
      'bn': 'পানীয়',
    },
    'cat_biscuits': {
      'en': 'Biscuits & Snacks',
      'bn': 'বিস্কুট ও স্ন্যাকস',
    },
    'cat_cosmetics': {
      'en': 'Cosmetics & Toiletries',
      'bn': 'কসমেটিকস ও টয়লেট্রিজ',
    },
    'cat_baby': {
      'en': 'Baby Food & Diaper',
      'bn': 'বেবি ফুড ও ডায়পার',
    },
    'cat_vegetables': {
      'en': 'Vegetables',
      'bn': 'কাঁচা বাজার',
    },
    'cat_frozen': {
      'en': 'Frozen Food',
      'bn': 'ফ্রোজেন ফুড',
    },
    'cat_stationery': {
      'en': 'Stationery',
      'bn': 'স্টেশনারি',
    },
    'cat_household': {
      'en': 'Household',
      'bn': 'ঘরের জিনিস',
    },
    'open_app_fingerprint': {
      'en': 'Scan fingerprint to open app',
      'bn': 'অ্যাপটি খুলতে ফিঙ্গারপ্রিন্ট দিন',
    },
    'pin_length_msg': {
      'en': 'PIN must be 4 digits!',
      'bn': 'অবশ্যই ৪ সংখ্যার পিন হতে হবে!',
    },
    'pin_set_msg': {
      'en': 'PIN set successfully!',
      'bn': 'পিন সফলভাবে সেট হয়েছে!',
    },
    'enable_fingerprint': {
      'en': 'Enable Fingerprint',
      'bn': 'ফিঙ্গারপ্রিন্ট চালু করুন',
    },
    'fingerprint_security_msg': {
      'en': 'Enter your 4-digit PIN for security:',
      'bn': 'নিরাপত্তার জন্য আপনার ৪ ডিজিটের পিনটি লিখুন:',
    },
    'four_digit_pin': {
      'en': '4 Digit PIN',
      'bn': '৪ ডিজিটের পিন',
    },
    'fingerprint_enabled_msg': {
      'en': 'Fingerprint unlock enabled!',
      'bn': 'ফিঙ্গারপ্রিন্ট আনলক চালু হয়েছে!',
    },
    'wrong_pin_short': {
      'en': 'Wrong PIN!',
      'bn': 'ভুল পিন!',
    },
    'set_new_pin': {
      'en': 'Set New 4-Digit PIN',
      'bn': 'নতুন ৪ ডিজিটের পিন সেট করুন',
    },
    'unlock_with_pin': {
      'en': 'Unlock with PIN',
      'bn': 'পিন দিয়ে আনলক করুন',
    },
    'save_pin_enter_app': {
      'en': 'Save PIN & Enter App',
      'bn': 'পিন সেভ করে অ্যাপে ঢুকুন',
    },
    'unlock': {
      'en': 'Unlock',
      'bn': 'আনলক করুন',
    },
    'unlock_with_fingerprint': {
      'en': 'Unlock with Fingerprint',
      'bn': 'ফিঙ্গারপ্রিন্ট দিয়ে আনলক',
    },
    'address_label': {
      'en': 'Address',
      'bn': 'ঠিকানা',
    },
    'name_required_msg': {
      'en': 'Customer name is required!',
      'bn': 'কাস্টমারের নাম আবশ্যক!',
    },
    'customer_added_msg': {
      'en': 'Customer added successfully!',
      'bn': 'কাস্টমার সফলভাবে যোগ করা হয়েছে!',
    },
    'edit_customer_title': {
      'en': 'Edit Customer Info',
      'bn': 'কাস্টমার তথ্য এডিট করুন',
    },
    'enter_pin_to_confirm': {
      'en': 'Enter PIN to confirm edit',
      'bn': 'এডিট কনফার্ম করতে অ্যাপের পিন দিন',
    },
    'please_enter_pin': {
      'en': 'Please enter PIN!',
      'bn': 'দয়া করে পিন লিখুন!',
    },
    'customer_updated_msg': {
      'en': 'Customer info updated successfully!',
      'bn': 'কাস্টমার তথ্য সফলভাবে আপডেট হয়েছে!',
    },
    'delete_customer_msg': {
      'en': 'Enter your login PIN to delete customer:',
      'bn': 'কাস্টমার ডিলিট করতে আপনার অ্যাপের লগইন পিন প্রদান করুন:',
    },
    'login_pin': {
      'en': 'Login PIN',
      'bn': 'লগইন পিন',
    },
    'customer_deleted_success': {
      'en': 'Customer deleted successfully!',
      'bn': 'কাস্টমার সফলভাবে ডিলিট করা হয়েছে!',
    },
    'new_due_sale': {
      'en': 'New Due (Sale)',
      'bn': 'নতুন বাকি (মাল বিক্রি)',
    },
    'jama_amount_tk': {
      'en': 'Collection Amount (৳)',
      'bn': 'জমার পরিমাণ (৳)',
    },
    'total_product_price_tk': {
      'en': 'Total Product Price (৳)',
      'bn': 'মোট পণ্যের দাম (৳)',
    },
    'cash_paid_if_any': {
      'en': 'Cash Paid (if any)',
      'bn': 'নগদ পরিশোধ (যদি থাকে)',
    },
    'memo_no_desc': {
      'en': 'Memo No. or Description',
      'bn': 'মেমো নম্বর বা বিবরণ',
    },
    'transaction_saved_msg': {
      'en': 'Transaction saved successfully!',
      'bn': 'লেনদেন সফলভাবে সংরক্ষিত হয়েছে!',
    },
    'select_report_range': {
      'en': 'Select Report Date Range',
      'bn': 'রিপোর্টের সময়সীমা সিলেক্ট করুন',
    },
    'start_date': {
      'en': 'Start Date',
      'bn': 'শুরুর তারিখ',
    },
    'end_date': {
      'en': 'End Date',
      'bn': 'শেষের তারিখ',
    },
    'download_share_pdf': {
      'en': 'Download/Share PDF',
      'bn': 'পিডিএফ ডাউনলোড/শেয়ার',
    },
    'select_date_calendar': {
      'en': 'Calendar: Select Date',
      'bn': 'ক্যালেন্ডার: তারিখ সিলেক্ট করুন',
    },
    'reset_filter': {
      'en': 'Reset Filter',
      'bn': 'ফিল্টার রিসেট করুন',
    },
    'baki_of_date': {
      'en': 'Due of @date',
      'bn': '@date তারিখের বাকি',
    },
    'jama': {
      'en': 'Collection',
      'bn': 'জমা',
    },
    'customer': {
      'en': 'Customer',
      'bn': 'কাস্টমার',
    },
    'tap_to_view_profile': {
      'en': 'Tap to view profile',
      'bn': 'প্রোফাইল দেখতে চাপুন',
    },
    'report_pdf': {
      'en': 'Report (PDF)',
      'bn': 'রিপোর্ট (PDF)',
    },
    'settled_due': {
      'en': 'Settled (Due)',
      'bn': 'নিষ্পত্তি করা (বকেয়া)',
    },
    'message': {
      'en': 'Message',
      'bn': 'বার্তা',
    },
    'reminder': {
      'en': 'Reminder',
      'bn': 'রিমাইন্ডার',
    },
    'invitation': {
      'en': 'Invitation',
      'bn': 'আমন্ত্রণ',
    },
    'search_note_hint': {
      'en': 'Search by note or description...',
      'bn': 'নোট বা বিবরণ দিয়ে খুঁজুন...',
    },
    'no_transaction_found': {
      'en': 'No transactions found!',
      'bn': 'কোনো লেনদেন পাওয়া যায়নি!',
    },
    'give_due': {
      'en': 'Give Due (-)',
      'bn': 'বাকি দিন (-)',
    },
    'take_jama': {
      'en': 'Take Collection (+)',
      'bn': 'জমা নিন (+)',
    },
    'edit_sale_history': {
      'en': 'Edit Sale Record',
      'bn': 'বিক্রির হিসাব এডিট করুন',
    },
    'new_total_sale_tk': {
      'en': 'New Total Sale (Tk)',
      'bn': 'নতুন মোট বিক্রির পরিমাণ (টাকা)',
    },
    'new_profit_tk': {
      'en': 'New Profit (Tk)',
      'bn': 'নতুন লাভের পরিমাণ (টাকা)',
    },
    'sale_updated_msg': {
      'en': 'Sale record updated successfully!',
      'bn': 'বিক্রির হিসাব সফলভাবে আপডেট করা হয়েছে!',
    },
    'expense_added_msg': {
      'en': 'Expense added successfully!',
      'bn': 'খরচ সফলভাবে যোগ করা হয়েছে!',
    },
    'general_expense': {
      'en': 'General Expense',
      'bn': 'সাধারণ খরচ',
    },
    'expense_amount_tk': {
      'en': 'Expense Amount (Tk)',
      'bn': 'খরচের পরিমাণ (টাকা)',
    },
    'expense_category_hint': {
      'en': 'Description (e.g. Electricity, Tea)',
      'bn': 'খাতের বিবরণ / নোট (যেমন: বিদ্যুৎ বিল, চা বিল)',
    },
    'add_new_employee': {
      'en': 'Add New Employee',
      'bn': 'নতুন কর্মচারী যোগ করুন',
    },
    'edit_employee_info': {
      'en': 'Edit Employee Info',
      'bn': 'কর্মচারীর তথ্য এডিট করুন',
    },
    'designation': {
      'en': 'Designation',
      'bn': 'পদবি',
    },
    'designation_hint': {
      'en': 'e.g. Manager / Salesman',
      'bn': 'যেমন: ম্যানেজার / সেলসম্যান',
    },
    'monthly_salary_tk': {
      'en': 'Monthly Salary (Tk)',
      'bn': 'মাসিক বেতন (টাকা)',
    },
    'info_saved_msg': {
      'en': 'Information saved successfully!',
      'bn': 'তথ্য সফলভাবে সংরক্ষণ করা হয়েছে!',
    },
    'salary_payment_title': {
      'en': 'Salary Payment',
      'bn': 'বেতন প্রদান',
    },
    'payment_amount_tk': {
      'en': 'Payment Amount (Tk)',
      'bn': 'প্রদানের পরিমাণ (টাকা)',
    },
    'salary_paid_msg': {
      'en': 'Salary paid successfully!',
      'bn': 'বেতন সফলভাবে পরিশোধ করা হয়েছে!',
    },
    'salary_payment_confirm': {
      'en': 'Confirm Payment',
      'bn': 'পেমেন্ট কনফার্ম',
    },
    'no_payment_record': {
      'en': 'No payment records found',
      'bn': 'কোনো পেমেন্ট রেকর্ড নেই',
    },
    'salary_payment_history': {
      'en': 'Salary Payment History:',
      'bn': 'বেতন প্রদানের ইতিহাস:',
    },
    'download_pdf': {
      'en': 'Download PDF',
      'bn': 'পিডিএফ ডাউনলোড',
    },
    'provided_by': {
      'en': 'Provided by',
      'bn': 'প্রদানকারী',
    },
    'net_balance': {
      'en': 'Net Balance',
      'bn': 'নিট ব্যালেন্স',
    },
    'daily_breakdown': {
      'en': 'Daily Breakdown',
      'bn': 'দৈনিক হিসাব বিবরণী',
    },
    'shop_expenses_salaries': {
      'en': 'Shop Expenses & Salaries:',
      'bn': 'দোকানের খরচ ও বেতনসমূহ:',
    },
    'staff_user': {
      'en': 'Staff / User',
      'bn': 'স্টাফ / ইউজার',
    },
    'my_shop': {
      'en': 'My Shop',
      'bn': 'আমার দোকান',
    },
    'otp_sent': {
      'en': 'OTP Sent Successfully!',
      'bn': 'OTP সফলভাবে পাঠানো হয়েছে!',
    },
    'enter_otp': {
      'en': 'Enter 6-Digit OTP',
      'bn': '৬ ডিজিটের OTP কোডটি দিন',
    },
    'verify_otp': {
      'en': 'Verify OTP',
      'bn': 'ভেরিফাই করুন',
    },
    'invalid_otp': {
      'en': 'Invalid OTP Code!',
      'bn': 'ভুল OTP কোড!',
    },
    'otp_error': {
      'en': 'Failed to send OTP. Please try again.',
      'bn': 'OTP পাঠাতে সমস্যা হয়েছে। আবার চেষ্টা করুন।',
    },
    'verify_email_title': {
      'en': 'Verify Your Email',
      'bn': 'ইমেইল ভেরিফাই করুন',
    },
    'verify_email_msg': {
      'en': 'A verification link has been sent to your email. Please click the link and then press "Verified" below.',
      'bn': 'আপনার ইমেইলে একটি ভেরিফিকেশন লিংক পাঠানো হয়েছে। দয়া করে লিংকে ক্লিক করুন এবং তারপর নিচের "ভেরিফাই করেছি" বাটনে চাপুন।',
    },
    'verified_btn': {
      'en': 'I have verified',
      'bn': 'ভেরিফাই করেছি',
    },
    'resend_link': {
      'en': 'Resend Link',
      'bn': 'আবার লিংক পাঠান',
    },
    'email_not_verified': {
      'en': 'Email not verified yet. Please check your inbox/spam.',
      'bn': 'ইমেইল এখনো ভেরিফাই করা হয়নি। আপনার ইনবক্স বা স্প্যাম চেক করুন।',
    },
    'spam_instruction': {
      'en': 'If you don\'t find the email, please check your Spam folder and mark it as "Not Spam". This will ensure future emails arrive in your Inbox.',
      'bn': 'যদি ইমেইল খুঁজে না পান, তবে দয়া করে স্প্যাম ফোল্ডার চেক করুন এবং সেটিকে "Not Spam" হিসেবে মার্ক করুন। এটি করলে পরের বার থেকে ইমেইল সরাসরি ইনবক্সে আসবে।',
    },
    'verification_sent_to': {
      'en': 'Verification link sent to:',
      'bn': 'ভেরিফিকেশন লিঙ্ক পাঠানো হয়েছে:',
    },
    'low_stock_alert': {
      'en': 'Low Stock Alert!',
      'bn': 'লো-স্টক সতর্কতা!',
    },
    'low_stock_msg': {
      'en': '@count products are running low in stock.',
      'bn': '@countটি পণ্যের স্টক কমে গেছে।',
    },
    'low_stock_limit': {
      'en': 'Low Stock Limit',
      'bn': 'লো-স্টক লিমিট',
    },
    'bulk_sms': {
      'en': 'Bulk Message',
      'bn': 'একসাথে মেসেজ পাঠান',
    },
    'marketing': {
      'en': 'Marketing',
      'bn': 'মার্কেটিং',
    },
    'select_customers': {
      'en': 'Select Customers',
      'bn': 'কাস্টমার সিলেক্ট করুন',
    },
    'online': {
      'en': 'Online',
      'bn': 'অনলাইন',
    },
    'offline': {
      'en': 'Offline',
      'bn': 'অফলাইন',
    },
    'forgot_pin': {
      'en': 'Forgot PIN?',
      'bn': 'পিন ভুলে গেছেন?',
    },
    'enter_phone_recovery': {
      'en': 'Enter your registered mobile number',
      'bn': 'আপনার রেজিস্টার্ড মোবাইল নম্বরটি দিন',
    },
    'reset_link_sent': {
      'en': 'Password reset link sent to your email.',
      'bn': 'পাসওয়ার্ড রিসেট লিংক আপনার ইমেইলে পাঠানো হয়েছে।',
    },
    'login_with_password': {
      'en': 'Login with Password',
      'bn': 'পাসওয়ার্ড দিয়ে লগইন করুন',
    },
    'set_new_pin_title': {
      'en': 'Set New 4-Digit PIN',
      'bn': 'নতুন ৪ ডিজিটের পিন সেট করুন',
    },
    'enter_password': {
      'en': 'Enter password',
      'bn': 'পাসওয়ার্ড দিন',
    },
    'recovery_instructions': {
      'en': 'A reset link has been sent to your email. Click the link to set a new password, then come back here.',
      'bn': 'আপনার ইমেইলে একটি লিঙ্ক পাঠানো হয়েছে। লিঙ্কে ক্লিক করে নতুন একটি পাসওয়ার্ড সেট করুন, তারপর এখানে ফিরে আসুন।',
    },
    'password_set_done': {
      'en': 'I have set a new password',
      'bn': 'আমি নতুন পাসওয়ার্ড সেট করেছি',
    },
    'currency_symbol': {
      'en': 'Tk',
      'bn': '৳',
    },
    'no_product_found': {
      'en': 'No product found',
      'bn': 'কোনো পণ্য পাওয়া যায়নি',
    },
    'no_product_in_cart': {
      'en': 'No products added to cart',
      'bn': 'কোনো পণ্য কার্টে যোগ করা হয়নি',
    },
    'payment_type_label': {
      'en': 'Payment Type:',
      'bn': 'পেমেন্ট টাইপ:',
    },
    'discount_label': {
      'en': 'Discount:',
      'bn': 'ডিসকাউন্ট:',
    },
    'shop_id_label': {
      'en': 'Shop ID / UID:',
      'bn': 'দোকানের আইডি / UID:',
    },
    'copy_id_msg': {
      'en': 'ID copied successfully!',
      'bn': 'আইডি সফলভাবে কপি করা হয়েছে!',
    },
    'copy_id_tooltip': {
      'en': 'Copy ID',
      'bn': 'আইডি কপি করুন',
    },
    'specific_date': {
      'en': 'Specific Date',
      'bn': 'নির্ধারিত তারিখ',
    },
    'date_range': {
      'en': 'Date Range',
      'bn': 'তারিখের রেঞ্জ',
    },
    'mobile_short': {
      'en': 'Mobile',
      'bn': 'মোবাইল',
    },
    'address_short': {
      'en': 'Address',
      'bn': 'ঠিকানা',
    },
    'added_by_label': {
      'en': 'Added by:',
      'bn': 'সংযুক্ত করেছেন:',
    },
    'username_label': {
      'en': 'Username:',
      'bn': 'ইউজারনেম:',
    },
    'access_label': {
      'en': 'Access:',
      'bn': 'অ্যাক্সেস:',
    },
    'selected': {
      'en': 'Selected',
      'bn': 'সিলেক্ট করা হয়েছে',
    },
    'person_count': {
      'en': 'person',
      'bn': 'জন',
    },
    'write_message_hint': {
      'en': 'Write message...',
      'bn': 'মেসেজ লিখুন...',
    },
    'send_sms_btn': {
      'en': 'Send SMS',
      'bn': 'SMS পাঠান',
    },
    'msg_process_started': {
      'en': 'Message sending process started...',
      'bn': 'মেসেজ পাঠানোর প্রক্রিয়া শুরু হয়েছে...',
    },
    'security_confirm_title': {
      'en': 'Security Confirmation',
      'bn': 'নিরাপত্তা নিশ্চিতকরণ',
    },
    'security_confirm_msg': {
      'en': 'Enter your 4-digit App PIN to save changes:',
      'bn': 'পরিবর্তনগুলো সংরক্ষণ করতে আপনার অ্যাপের ৪ ডিজিটের পিন কোড দিন:',
    },
    'app_pin_label': {
      'en': 'App PIN',
      'bn': 'অ্যাপ পিন',
    },
    'wrong_pin_msg': {
      'en': 'Wrong PIN! Please try again.',
      'bn': 'ভুল পিন দিয়েছেন! আবার চেষ্টা করুন।',
    },
    'confirm_btn': {
      'en': 'Confirm',
      'bn': 'কনফার্ম করুন',
    },
    'change_pin_title': {
      'en': 'Change Security PIN',
      'bn': 'সিকিউরিটি পিন পরিবর্তন',
    },
    'old_pin': {
      'en': 'Old PIN',
      'bn': 'পুরাতন পিন',
    },
    'new_pin_4_digit': {
      'en': 'New 4-Digit PIN',
      'bn': 'নতুন ৪ ডিজিটের পিন',
    },
    'pin_changed_msg': {
      'en': 'PIN changed successfully!',
      'bn': 'পিন সফলভাবে পরিবর্তন হয়েছে!',
    },
    'pin_must_4_digit': {
      'en': 'PIN must be 4 digits!',
      'bn': 'নতুন পিন অবশ্যই ৪ ডিজিট হতে হবে!',
    },
    'old_pin_wrong': {
      'en': 'Old PIN is wrong!',
      'bn': 'পুরাতন পিন ভুল হয়েছে!',
    },
    'save_settings_btn': {
      'en': 'Save Settings',
      'bn': 'সেভ করুন',
    },
    'settings_saved_msg': {
      'en': 'Settings saved successfully!',
      'bn': 'সেটিংস সফলভাবে সেভ হয়েছে!',
    },
    'error_occurred': {
      'en': 'An error occurred:',
      'bn': 'সমস্যা হয়েছে:',
    },
    'monthly_report_title': {
      'en': 'Monthly Report:',
      'bn': 'মাসিক রিপোর্ট:',
    },
    'sales_list_title': {
      'en': 'Sales list for this month:',
      'bn': 'এই মাসের সকল বিক্রির তালিকা:',
    },
    'no_sales_month': {
      'en': 'No sales records this month',
      'bn': 'এই মাসে কোনো বিক্রির রেকর্ড নেই',
    },
    'date_label': {
      'en': 'Date:',
      'bn': 'তারিখ:',
    },
    'user_staff_label': {
      'en': 'User/Staff:',
      'bn': 'ইউজার/স্টাফ:',
    },
    'no_employee_found': {
      'en': 'No employees added',
      'bn': 'কোনো কর্মচারী যোগ করা হয়নি',
    },
    'salary_label': {
      'en': 'Salary:',
      'bn': 'বেতন:',
    },
    'edit_pos_tooltip': {
      'en': 'Edit entry (Product Return)',
      'bn': 'এডিট হিসাব (পণ্য ফেরত)',
    },
    'pos_sale_label': {
      'en': 'POS Sale',
      'bn': 'বিক্রি',
    },
    'user_approval': {
      'en': 'User Approval',
      'bn': 'ইউজার অনুমোদন',
    },
    'pending_users': {
      'en': 'Pending Users',
      'bn': 'অপেক্ষমাণ ইউজার',
    },
    'approve_btn': {
      'en': 'Approve',
      'bn': 'অনুমোদন করুন',
    },
    'no_pending_users': {
      'en': 'No pending users found.',
      'bn': 'কোনো অপেক্ষমাণ ইউজার পাওয়া যায়নি।',
    },
    'user_approved_msg': {
      'en': 'User approved successfully!',
      'bn': 'ইউজার সফলভাবে অনুমোদিত হয়েছে!',
    },
    'pending': {
      'en': 'Pending',
      'bn': 'পেন্ডিং',
    },
    'approved': {
      'en': 'Approved',
      'bn': 'অনুমোদিত',
    },
    'verify_pin_to_approve': {
      'en': 'Verify PIN to Approve',
      'bn': 'ইউজার এপ্রুভ করতে পিন দিন',
    },
    'pending_approval_title': {
      'en': 'Account Pending Approval',
      'bn': 'অ্যাকাউন্ট অনুমোদনের অপেক্ষায়',
    },
    'pending_approval_msg': {
      'en': 'Your account is currently pending admin approval. To verify that this is your number, please call or message the admin from your registered number. (WhatsApp message is recommended)',
      'bn': 'আপনার অ্যাকাউন্টটি বর্তমানে অনুমোদনের অপেক্ষায় আছে। এটি যে আপনার নম্বর তা নিশ্চিত করতে অনুগ্রহ করে আপনার রেজিস্টার্ড নম্বর থেকে এডমিনকে কল বা মেসেজ দিন। (হোয়াটসঅ্যাপে মেসেজ দেওয়ার পরামর্শ দেওয়া হচ্ছে)',
    },
    'call_admin': {
      'en': 'Call Admin',
      'bn': 'এডমিনকে কল দিন',
    },
    'whatsapp_admin': {
      'en': 'WhatsApp (Recommended)',
      'bn': 'হোয়াটসঅ্যাপ (পরামর্শিত)',
    },
    'admin_not_approved': {
      'en': 'Account not approved yet. Please contact admin.',
      'bn': 'অ্যাকাউন্ট এখনো অনুমোদন করা হয়নি। এডমিনের সাথে যোগাযোগ করুন।',
    },
    'premium_feature': {
      'en': 'Premium Feature',
      'bn': 'প্রিমিয়াম ফিচার',
    },
    'subscription_required': {
      'en': 'Subscription required to use this feature.',
      'bn': 'এই ফিচারটি ব্যবহার করতে সাবস্ক্রিপশন প্রয়োজন।',
    },
    'buy_premium': {
      'en': 'Get Premium',
      'bn': 'প্রিমিয়াম নিন',
    },
    'watch_ad_to_unlock': {
      'en': 'Watch an ad to unlock this receipt',
      'bn': 'রিসিট ডাউনলোড করতে একটি বিজ্ঞাপন দেখুন',
    },
    'watch_ad': {
      'en': 'Watch Ad',
      'bn': 'বিজ্ঞাপন দেখুন',
    },
    'trial_remaining': {
      'en': 'Free trial ends in @days days.',
      'bn': 'ফ্রি ট্রায়াল @days দিন পর শেষ হবে।',
    },
    'plan_3_month': {
      'en': '3 Months - 300 Tk',
      'bn': '৩ মাস - ৩০০ টাকা',
    },
    'plan_6_month': {
      'en': '6 Months - 500 Tk',
      'bn': '৬ মাস - ৫০০ টাকা',
    },
    'plan_12_month': {
      'en': '12 Months - 1000 Tk',
      'bn': '১২ মাস - ১০০০ টাকা',
    },
    'payment_instructions': {
      'en': 'Send money to 01828424364 (bKash/Nagad) and send screenshot to WhatsApp.',
      'bn': '০১৮২৮৪২৪৩৬৪ (বিকাশ/নগদ) নম্বরে টাকা পাঠিয়ে হোয়াটসঅ্যাপে স্ক্রিনশট দিন।',
    },
    'whatsapp_us': {
      'en': 'Message on WhatsApp',
      'bn': 'হোয়াটসঅ্যাপে জানান',
    },
    'subscriptions': {
      'en': 'Subscriptions',
      'bn': 'সাবস্ক্রিপশন',
    },
    'enter_txid': {
      'en': 'Enter Transaction ID (TxID)',
      'bn': 'ট্রানজেকশন আইডি (TxID) দিন',
    },
    'submit_payment': {
      'en': 'Submit Payment',
      'bn': 'পেমেন্ট জমা দিন',
    },
    'payment_submitted_msg': {
      'en': 'Payment submitted! Please wait for admin approval.',
      'bn': 'পেমেন্ট জমা দেওয়া হয়েছে! এডমিনের অনুমোদনের জন্য অপেক্ষা করুন।',
    },
    'confirm_payment': {
      'en': 'Confirm Payment',
      'bn': 'পেমেন্ট নিশ্চিত করুন',
    },
    'select_plan_msg': {
      'en': 'Please select a plan first.',
      'bn': 'দয়া করে আগে একটি প্ল্যান সিলেক্ট করুন।',
    },
    'txid_required': {
      'en': 'Transaction ID is required!',
      'bn': 'ট্রানজেকশন আইডি দেওয়া আবশ্যক!',
    },
    'subscription_receipt': {
      'en': 'Subscription Receipt',
      'bn': 'সাবস্ক্রিপশন রিসিট',
    },
    'send_receipt_msg': {
      'en': 'Please send your plan receipt to WhatsApp.',
      'bn': 'আপনার প্ল্যান রিসিটটি হোয়াটসঅ্যাপে পাঠিয়ে দিন।',
    },
    'plan_details': {
      'en': 'Plan Details',
      'bn': 'প্ল্যান ডিটেইলস',
    },
    'transaction_id': {
      'en': 'Transaction ID',
      'bn': 'ট্রানজেকশন আইডি',
    },
  };

  static String get(String key) {
    return _localizedValues[key]?[currentLanguage] ?? key;
  }

  static Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    currentLanguage = prefs.getString('language_code') ?? 'bn';
  }

  static Future<void> saveLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', langCode);
    currentLanguage = langCode;
  }
}
