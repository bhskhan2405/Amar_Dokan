# অ্যাপের ফিচার ও অ্যাকাউন্ট ডিলিট সমস্যা সমাধানের পরিকল্পনা

এই পরিকল্পনাটি অ্যাপের **Product, POS, Hisab Kitab** ফিচারগুলো পুনরায় সচল করা এবং **Account Deletion** লজিকটি ঠিক করার জন্য তৈরি করা হয়েছে।

## User Review Required

> [!IMPORTANT]
> বর্তমানে পেন্ডিং ইউজারদের (যাদের অ্যাকাউন্ট এখনো অ্যাপ্রুভ হয়নি) ড্যাশবোর্ডে প্রবেশের অনুমতি দেওয়া হচ্ছে কিন্তু ফায়ারবেস অথেন্টিকেশনে লগইন করানো হচ্ছে না। এর ফলে ডাটা লোড হচ্ছে না। আমি এটি পরিবর্তন করে আগে লগইন করাবো এবং তারপর ড্যাশবোর্ডে পেন্ডিং স্ট্যাটাস দেখাবো।

## Proposed Changes

### 1. Authentication Flow [Component]
লগইন প্রসেসটি এমনভাবে সাজানো হবে যাতে ইউজার সব সময় অথেন্টিকেটেড থাকে।

#### [MODIFY] [login_register_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/login_register_screen.dart)
- `isApproved` চেক করার আগেই `FirebaseAuth.instance.signInWithEmailAndPassword` কল করা হবে।
- এর ফলে ইউজার পেন্ডিং থাকলেও তার UID ডাটাবেস কোয়েরির জন্য পাওয়া যাবে।

### 2. Account Settings & Deletion [Component]
অ্যাকাউন্ট ডিলিট করার প্রসেসটি আরও শক্তিশালী করা হবে।

#### [MODIFY] [settings_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/settings_screen.dart)
- `_deleteAccount` ফাংশনে `reauthenticateWithCredential` যোগ করা হবে যাতে Firebase Auth এরর না দেয়।
- অ্যাকাউন্ট ডিলিট করার আগে ফায়ারস্টোর থেকে ইউজারের সব ডাটা (Products, Customers, Transactions) মুছে ফেলার লজিক যোগ করা হবে (যাতে কোনো আবর্জনা ডাটা না থাকে)।

### 3. Utility Improvements [Component]
শপ আইডি পাওয়ার প্রক্রিয়াটি আরও নিশ্চিত করা হবে।

#### [MODIFY] [shop_utils.dart](file:///C:/Users/bhskh/amardokan_new/lib/utils/shop_utils.dart)
- `getShopId` ফাংশনটি এমনভাবে আপডেট করা হবে যাতে এটি `FirebaseAuth.instance.currentUser` থেকে সরাসরি ডাটা নিতে পারে যদি `SharedPreferences` খালি থাকে।

## Verification Plan

### Automated Tests
- লগইন করার পর `ShopUtils.getShopId()` সঠিক UID দিচ্ছে কি না তা চেক করা।
- অ্যাকাউন্ট ডিলিট করার সময় সব ডাটা মুছে যাচ্ছে কি না তা পরীক্ষা করা।

### Manual Verification
- একটি নতুন অ্যাকাউন্ট দিয়ে লগইন করে দেখা যে ড্যাশবোর্ডে ডাটা লোড হচ্ছে কি না।
- পিন দিয়ে অ্যাকাউন্ট ডিলিট করার চেষ্টা করা এবং দেখা যে এটি পুনরায় লগইন স্ক্রিনে পাঠাচ্ছে কি না।
