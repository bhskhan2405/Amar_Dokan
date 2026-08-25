# রেজিস্ট্রেশনে রিয়েল OTP ভেরিফিকেশন যোগ করার পরিকল্পনা

এই পরিকল্পনায় `login_register_screen.dart`-এ নতুন অ্যাকাউন্ট খোলার সময় Firebase Phone Authentication ব্যবহার করে একটি ৬ ডিজিটের OTP ভেরিফিকেশন সিস্টেম যোগ করা হবে। এর ফলে শুধুমাত্র সঠিক মোবাইল নম্বর ব্যবহার করেই অ্যাকাউন্ট খোলা যাবে।

## ব্যবহারকারীর জন্য গুরুত্বপূর্ণ নোট (IMPORTANT)

> [!IMPORTANT]
> রিয়েল OTP কাজ করার জন্য আপনাকে অবশ্যই আপনার প্রোজেক্টের **Firebase Console**-এ গিয়ে **Phone Authentication** এনাবল করতে হবে। এছাড়াও অ্যান্ড্রয়েডের ক্ষেত্রে **Firebase Console**-এ আপনার অ্যাপের **SHA-1** ও **SHA-256** ফিঙ্গারপ্রিন্ট সেটআপ করতে হবে এবং Google Cloud Console-এ **Android Device Check API** এনাবল থাকতে হবে। অন্যথায় OTP আসবে না।

## প্রস্তাবিত পরিবর্তনসমূহ (Proposed Changes)

### [Component] Authentication Logic & UI

#### [MODIFY] [login_register_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/login_register_screen.dart)
- **নতুন স্টেট ভেরিয়েবল**:
    - `_verificationId` এবং `_resendToken` স্টোর করার জন্য ভেরিয়েবল যোগ করা হবে।
- **OTP পাঠানোর লজিক**:
    - `_sendOTP()` নামে একটি মেথড যোগ করা হবে যা `FirebaseAuth.instance.verifyPhoneNumber` কল করবে।
- **OTP ভেরিফিকেশন ডায়ালগ**:
    - OTP কোড ইনপুট নেওয়ার জন্য একটি সুন্দর ডায়ালগ বক্স তৈরি করা হবে।
- **রেজিস্ট্রেশন ফ্লো পরিবর্তন**:
    - `_submit()` ফাংশনে রেজিস্ট্রেশনের সময় সরাসরি অ্যাকাউন্ট তৈরি না করে আগে `_sendOTP()` কল করা হবে।
    - OTP সফলভাবে ভেরিফাই হওয়ার পর মূল রেজিস্ট্রেশন লজিক (`createUserWithEmailAndPassword` এবং Firestore-এ ডাটা সেভ) সম্পন্ন করা হবে।

### [Component] Localized Strings

#### [MODIFY] [translations.dart](file:///C:/Users/bhskh/amardokan_new/lib/utils/translations.dart)
- নিচের কী-গুলো যোগ করা হবে:
    - `otp_sent`: "OTP পাঠানো হয়েছে!" / "OTP Sent!"
    - `enter_otp`: "৬ ডিজিটের কোডটি দিন" / "Enter 6-digit code"
    - `verify_otp`: "ভেরিফাই করুন" / "Verify OTP"
    - `invalid_otp`: "ভুল OTP কোড!" / "Invalid OTP Code!"
    - `otp_error`: "OTP পাঠাতে সমস্যা হয়েছে" / "Failed to send OTP"

## ভেরিফিকেশন প্ল্যান (Verification Plan)

### ম্যানুয়াল ভেরিফিকেশন (Manual Verification)
- একটি সঠিক মোবাইল নম্বর দিয়ে সাইন আপ করার চেষ্টা করা হবে।
- মোবাইলে SMS-এর মাধ্যমে ৬ ডিজিটের রিয়েল OTP কোড আসছে কিনা পরীক্ষা করা হবে।
- ভুল OTP দিয়ে চেক করা হবে যে এরর মেসেজ দেখাচ্ছে কিনা।
- সঠিক OTP দেওয়ার পর আগের মতোই অ্যাকাউন্ট তৈরি হচ্ছে কিনা এবং ডাটাবেজে সঠিক তথ্য সেভ হচ্ছে কিনা তা নিশ্চিত করা হবে।
