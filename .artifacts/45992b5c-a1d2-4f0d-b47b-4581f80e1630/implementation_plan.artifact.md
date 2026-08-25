# রেজিস্ট্রেশনে রিয়েল OTP ভেরিফিকেশন যোগ করার পরিকল্পনা

এই পরিকল্পনায় `login_register_screen.dart`-এ নতুন অ্যাকাউন্ট খোলার সময় Firebase Phone Authentication ব্যবহার করে একটি ৬ ডিজিটের OTP ভেরিফিকেশন সিস্টেম যোগ করা হবে। এর ফলে শুধুমাত্র সঠিক মোবাইল নম্বর ব্যবহার করেই অ্যাকাউন্ট খোলা যাবে।

## ব্যবহারকারীর জন্য গুরুত্বপূর্ণ নোট (IMPORTANT)

> [!IMPORTANT]
> রিয়েল OTP কাজ করার জন্য আপনাকে অবশ্যই আপনার প্রোজেক্টের **Firebase Console**-এ গিয়ে **Phone Authentication** এনাবল করতে হবে এবং আপনার অ্যাপের **SHA-1** ও **SHA-256** ফিঙ্গারপ্রিন্ট সেটআপ করতে হবে। অন্যথায় OTP আসবে না।

## প্রস্তাবিত পরিবর্তনসমূহ (Proposed Changes)

### [Component] Authentication Logic

#### [MODIFY] [login_register_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/login_register_screen.dart)
- **OTP ভেরিফিকেশন লজিক**:
    - `_verifyPhoneNumber()` নামে একটি নতুন মেথড যোগ করা হবে যা Firebase-এর `verifyPhoneNumber` ফাংশন কল করবে।
    - রেজিস্ট্রেশন বাটনে ক্লিক করলে প্রথমে OTP পাঠানো হবে।
- **OTP ডায়ালগ**:
    - OTP পাঠানোর পর একটি পপ-আপ ডায়ালগ আসবে যেখানে ব্যবহারকারী ৬ ডিজিটের কোডটি লিখবেন।
- **অ্যাকাউন্ট তৈরি**:
    - OTP সফলভাবে ভেরিফাই হওয়ার পর আগের মতোই ইমেইল/পাসওয়ার্ড এবং Firestore-এ ডাটা সেভ করার প্রসেসটি সম্পন্ন হবে।

### [Component] Localized Strings

#### [MODIFY] [translations.dart](file:///C:/Users/bhskh/amardokan_new/lib/utils/translations.dart)
- OTP সংক্রান্ত নতুন শব্দ যোগ করা হবে:
    - `otp_sent`: "OTP পাঠানো হয়েছে!" / "OTP Sent!"
    - `enter_otp`: "৬ ডিজিটের কোডটি দিন" / "Enter 6-digit code"
    - `verify_otp`: "ভেরিফাই করুন" / "Verify OTP"
    - `invalid_otp`: "ভুল OTP কোড!" / "Invalid OTP Code!"

## ভেরিফিকেশন প্ল্যান (Verification Plan)

### ম্যানুয়াল ভেরিফিকেশন (Manual Verification)
- নতুন একটি মোবাইল নম্বর দিয়ে রেজিস্ট্রেশন করার চেষ্টা করা হবে।
- দেখা হবে মোবাইলে SMS-এর মাধ্যমে ৬ ডিজিটের কোড আসছে কিনা।
- ভুল কোড দিয়ে চেক করা হবে যে এরর মেসেজ দিচ্ছে কিনা।
- সঠিক কোড দেওয়ার পর অ্যাকাউন্ট সফলভাবে তৈরি হচ্ছে কিনা এবং ড্যাশবোর্ডে নিয়ে যাচ্ছে কিনা তা নিশ্চিত করা হবে।
