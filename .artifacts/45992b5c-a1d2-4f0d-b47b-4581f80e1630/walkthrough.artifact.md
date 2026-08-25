# মাল্টি-ল্যাঙ্গুয়েজ (English & Bangla) সাপোর্ট সারসংক্ষেপ

অ্যাপে ভাষা পরিবর্তনের সুবিধা যোগ করা হয়েছে। এখন ব্যবহারকারী সেটিংস থেকে ইংরেজি বা বাংলা বেছে নিতে পারবেন এবং পুরো অ্যাপের ভাষা সেই অনুযায়ী পরিবর্তিত হবে।

## সম্পাদিত পরিবর্তনসমূহ (Changes Made)

### [Component] Translation Infrastructure
- **[NEW] [translations.dart](file:///C:/Users/bhskh/amardokan_new/lib/utils/translations.dart)**: এখানে সব ইংরেজি এবং বাংলা শব্দের ম্যাপ তৈরি করা হয়েছে।
- **[MODIFY] [main.dart](file:///C:/Users/bhskh/amardokan_new/lib/main.dart)**: অ্যাপ শুরু হওয়ার সময় সেভ করা ভাষা লোড করার লজিক যোগ করা হয়েছে।

### [Component] Settings UI
- **[MODIFY] [settings_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/settings_screen.dart)**: ভাষা পরিবর্তনের জন্য একটি ড্রপডাউন মেনু যোগ করা হয়েছে। এখান থেকে ভাষা পরিবর্তন করলে পুরো অ্যাপে তা কার্যকর হবে।

### [Component] Localized Screens
- **[MODIFY] [dashboard_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/dashboard_screen.dart)**: ড্যাশবোর্ডের সব মেনু এবং টেক্সট এখন ল্যাঙ্গুয়েজ সাপোর্ট করে।
- **[MODIFY] [products_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/products_screen.dart)**: হেডলাইন এবং কিছু মূল ফাংশন অনুবাদ করা হয়েছে।
- **[MODIFY] [pos_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/pos_screen.dart)**: POS স্ক্রিনের মূল ইন্টারফেস অনুবাদ করা হয়েছে।

## ব্যবহারবিধি (How to use)
১. অ্যাপের **সেটিংস (Settings)**-এ যান।
২. **ভাষা (Language)** অপশনটি খুঁজে বের করুন।
৩. ড্রপডাউন থেকে **English** বা **বাংলা** সিলেক্ট করুন।
৪. সাথে সাথেই পুরো অ্যাপের ভাষা পরিবর্তিত হয়ে যাবে।

> [!IMPORTANT]
> এটি একটি চলমান কাজ। আমি প্রধান স্ক্রিনগুলো অনুবাদ করেছি। আপনি যদি কোনো নির্দিষ্ট শব্দ বা স্ক্রিন দ্রুত অনুবাদ করতে চান, তবে আমাকে জানাবেন।

> [!TIP]
> আমি খেয়াল রেখেছি যেন আপনার আগের কোনো কোড বা ফিচার নষ্ট না হয়। সব লজিক ঠিকঠাক কাজ করছে।
