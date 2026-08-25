# POS এবং রিপোর্ট PDF-এ স্টাফের নাম যুক্ত করার পরিকল্পনা

এই পরিবর্তনের লক্ষ্য হলো POS রিসিপ্ট এবং সেলস রিপোর্ট PDF-এ বিক্রয়কারী স্টাফের নাম এবং রোল (Admin/Staff) প্রদর্শন করা। বর্তমানে অনেক ক্ষেত্রে এটি প্রদর্শিত হয় না অথবা শুধুমাত্র "Admin" হিসেবে থাকে।

## ইউজার রিভিউ প্রয়োজন

- **লেবেল ভাষা:** আমি "Sold By" (বা বাংলা ফন্টে "বিক্রেতা") লেবেল ব্যবহার করব।
- **প্রদর্শন ফরম্যাট:** যদি স্টাফ বিক্রি করে তবে "Staff: [নাম]" এবং এডমিন বিক্রি করলে "Admin" প্রদর্শিত হবে।

## প্রস্তাবিত পরিবর্তনসমূহ

### [POS এবং রিপোর্ট মডিউল]

#### [MODIFY] [pos_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/pos_screen.dart)
- `_generateAndPrintBill` এবং `_processReceipt` ফাংশনে `staffName` ডাটা রিড করা হবে।
- PDF-এর `pw.Column`-এ "Sold By" তথ্য যোগ করা হবে।
- `staffName` যদি "Admin" হয় তবে শুধু "Admin" দেখাবে, অন্যথায় "Staff: [নাম]" দেখাবে।

#### [MODIFY] [reports_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/reports_screen.dart)
- `_generatePdf` ফাংশনে `saleData['staffName']` রিড করা হবে।
- PDF রিপোর্টে "Sold By" তথ্য যোগ করা হবে।

#### [MODIFY] [hisab_kitab.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/hisab_kitab.dart)
- `_generateAndPrintPdf` ফাংশনে ইউজার/স্টাফ প্রদর্শনের লজিক আপডেট করা হবে যাতে "Staff: [নাম]" ফরম্যাট বজায় থাকে।

## যাচাইকরণ পরিকল্পনা

### ম্যানুয়াল ভেরিফিকেশন
- POS থেকে একটি নতুন বিক্রি করে PDF শেয়ার বা প্রিন্ট করে দেখা হবে যে স্টাফের নাম আসছে কিনা।
- সেলস হিস্ট্রি থেকে পুরাতন বিক্রির PDF জেনারেট করে দেখা হবে।
- রিপোর্ট স্ক্রিন থেকে PDF জেনারেট করে দেখা হবে।
