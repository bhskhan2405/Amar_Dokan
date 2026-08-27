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
      'bn': 'ভাষা পরিবর্তন করুন',
    },
    'bonus': {
      'en': 'Bonus',
      'bn': 'বোনাস',
    },
    'bonus_tk': {
      'en': 'Bonus (Tk)',
      'bn': 'বোনাস (টাকা)',
    },
    'pay_bonus': {
      'en': 'Pay Bonus',
      'bn': 'বোনাস দিন',
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
      'bn': 'বারকোড',
    },
    'discount': {
      'en': 'Discount (%)',
      'bn': 'ডিসকাউন্ট (%)',
    },
    'save': {
      'en': 'Save',
      'bn': 'সেভ করুন',
    },
    'update': {
      'en': 'Update',
      'bn': 'আপডেট করুন',
    },
    'delete': {
      'en': 'Delete',
      'bn': 'ডিলিট করুন',
    },
    'cancel': {
      'en': 'Cancel',
      'bn': 'বাতিল',
    },
    'search_product': {
      'en': 'Search Product...',
      'bn': 'পণ্য খুঁজুন...',
    },
    'no_product_found': {
      'en': 'No product found!',
      'bn': 'কোনো পণ্য পাওয়া যায়নি!',
    },
    'low_stock': {
      'en': 'Low Stock',
      'bn': 'স্টক কম',
    },
    'low_stock_limit': {
      'en': 'Low Stock Limit',
      'bn': 'লো স্টক লিমিট',
    },
    'product_added_msg': {
      'en': 'Product added successfully!',
      'bn': 'পণ্যটি সফলভাবে যোগ করা হয়েছে!',
    },
    'product_updated_msg': {
      'en': 'Product updated successfully!',
      'bn': 'পণ্যটি সফলভাবে আপডেট করা হয়েছে!',
    },
    'product_deleted_msg': {
      'en': 'Product deleted successfully!',
      'bn': 'পণ্যটি সফলভাবে মুছে ফেলা হয়েছে!',
    },

    // POS Screen
    'cart': {
      'en': 'Cart',
      'bn': 'কার্ট',
    },
    'total': {
      'en': 'Total',
      'bn': 'মোট',
    },
    'subtotal': {
      'en': 'Subtotal',
      'bn': 'উপ-মোট',
    },
    'total_payable': {
      'en': 'Total Payable',
      'bn': 'মোট পরিশোধযোগ্য',
    },
    'cash_received': {
      'en': 'Cash Received',
      'bn': 'নগদ গ্রহণ',
    },
    'change_amount': {
      'en': 'Change Amount',
      'bn': 'বাকি ফেরত',
    },
    'complete_sale': {
      'en': 'Complete Sale',
      'bn': 'বিক্রি সম্পন্ন করুন',
    },
    'clear_cart': {
      'en': 'Clear Cart',
      'bn': 'কার্ট মুছুন',
    },
    'select_customer': {
      'en': 'Select Customer',
      'bn': 'কাস্টমার নির্বাচন করুন',
    },
    'add_customer': {
      'en': 'Add Customer',
      'bn': 'কাস্টমার যোগ করুন',
    },
    'walk_in_customer': {
      'en': 'Walk-in Customer',
      'bn': 'সাধারণ কাস্টমার',
    },
    'sale_success_msg': {
      'en': 'Sale completed successfully!',
      'bn': 'বিক্রি সফলভাবে সম্পন্ন হয়েছে!',
    },
    'print_receipt': {
      'en': 'Print Receipt',
      'bn': 'রিসিট প্রিন্ট করুন',
    },

    // Hisab Kitab (Accounts)
    'daily_report': {
      'en': 'Daily Report',
      'bn': 'দৈনিক হিসাব',
    },
    'monthly_report': {
      'en': 'Monthly Report',
      'bn': 'মাসিক হিসাব',
    },
    'total_sales': {
      'en': 'Total Sales',
      'bn': 'মোট বিক্রি',
    },
    'total_profit': {
      'en': 'Total Profit',
      'bn': 'মোট লাভ',
    },
    'total_expense': {
      'en': 'Total Expense',
      'bn': 'মোট খরচ',
    },
    'add_expense': {
      'en': 'Add Expense',
      'bn': 'খরচ যোগ করুন',
    },
    'expense_amount_tk': {
      'en': 'Expense Amount (Tk)',
      'bn': 'খরচের পরিমাণ (টাকা)',
    },
    'expense_category_hint': {
      'en': 'Reason / Note (e.g. Electricity Bill)',
      'bn': 'খরচের কারণ / নোট (যেমন- বিদ্যুৎ বিল)',
    },
    'expense_added_msg': {
      'en': 'Expense added successfully!',
      'bn': 'খরচ সফলভাবে যোগ করা হয়েছে!',
    },

    // Customer Screen
    'customer_name': {
      'en': 'Customer Name',
      'bn': 'কাস্টমারের নাম',
    },
    'phone_number': {
      'en': 'Phone Number',
      'bn': 'ফোন নম্বর',
    },
    'due_amount': {
      'en': 'Due Amount',
      'bn': 'বাকি পরিমাণ',
    },
    'payment_history': {
      'en': 'Payment History',
      'bn': 'পেমেন্ট ইতিহাস',
    },
    'take_payment': {
      'en': 'Take Payment',
      'bn': 'পেমেন্ট গ্রহণ করুন',
    },
    'customer_added_msg': {
      'en': 'Customer added successfully!',
      'bn': 'কাস্টমার সফলভাবে যোগ করা হয়েছে!',
    },

    // Login/Register
    'login': {
      'en': 'Login',
      'bn': 'লগইন করুন',
    },
    'register': {
      'en': 'Register',
      'bn': 'রেজিস্ট্রেশন করুন',
    },
    'phone_label': {
      'en': 'Phone Number',
      'bn': 'ফোন নম্বর',
    },
    'pin_label': {
      'en': '4-Digit PIN',
      'bn': '৪-ডিজিটের পিন',
    },
    'forgot_pin': {
      'en': 'Forgot PIN?',
      'bn': 'পিন ভুলে গেছেন?',
    },
    'invalid_login_msg': {
      'en': 'Invalid phone or PIN!',
      'bn': 'সঠিক ফোন নম্বর বা পিন দিন!',
    },
    'account_created_msg': {
      'en': 'Account created! Please verify email.',
      'bn': 'অ্যাকাউন্ট তৈরি হয়েছে! ইমেইল ভেরিফাই করুন।',
    },
    'verified_btn': {
      'en': 'Verified Done',
      'bn': 'ভেরিফাই করেছি',
    },
    'resend_link': {
      'en': 'Resend Link',
      'bn': 'লিঙ্ক পুনরায় পাঠান',
    },
    'email_not_verified': {
      'en': 'Email not verified yet!',
      'bn': 'ইমেইল এখনো ভেরিফাই করা হয়নি!',
    },

    // Common
    'confirm': {
      'en': 'Confirm',
      'bn': 'নিশ্চিত করুন',
    },
    'error_occurred': {
      'en': 'Error occurred:',
      'bn': 'একটি সমস্যা হয়েছে:',
    },
    'currency_symbol': {
      'en': 'Tk',
      'bn': '৳',
    },
    'yes': {
      'en': 'Yes',
      'bn': 'হ্যাঁ',
    },
    'no': {
      'en': 'No',
      'bn': 'না',
    },

    // অতিরিক্ত স্ট্রিংগুলো যোগ করা হলো
    'verification_sent_to': {
      'en': 'Verification link sent to:',
      'bn': 'ভেরিফিকেশন লিঙ্ক পাঠানো হয়েছে:',
    },
    'verify_email_title': {
      'en': 'Verify Your Email',
      'bn': 'আপনার ইমেইল ভেরিফাই করুন',
    },
    'verify_email_msg': {
      'en': 'A link has been sent to your email. Click it to verify.',
      'bn': 'আপনার ইমেইলে একটি লিঙ্ক পাঠানো হয়েছে। সেটি ক্লিক করে ভেরিফাই করুন।',
    },
    'spam_instruction': {
      'en': 'If not found, check Spam/Junk folder.',
      'bn': 'না পাওয়া গেলে স্প্যাম (Spam/Junk) ফোল্ডার চেক করুন।',
    },
    'otp_sent': {
      'en': 'Verification email sent!',
      'bn': 'ভেরিফিকেশন ইমেইল পাঠানো হয়েছে!',
    },
    'user_not_found': {
      'en': 'User not found!',
      'bn': 'ইউজার পাওয়া যায়নি!',
    },
    'recovery_instructions': {
      'en': 'Reset instructions sent to your email.',
      'bn': 'পিন রিসেট করার নিয়ম ইমেইলে পাঠানো হয়েছে।',
    },
    'password_set_done': {
      'en': 'Done',
      'bn': 'সম্পন্ন করেছি',
    },

    // Hisab Kitab - Additional
    'general_expense': {
      'en': 'General Expense',
      'bn': 'সাধারণ খরচ',
    },
    'expense_salary': {
      'en': 'Expense & Salary',
      'bn': 'খরচ ও বেতন',
    },
    'shop_expenses_salaries': {
      'en': 'Shop Expenses & Salaries',
      'bn': 'দোকানের খরচ ও বেতন সমূহ',
    },
    'salary': {
      'en': 'Salary',
      'bn': 'বেতন',
    },
    'expense': {
      'en': 'Expense',
      'bn': 'খরচ',
    },
    'added_by': {
      'en': 'Added By',
      'bn': 'সংযোজনকারী',
    },
    'time': {
      'en': 'Time',
      'bn': 'সময়',
    },
    'sales_history': {
      'en': 'Sales History',
      'bn': 'বিক্রয় ইতিহাস',
    },
    'no_record_found': {
      'en': 'No record found!',
      'bn': 'কোনো তথ্য পাওয়া যায়নি!',
    },
    'edit_pos_tooltip': {
      'en': 'Edit this sale',
      'bn': 'বিক্রি এডিট করুন',
    },
    'date_range': {
      'en': 'Date Range',
      'bn': 'নির্দিষ্ট সময়সীমা',
    },
    'specific_date': {
      'en': 'Specific Date',
      'bn': 'নির্দিষ্ট তারিখ',
    },
    'date': {
      'en': 'Date',
      'bn': 'তারিখ',
    },
    'monthly_report_title': {
      'en': 'Monthly Report of',
      'bn': 'মাসিক হিসাব:',
    },
    'sales_list_title': {
      'en': 'List of Sales:',
      'bn': 'বিক্রয় তালিকা:',
    },
    'no_sales_month': {
      'en': 'No sales found for this month.',
      'bn': 'এই মাসে কোনো বিক্রি পাওয়া যায়নি।',
    },
    'date_label': {
      'en': 'Date:',
      'bn': 'তারিখ:',
    },
    'user_staff_label': {
      'en': 'Staff:',
      'bn': 'স্টাফ:',
    },
    'employee': {
      'en': 'Employee',
      'bn': 'কর্মচারী',
    },
    'no_employee_found': {
      'en': 'No employee found.',
      'bn': 'কোনো কর্মচারী পাওয়া যায়নি।',
    },
    'salary_label': {
      'en': 'Salary',
      'bn': 'বেতন',
    },
    'mobile_short': {
      'en': 'Mob',
      'bn': 'মোবাইল',
    },
    'address_short': {
      'en': 'Addr',
      'bn': 'ঠিকানা',
    },
    'added_by_label': {
      'en': 'Added by:',
      'bn': 'যোগ করেছেন:',
    },
    'edit_info': {
      'en': 'Edit Info',
      'bn': 'তথ্য পরিবর্তন',
    },
    'pay_salary': {
      'en': 'Pay Salary',
      'bn': 'বেতন দিন',
    },
    'add_employee': {
      'en': 'Add Staff',
      'bn': 'কর্মচারী যোগ',
    },

    // Staff Edit Dialog
    'add_new_employee': {
      'en': 'Add New Employee',
      'bn': 'নতুন কর্মচারী যোগ করুন',
    },
    'edit_employee_info': {
      'en': 'Edit Employee Info',
      'bn': 'কর্মচারীর তথ্য পরিবর্তন',
    },
    'staff_name': {
      'en': 'Staff Name',
      'bn': 'কর্মচারীর নাম',
    },
    'designation_hint': {
      'en': 'Designation (e.g. Manager)',
      'bn': 'পদবী (যেমন- ম্যানেজার)',
    },
    'monthly_salary_tk': {
      'en': 'Monthly Salary (Tk)',
      'bn': 'মাসিক বেতন (টাকা)',
    },
    'info_saved_msg': {
      'en': 'Information saved successfully!',
      'bn': 'তথ্য সফলভাবে সংরক্ষিত হয়েছে!',
    },

    // Salary Payment Dialog
    'salary_payment_title': {
      'en': 'Pay Salary to',
      'bn': 'বেতন পরিশোধ:',
    },
    'payment_amount_tk': {
      'en': 'Payment Amount (Tk)',
      'bn': 'পরিশোধের পরিমাণ (টাকা)',
    },
    'description_optional': {
      'en': 'Description (Optional)',
      'bn': 'বিবরণ (ঐচ্ছিক)',
    },
    'salary_paid_msg': {
      'en': 'Salary payment recorded!',
      'bn': 'বেতন পরিশোধের হিসাব রাখা হয়েছে!',
    },
    'salary_payment_confirm': {
      'en': 'Confirm Payment',
      'bn': 'পরিশোধ নিশ্চিত করুন',
    },

    // Employee Detail / Payment History
    'designation': {
      'en': 'Designation',
      'bn': 'পদবী',
    },
    'salary_payment_history': {
      'en': 'Salary Payment History',
      'bn': 'বেতন পরিশোধের ইতিহাস',
    },
    'no_payment_record': {
      'en': 'No payment records found.',
      'bn': 'বেতন পরিশোধের কোনো তথ্য পাওয়া যায়নি।',
    },
    'provided_by': {
      'en': 'Provided By',
      'bn': 'প্রদানকারী',
    },
    'download_pdf': {
      'en': 'Download PDF',
      'bn': 'PDF ডাউনলোড',
    },
    'my_shop': {
      'en': 'My Shop',
      'bn': 'আমার দোকান',
    },
    'staff_user': {
      'en': 'Staff User',
      'bn': 'স্টাফ ইউজার',
    },

    // Security PIN Dialog
    'security_pin': {
      'en': 'Security PIN',
      'bn': 'নিরাপত্তা পিন',
    },
    'enter_pin': {
      'en': 'Enter 4-Digit PIN',
      'bn': '৪-ডিজিটের পিন দিন',
    },
    'invalid_pin_msg': {
      'en': 'Invalid PIN! Please try again.',
      'bn': 'ভুল পিন! আবার চেষ্টা করুন।',
    },

    // Edit Sale Dialog
    'edit_sale_history': {
      'en': 'Edit Sale History',
      'bn': 'বিক্রয় তথ্য পরিবর্তন',
    },
    'new_total_sale_tk': {
      'en': 'New Total Amount (Tk)',
      'bn': 'নতুন মোট টাকা',
    },
    'new_profit_tk': {
      'en': 'New Profit (Tk)',
      'bn': 'নতুন লাভ',
    },
    'sale_updated_msg': {
      'en': 'Sale updated successfully!',
      'bn': 'বিক্রয় তথ্য সফলভাবে আপডেট হয়েছে!',
    },

    // Settings Screen Additional
    'security_confirm_title': {
      'en': 'Security Confirmation',
      'bn': 'নিরাপত্তা নিশ্চিতকরণ',
    },
    'security_confirm_msg': {
      'en': 'Enter your PIN to save settings.',
      'bn': 'সেটিংস সেভ করতে আপনার পিন দিন।',
    },
    'app_pin_label': {
      'en': 'Enter App PIN',
      'bn': 'অ্যাপ পিন দিন',
    },
    'wrong_pin_msg': {
      'en': 'Wrong PIN! Action denied.',
      'bn': 'ভুল পিন! এক্সেস রিফিউজ করা হয়েছে।',
    },
    'confirm_btn': {
      'en': 'Confirm',
      'bn': 'নিশ্চিত করুন',
    },
    'change_pin_title': {
      'en': 'Change App PIN',
      'bn': 'পিন পরিবর্তন করুন',
    },
    'old_pin': {
      'en': 'Old PIN',
      'bn': 'পুরোনো পিন',
    },
    'new_pin_4_digit': {
      'en': 'New 4-Digit PIN',
      'bn': 'নতুন ৪-ডিজিটের পিন',
    },
    'pin_changed_msg': {
      'en': 'PIN changed successfully!',
      'bn': 'পিন সফলভাবে পরিবর্তন হয়েছে!',
    },
    'pin_must_4_digit': {
      'en': 'PIN must be 4 digits!',
      'bn': 'পিন অবশ্যই ৪ ডিজিটের হতে হবে!',
    },
    'old_pin_wrong': {
      'en': 'Old PIN is incorrect!',
      'bn': 'পুরোনো পিনটি সঠিক নয়!',
    },
    'save_settings_btn': {
      'en': 'Save Settings',
      'bn': 'সেটিংস সেভ করুন',
    },
    'settings_saved_msg': {
      'en': 'Settings saved successfully!',
      'bn': 'সেটিংস সফলভাবে সেভ হয়েছে!',
    },
    'shop_id_label': {
      'en': 'Your Shop ID (Click to copy)',
      'bn': 'আপনার দোকান আইডি (কপি করতে ক্লিক করুন)',
    },
    'copy_id_tooltip': {
      'en': 'Copy Shop ID',
      'bn': 'আইডি কপি করুন',
    },
    'copy_id_msg': {
      'en': 'Shop ID copied to clipboard!',
      'bn': 'দোকান আইডি কপি করা হয়েছে!',
    },
    'account_settings': {
      'en': 'Account Settings',
      'bn': 'অ্যাকাউন্ট সেটিংস',
    },
    'shop_info_label': {
      'en': 'Shop Information',
      'bn': 'দোকানের তথ্য',
    },
    'user_approval': {
      'en': 'User Approval Panel',
      'bn': 'ইউজার এপ্রুভাল প্যানেল',
    },

    // User Approval Panel
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
