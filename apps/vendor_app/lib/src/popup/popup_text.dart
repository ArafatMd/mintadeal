import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages for the pop-up stall screens, which many first-time and less literate sellers use.
enum PopupLang {
  en('English'),
  kn('ಕನ್ನಡ'),
  hi('हिंदी');

  const PopupLang(this.nativeName);

  final String nativeName;
}

class PopupLangController extends Notifier<PopupLang> {
  static const _key = 'mintadeal.popupLang';

  @override
  PopupLang build() {
    SharedPreferences.getInstance().then((p) {
      final saved = PopupLang.values.where((l) => l.name == p.getString(_key));
      if (saved.isNotEmpty) state = saved.first;
    });
    return PopupLang.en;
  }

  Future<void> choose(PopupLang lang) async {
    state = lang;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, lang.name);
  }
}

final popupLangProvider = NotifierProvider<PopupLangController, PopupLang>(PopupLangController.new);

/// Words for the pop-up screens. Short and plain on purpose; Kannada and Hindi should be checked by a native speaker.
class PopupText {
  const PopupText(this.lang);

  final PopupLang lang;

  String _t(String en, String kn, String hi) => switch (lang) {
        PopupLang.en => en,
        PopupLang.kn => kn,
        PopupLang.hi => hi,
      };

  // Choosing shop or stall.
  String get chooseTitle => _t('What do you sell?', 'ನೀವು ಏನು ಮಾರುತ್ತೀರಿ?', 'आप क्या बेचते हैं?');
  String get haveShop => _t('I have a shop', 'ನನಗೆ ಅಂಗಡಿ ಇದೆ', 'मेरी दुकान है');
  String get haveShopHint => _t('Register your shop. Mintadeal checks it first.',
      'ನಿಮ್ಮ ಅಂಗಡಿಯನ್ನು ನೋಂದಾಯಿಸಿ. Mintadeal ಮೊದಲು ಪರಿಶೀಲಿಸುತ್ತದೆ.', 'अपनी दुकान रजिस्टर करें। Mintadeal पहले जाँच करेगा।');
  String get stall => _t('Stall for a few days', 'ಕೆಲವು ದಿನಗಳ ಸ್ಟಾಲ್', 'कुछ दिनों का स्टॉल');
  String get stallHint => _t('Street, cart, market or event. Start in 2 minutes.',
      'ರಸ್ತೆ ಬದಿ, ತಳ್ಳುಗಾಡಿ, ಸಂತೆ ಅಥವಾ ಮೇಳ. 2 ನಿಮಿಷದಲ್ಲಿ ಶುರು ಮಾಡಿ.', 'सड़क, ठेला, बाज़ार या मेला। 2 मिनट में शुरू करें।');

  // Common.
  String get next => _t('Next', 'ಮುಂದೆ', 'आगे');
  String get back => _t('Back', 'ಹಿಂದೆ', 'पीछे');
  String get yes => _t('Yes', 'ಹೌದು', 'हाँ');
  String get no => _t('No', 'ಇಲ್ಲ', 'नहीं');
  String get save => _t('Save', 'ಉಳಿಸಿ', 'सेव करें');
  String get language => _t('Language', 'ಭಾಷೆ', 'भाषा');
  String get help => _t('Help', 'ಸಹಾಯ', 'मदद');
  String get signOut => _t('Log out', 'ಲಾಗ್ ಔಟ್', 'लॉग आउट');
  String get myStall => _t('My stall', 'ನನ್ನ ಸ್ಟಾಲ್', 'मेरा स्टॉल');

