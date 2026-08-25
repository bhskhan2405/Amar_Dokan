# রেজিস্ট্রেশনে রিয়েল OTP ভেরিফিকেশন যোগ করা হয়েছে

আমি আপনার অনুরোধ অনুযায়ী `login_register_screen.dart`-এ নতুন অ্যাকাউন্ট খোলার সময় রিয়েল OTP ভেরিফিকেশন সিস্টেম যোগ করেছি। এখন থেকে ব্যবহারকারী যে নম্বরটি দেবেন, সেই নম্বরে একটি কোড যাবে এবং সেটি ভেরিফাই করলেই কেবল অ্যাকাউন্ট তৈরি হবে।

## কি কি পরিবর্তন করা হয়েছে:

### ১. [translations.dart](file:///C:/Users/bhskh/amardokan_new/lib/utils/translations.dart)
- OTP সংক্রান্ত নতুন মেসেজ এবং বাটন টেক্সট যোগ করা হয়েছে (যেমন: `otp_sent`, `enter_otp`, `verify_otp` ইত্যাদি)।

### ২. [login_register_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/login_register_screen.dart)
- **`_sendOTP()`**: Firebase Phone Auth ব্যবহার করে SMS পাঠানোর লজিক যোগ করা হয়েছে। এটি অটোমেটিক বাংলাদেশি কান্ট্রি কোড (+88) হ্যান্ডেল করবে।
- **`_showOTPDialog()`**: ব্যবহারকারীর কাছ থেকে ৬ ডিজিটের কোড নেওয়ার জন্য একটি পপ-আপ ডায়ালগ যোগ করা হয়েছে।
- **`_completeRegistration()`**: OTP ভেরিফাই হওয়ার পর ইমেইল/পাসওয়ার্ড তৈরি এবং Firestore-এ ডাটা সেভ করার মূল কাজগুলো এখানে করা হবে।
- **`_submit()`**: রেজিস্ট্রেশন বাটনে ক্লিক করলে এখন সরাসরি অ্যাকাউন্ট তৈরি না হয়ে আগে OTP পাঠানো হবে।

## কিভাবে পরীক্ষা করবেন:
১. অ্যাপটি রান করুন এবং 'সাইন আপ' পেজে যান।
২. সব তথ্য দিয়ে রেজিস্ট্রেশন বাটনে ক্লিক করুন।
৩. আপনার মোবাইলে একটি SMS আসবে।
৪. অ্যাপের ডায়ালগ বক্সে সেই ৬ ডিজিটের কোডটি দিন।
৫. সঠিক কোড দিলে আপনার অ্যাকাউন্ট তৈরি হয়ে যাবে এবং আপনি ড্যাশবোর্ডে চলে যাবেন।

> [!IMPORTANT]
> আপনি যদি এখনো Firebase Console-এ **SHA-1** এবং **SHA-256** কী গুলো যোগ না করে থাকেন, তবে রিয়েল OTP আসবে না। দয়া করে সেটি নিশ্চিত করুন।

render_diffs(file:///C:/Users/bhskh/amardokan_new/lib/screens/login_register_screen.dart)
render_diffs(file:///C:/Users/bhskh/amardokan_new/lib/utils/translations.dart)
