# স্টাফ এক্সেস এবং লোডিং ফিক্সের সারাংশ

আমি আপনার প্রোজেক্টের কোড আপডেট করেছি যাতে স্টাফরা যখন ডাটাবেজ এক্সেস করার চেষ্টা করে, তখন কোনো সমস্যা হলে তা স্ক্রিনে দেখা যায়। এর আগে ডাটা লোড না হলে শুধু অনন্তকাল ধরে লোডিং এনিমেশন দেখাতো।

## যা পরিবর্তন করা হয়েছে:

### ১. এরর হ্যান্ডেলিং যোগ করা
- **POS Screen**, **Products Screen**, এবং **Hisab Kitab Screen**-এ ফায়ারস্টোর কোয়েরিতে এরর হ্যান্ডেলিং যোগ করা হয়েছে।
- এখন যদি ডাটাবেজ থেকে ডাটা আসতে কোনো বাধা থাকে (যেমন পারমিশন নাই), তবে আপনি স্ক্রিনে লাল রঙে এরর মেসেজটি দেখতে পাবেন।

## আপনার জন্য জরুরি করণীয়:

স্টাফদের ডাটা দেখানোর জন্য আপনাকে আপনার **Firebase Console**-এ গিয়ে নিচের রুলসগুলো আপডেট করতে হবে:

১. [Firebase Console](https://console.firebase.google.com/)-এ যান।
২. **Firestore Database** -> **Rules** ট্যাবে যান।
৩. আগের রুলস মুছে নিচের এই নতুন কোডটি পেস্ট করে **Publish** করুন।

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ১. ইউজার, স্টাফ এবং দোকানের সব ডাটা এক্সেস করার নিয়ম
    match /users/{userId}/{document=**} {
      allow read, write: if true;
    }

    // ২. নোটিফিকেশন রুলস
    match /notifications/{notificationId} {
      allow create: if request.auth != null;
      allow read: if true;
      allow update, delete: if true;
    }

    // ৩. বাকি সব কিছুর জন্য সাধারণ নিয়ম
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

এই রুলসগুলো সেট করার সাথে সাথেই স্টাফরা লোডিং ছাড়াই ডাটা দেখতে পাবেন। আপনার আগের কোনো কোড বা ফিচার ডিলিট করা হয়নি।