  // Steps.
  String get startSelling => _t('Start selling', 'ಮಾರಾಟ ಶುರು ಮಾಡಿ', 'बेचना शुरू करें');
  String get yourName => _t('Your name or stall name', 'ನಿಮ್ಮ ಹೆಸರು ಅಥವಾ ಸ್ಟಾಲ್ ಹೆಸರು', 'आपका नाम या स्टॉल का नाम');
  String get yourNameHint => _t('Customers see this name', 'ಗ್ರಾಹಕರು ಈ ಹೆಸರನ್ನು ನೋಡುತ್ತಾರೆ', 'ग्राहक यह नाम देखेंगे');
  String get typeName => _t('Write a name', 'ಹೆಸರು ಬರೆಯಿರಿ', 'नाम लिखें');
  String get photosTitle =>
      _t('Take photos of what you sell', 'ನೀವು ಮಾರುವ ವಸ್ತುಗಳ ಫೋಟೋ ತೆಗೆಯಿರಿ', 'जो बेचते हैं उसकी फ़ोटो लें');
  String get takePhoto => _t('Take photo', 'ಫೋಟೋ ತೆಗೆಯಿರಿ', 'फ़ोटो लें');
  String get fromGallery => _t('From gallery', 'ಗ್ಯಾಲರಿಯಿಂದ', 'गैलरी से');
  String get price => _t('Price ₹', 'ಬೆಲೆ ₹', 'दाम ₹');
  String get itemName => _t('What is it?', 'ಇದು ಏನು?', 'यह क्या है?');
  String get optional => _t('optional', 'ಬೇಕಿದ್ದರೆ', 'ज़रूरी नहीं');
  String get addOnePhoto => _t('Add at least 1 photo', 'ಕನಿಷ್ಠ 1 ಫೋಟೋ ಸೇರಿಸಿ', 'कम से कम 1 फ़ोटो डालें');
  String get notAllowed => _t('Not allowed: alcohol, tobacco, medicines, fireworks, animals.',
      'ಅನುಮತಿ ಇಲ್ಲ: ಮದ್ಯ, ತಂಬಾಕು, ಔಷಧಿ, ಪಟಾಕಿ, ಪ್ರಾಣಿಗಳು.', 'मना है: शराब, तंबाकू, दवाइयाँ, पटाखे, जानवर।');
  String get daysTitle =>
      _t('How many days will you sell here?', 'ಇಲ್ಲಿ ಎಷ್ಟು ದಿನ ಮಾರುತ್ತೀರಿ?', 'यहाँ कितने दिन बेचेंगे?');
  String days(int n) => _t(n == 1 ? '1 day' : '$n days', '$n ದಿನ', '$n दिन');
  String get hereTitle =>
      _t('Are you at your stall now?', 'ನೀವು ಈಗ ನಿಮ್ಮ ಸ್ಟಾಲ್‌ನಲ್ಲಿ ಇದ್ದೀರಾ?', 'क्या आप अभी अपने स्टॉल पर हैं?');
  String get hereHint => _t('Stand at your stall. Customers will see this place.',
      'ನಿಮ್ಮ ಸ್ಟಾಲ್ ಬಳಿ ನಿಂತುಕೊಳ್ಳಿ. ಗ್ರಾಹಕರಿಗೆ ಈ ಜಾಗ ಕಾಣುತ್ತದೆ.', 'अपने स्टॉल के पास खड़े हों। ग्राहक यह जगह देखेंगे।');
  String get imHere => _t('Yes, I am here. Start!', 'ಹೌದು, ನಾನು ಇಲ್ಲೇ ಇದ್ದೇನೆ. ಶುರು!', 'हाँ, मैं यहीं हूँ। शुरू करें!');
  String phoneShown(String phone) => _t('Customers can call you on $phone.',
      'ಗ್ರಾಹಕರು ನಿಮಗೆ $phone ಗೆ ಕರೆ ಮಾಡಬಹುದು.', 'ग्राहक आपको $phone पर कॉल कर सकते हैं।');
  String get finding => _t('Finding your place…', 'ನಿಮ್ಮ ಜಾಗ ಹುಡುಕುತ್ತಿದೆ…', 'आपकी जगह ढूँढ रहे हैं…');
  String get locationFailed => _t('Could not find your place. Turn on location and try again.',
      'ನಿಮ್ಮ ಜಾಗ ಸಿಗಲಿಲ್ಲ. ಲೊಕೇಶನ್ ಆನ್ ಮಾಡಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.', 'आपकी जगह नहीं मिली। लोकेशन चालू करके फिर कोशिश करें।');
  String get outsideCity => _t('Mintadeal is only in Bengaluru for now.', 'Mintadeal ಈಗ ಬೆಂಗಳೂರಿನಲ್ಲಿ ಮಾತ್ರ ಇದೆ.',
      'Mintadeal अभी सिर्फ़ बेंगलुरु में है।');
  String near(String area) => _t('Near $area', '$area ಹತ್ತಿರ', '$area के पास');

