import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_helper.dart';
import 'subscription_utils.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static int _productAddCount = 0;
  static int _posSaleCount = 0;

  // প্রোডাক্ট অ্যাডিং কাউন্ট চেক ও অ্যাড দেখানো
  static Future<void> checkAndShowProductAd(Function onAdDismissed) async {
    if (await SubscriptionUtils.isPremium()) {
      onAdDismissed();
      return;
    }

    _productAddCount++;
    if (_productAddCount >= 3) {
      _loadInterstitialAd((ad) {
        ad.show();
        _productAddCount = 0;
        onAdDismissed();
      }, onAdDismissed);
    } else {
      onAdDismissed();
    }
  }

  // POS সেল কাউন্ট চেক ও অ্যাড দেখানো
  static Future<void> checkAndShowSaleAd(Function onAdDismissed) async {
    if (await SubscriptionUtils.isPremium()) {
      onAdDismissed();
      return;
    }

    _posSaleCount++;
    if (_posSaleCount >= 1) { // আপনি বলেছিলেন প্রতি ১ টা সেল পর পর অ্যাড
      _loadInterstitialAd((ad) {
        ad.show();
        _posSaleCount = 0;
        onAdDismissed();
      }, onAdDismissed);
    } else {
      onAdDismissed();
    }
  }

  static void _loadInterstitialAd(Function(InterstitialAd) onLoaded, Function onFail) {
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          onLoaded(ad);
        },
        onAdFailedToLoad: (err) {
          onFail();
        },
      ),
    );
  }
}
