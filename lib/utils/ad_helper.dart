import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // টেস্ট আইডিগুলো ব্যবহার করা হয়েছে
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // আপনার রিয়েল ব্যানার অ্যাড আইডি
      return 'ca-app-pub-6060531284268467/3600494304';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      // আপনার রিয়েল ইন্টারস্টিশিয়াল অ্যাড আইডি
      return 'ca-app-pub-6060531284268467/6583197518';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