  // Live.
  String get youAreLive => _t('You are live!', 'ನೀವು ಈಗ ಲೈವ್!', 'आप लाइव हैं!');
  String get liveTitle => _t('You are selling now', 'ನೀವು ಈಗ ಮಾರಾಟ ಮಾಡುತ್ತಿದ್ದೀರಿ', 'आप अभी बेच रहे हैं');
  String get liveHint => _t('Customers near you can see your stall.', 'ಹತ್ತಿರದ ಗ್ರಾಹಕರು ನಿಮ್ಮ ಸ್ಟಾಲ್ ನೋಡಬಹುದು.',
      'पास के ग्राहक आपका स्टॉल देख सकते हैं।');
  String endsIn(Duration left) {
    final d = left.inDays;
    final h = left.inHours % 24;
    final m = left.inMinutes % 60;
    final parts = switch (lang) {
      PopupLang.en => [if (d > 0) d == 1 ? '1 day' : '$d days', if (h > 0) h == 1 ? '1 hour' : '$h hours',
          if (d == 0 && h == 0) '$m min'],
      PopupLang.kn => [if (d > 0) '$d ದಿನ', if (h > 0) '$h ಗಂಟೆ', if (d == 0 && h == 0) '$m ನಿಮಿಷ'],
      PopupLang.hi => [if (d > 0) '$d दिन', if (h > 0) '$h घंटे', if (d == 0 && h == 0) '$m मिनट'],
    };
    final when = parts.join(' ');
    return _t('Ends in $when', 'ಇನ್ನು $when ಬಾಕಿ', 'अभी $when बाकी');
  }

  String get moved => _t('I moved. Update my place', 'ನಾನು ಜಾಗ ಬದಲಿಸಿದೆ', 'मैंने जगह बदली');
  String get placeUpdated => _t('Place updated', 'ಜಾಗ ಬದಲಾಯಿತು', 'जगह बदल दी गई');
  String get stop => _t('Stop selling', 'ಮಾರಾಟ ನಿಲ್ಲಿಸಿ', 'बेचना बंद करें');
  String get stopConfirm => _t('Stop now? Customers will not see your stall.',
      'ಈಗ ನಿಲ್ಲಿಸಬೇಕೆ? ಗ್ರಾಹಕರಿಗೆ ನಿಮ್ಮ ಸ್ಟಾಲ್ ಕಾಣುವುದಿಲ್ಲ.', 'अभी बंद करें? ग्राहकों को आपका स्टॉल नहीं दिखेगा।');
  String get stopped => _t('Stopped', 'ನಿಲ್ಲಿಸಲಾಗಿದೆ', 'बंद किया');

  // History.
  String get pastStalls => _t('Your past stalls', 'ಹಿಂದಿನ ಸ್ಟಾಲ್‌ಗಳು', 'पिछले स्टॉल');
  String get sellAgain => _t('Sell again', 'ಮತ್ತೆ ಮಾರಿ', 'फिर से बेचें');
  String get removed => _t('Taken down by Mintadeal', 'Mintadeal ತೆಗೆದುಹಾಕಿದೆ', 'Mintadeal ने हटाया');
  String get blocked => _t('You cannot open stalls. Ask Mintadeal for help.',
      'ನೀವು ಸ್ಟಾಲ್ ತೆರೆಯಲು ಸಾಧ್ಯವಿಲ್ಲ. Mintadeal ಸಹಾಯ ಕೇಳಿ.', 'आप स्टॉल नहीं खोल सकते। Mintadeal से मदद लें।');
  String get changeName => _t('Change name', 'ಹೆಸರು ಬದಲಿಸಿ', 'नाम बदलें');

  // Shops, more stalls and fees.
  String get stallNameTitle => _t('Name of this stall', 'ಈ ಸ್ಟಾಲ್‌ನ ಹೆಸರು', 'इस स्टॉल का नाम');
  String get stallNameHint => _t('For example: your shop name and the event', 'ಉದಾ: ನಿಮ್ಮ ಅಂಗಡಿ ಹೆಸರು ಮತ್ತು ಮೇಳ',
      'जैसे: आपकी दुकान का नाम और मेला');
  String get myStalls => _t('Pop-up stalls', 'ಪಾಪ್-ಅಪ್ ಸ್ಟಾಲ್‌ಗಳು', 'पॉप-अप स्टॉल');
  String get myStallsHint => _t('Selling at an event or market? Open a stall for a few days.',
      'ಮೇಳ ಅಥವಾ ಸಂತೆಯಲ್ಲಿ ಮಾರುತ್ತಿದ್ದೀರಾ? ಕೆಲವು ದಿನಗಳ ಸ್ಟಾಲ್ ತೆರೆಯಿರಿ.', 'मेले या बाज़ार में बेच रहे हैं? कुछ दिनों का स्टॉल खोलें।');
  String get startAnother => _t('Start another stall', 'ಇನ್ನೊಂದು ಸ್ಟಾಲ್ ಶುರು ಮಾಡಿ', 'एक और स्टॉल शुरू करें');
  String canRun(int n) => _t('You can run $n stalls at a time', 'ನೀವು ಒಂದೇ ಸಮಯದಲ್ಲಿ $n ಸ್ಟಾಲ್ ನಡೆಸಬಹುದು',
      'आप एक साथ $n स्टॉल चला सकते हैं');
  String feeInfo(String perDay, int days, String total) => _t('Fee: $perDay a day. $days days = $total',
      'ಶುಲ್ಕ: ದಿನಕ್ಕೆ $perDay. $days ದಿನ = $total', 'शुल्क: $perDay प्रति दिन। $days दिन = $total');
  String get feeFromShop => _t('Taken from your shop balance.', 'ನಿಮ್ಮ ಅಂಗಡಿ ಬ್ಯಾಲೆನ್ಸ್‌ನಿಂದ ಕಡಿತ.',
      'आपकी दुकान के बैलेंस से कटेगा।');
  String get feeOnline => _t('Pay online before your stall goes live.', 'ಸ್ಟಾಲ್ ಲೈವ್ ಆಗುವ ಮೊದಲು ಆನ್‌ಲೈನ್‌ನಲ್ಲಿ ಪಾವತಿಸಿ.',
      'स्टॉल लाइव होने से पहले ऑनलाइन भुगतान करें।');
  String get free => _t('Free', 'ಉಚಿತ', 'मुफ़्त');
  String get waitingPayment => _t('Waiting for payment', 'ಪಾವತಿಗಾಗಿ ಕಾಯುತ್ತಿದೆ', 'भुगतान का इंतज़ार');
  String waitingPaymentHint(int minutes) => _t('Pay within $minutes minutes. Customers see your stall after you pay.',
      '$minutes ನಿಮಿಷದೊಳಗೆ ಪಾವತಿಸಿ. ಪಾವತಿಸಿದ ನಂತರ ಗ್ರಾಹಕರಿಗೆ ಕಾಣುತ್ತದೆ.',
      '$minutes मिनट में भुगतान करें। भुगतान के बाद ग्राहक आपका स्टॉल देखेंगे।');
  String pay(String amount) => _t('Pay $amount', '$amount ಪಾವತಿಸಿ', '$amount भुगतान करें');
  String get iHavePaid => _t('I have paid', 'ನಾನು ಪಾವತಿಸಿದ್ದೇನೆ', 'मैंने भुगतान कर दिया');
  String get notPaidYet => _t('Payment not received yet. Try again in a minute.',
      'ಪಾವತಿ ಇನ್ನೂ ಬಂದಿಲ್ಲ. ಒಂದು ನಿಮಿಷದ ನಂತರ ಪ್ರಯತ್ನಿಸಿ.', 'भुगतान अभी नहीं मिला। एक मिनट बाद फिर कोशिश करें।');
  String get cancel => _t('Cancel', 'ರದ್ದು ಮಾಡಿ', 'रद्द करें');
  String get paidLive => _t('Paid. You are live!', 'ಪಾವತಿಯಾಯಿತು. ನೀವು ಲೈವ್!', 'भुगतान हो गया। आप लाइव हैं!');
}

final popupTextProvider = Provider<PopupText>((ref) => PopupText(ref.watch(popupLangProvider)));
