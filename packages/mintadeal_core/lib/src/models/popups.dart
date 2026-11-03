import 'models.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
double _double(Object? v) => (v as num).toDouble();

/// One photo of something a pop-up stall sells, with an optional name and price.
class PopupItem {
  const PopupItem({required this.imageUrl, this.title, this.priceMinor});

  PopupItem.fromJson(Json j)
      : imageUrl = j['imageUrl'] as String,
        title = j['title'] as String?,
        priceMinor = (j['priceMinor'] as num?)?.toInt();

  final String imageUrl;
  final String? title;
  final int? priceMinor;

  Json toJson() => {'imageUrl': imageUrl, 'title': title, 'priceMinor': priceMinor};
}

// ignore: constant_identifier_names
enum PopupStatus { PENDING_PAYMENT, LIVE, ENDED, REMOVED }

/// A stall as its seller sees it.
class MyPopup {
  MyPopup.fromJson(Json j)
      : id = j['id'] as String,
        status = PopupStatus.values.byName(j['status'] as String),
        name = j['name'] as String? ?? '',
        items = [for (final i in j['items'] as List) PopupItem.fromJson(i as Json)],
        latitude = _double(j['latitude']),
        longitude = _double(j['longitude']),
        days = (j['days'] as num).toInt(),
        startsAt = _date(j['startsAt'])!,
        endsAt = _date(j['endsAt'])!,
        stoppedAt = _date(j['stoppedAt']),
        removedReason = j['removedReason'] as String?,
        feeMinor = (j['feeMinor'] as num?)?.toInt() ?? 0,
        paymentUrl = j['paymentUrl'] as String?,
        paymentDeadline = _date(j['paymentDeadline']);

  final String id;
  final PopupStatus status;

  /// This stall's name, which customers see.
  final String name;
  final int feeMinor;

  /// Where to pay the fee, while the stall is waiting for it.
  final String? paymentUrl;
  final DateTime? paymentDeadline;
  final List<PopupItem> items;
  final double latitude;
  final double longitude;
  final int days;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? stoppedAt;
  final String? removedReason;

  /// When it actually finished: stopped early, or its days ran out.
  DateTime get endedAt => stoppedAt ?? endsAt;
}

/// Everything the seller's pop-up screen needs.
class PopupMe {
  PopupMe.fromJson(Json j)
      : name = j['name'] as String?,
        blocked = j['blocked'] as bool? ?? false,
        blockedReason = j['blockedReason'] as String?,
        active = [for (final p in j['active'] as List? ?? const []) MyPopup.fromJson(p as Json)],
        history = [for (final p in j['history'] as List? ?? const []) MyPopup.fromJson(p as Json)],
        allowedDays = [for (final d in j['allowedDays'] as List? ?? const [1, 2, 3, 7]) (d as num).toInt()],
        defaultDays = (j['defaultDays'] as num?)?.toInt() ?? 2,
        maxItems = (j['maxItems'] as num?)?.toInt() ?? 6,
        maxLive = (j['maxLive'] as num?)?.toInt() ?? 1,
        feePerDayMinor = (j['feePerDayMinor'] as num?)?.toInt() ?? 0,
        shopName = j['shopName'] as String?;

  /// Null until the person has opened their first stall.
  final String? name;
  final bool blocked;
  final String? blockedReason;
  /// Stalls live now or waiting for their fee, newest first.
  final List<MyPopup> active;
  final List<MyPopup> history;
  final List<int> allowedDays;
  final int defaultDays;
  final int maxItems;

  /// How many stalls this seller may run at once.
  final int maxLive;

  /// The listing fee per day; 0 when free.
  final int feePerDayMinor;

  /// The seller's approved shop: its stalls show it, and fees come off the shop's balance.
  final String? shopName;

  bool get isShop => shopName != null;
  bool get canStartAnother => !blocked && active.length < maxLive;
}

/// A live stall as customers see it.
class PublicPopup {
  PublicPopup.fromJson(Json j)
      : id = j['id'] as String,
        sellerName = j['sellerName'] as String,
        phone = j['phone'] as String?,
        items = [for (final i in j['items'] as List) PopupItem.fromJson(i as Json)],
        latitude = _double(j['latitude']),
        longitude = _double(j['longitude']),
        distanceKm = (j['distanceKm'] as num?)?.toDouble(),
        startsAt = _date(j['startsAt'])!,
        endsAt = _date(j['endsAt'])!,
        vendorId = j['vendorId'] as String?,
        vendorName = j['vendorName'] as String?;

  final String id;
  final String sellerName;

  /// The approved shop running this stall, or null for an independent seller.
  final String? vendorId;
  final String? vendorName;
  final String? phone;
  final List<PopupItem> items;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final DateTime startsAt;
  final DateTime endsAt;
}

// ignore: constant_identifier_names
enum PopupReportReason { NOT_THERE, FAKE_OR_MISLEADING, NOT_ALLOWED, RUDE_OR_UNSAFE, OTHER }

extension PopupReportReasonLabel on PopupReportReason {
  String get label => switch (this) {
        PopupReportReason.NOT_THERE => 'The stall is not there',
        PopupReportReason.FAKE_OR_MISLEADING => 'Fake or misleading',
        PopupReportReason.NOT_ALLOWED => 'Sells something not allowed',
        PopupReportReason.RUDE_OR_UNSAFE => 'Rude or unsafe',
        PopupReportReason.OTHER => 'Something else',
      };
}

// ignore: constant_identifier_names
enum PopupFilter { LIVE, REPORTED, SHOPS, ENDED, REMOVED }

/// The master controls for pop-up stalls.
class PopupSettings {
  const PopupSettings({
    required this.shopMaxLive,
    required this.shopFeePerDayMinor,
    required this.sellerMaxLive,
    required this.sellerFeePerDayMinor,
  });

  PopupSettings.fromJson(Json j)
      : shopMaxLive = (j['shopMaxLive'] as num).toInt(),
        shopFeePerDayMinor = (j['shopFeePerDayMinor'] as num).toInt(),
        sellerMaxLive = (j['sellerMaxLive'] as num).toInt(),
        sellerFeePerDayMinor = (j['sellerFeePerDayMinor'] as num).toInt();

  final int shopMaxLive;
  final int shopFeePerDayMinor;
  final int sellerMaxLive;
  final int sellerFeePerDayMinor;

  Json toJson() => {
        'shopMaxLive': shopMaxLive,
        'shopFeePerDayMinor': shopFeePerDayMinor,
        'sellerMaxLive': sellerMaxLive,
        'sellerFeePerDayMinor': sellerFeePerDayMinor,
      };
}

/// One seller's limits: an admin's choice (null = default) and what applies.
class SellerLimits {
  SellerLimits.fromJson(Json j)
      : userId = j['userId'] as String,
        name = j['name'] as String?,
        phone = j['phone'] as String?,
        shopName = j['shopName'] as String?,
        maxLive = (j['maxLive'] as num?)?.toInt(),
        feePerDayMinor = (j['feePerDayMinor'] as num?)?.toInt(),
        effectiveMaxLive = (j['effectiveMaxLive'] as num).toInt(),
        effectiveFeePerDayMinor = (j['effectiveFeePerDayMinor'] as num).toInt();

  final String userId;
  final String? name;
  final String? phone;
  final String? shopName;
  final int? maxLive;
  final int? feePerDayMinor;
  final int effectiveMaxLive;
  final int effectiveFeePerDayMinor;
}

class PopupReportEntry {
  PopupReportEntry.fromJson(Json j)
      : reason = PopupReportReason.values.byName(j['reason'] as String),
        note = j['note'] as String?,
        createdAt = _date(j['createdAt'])!;

  final PopupReportReason reason;
  final String? note;
  final DateTime createdAt;
}

/// A stall in the admin website.
class AdminPopup {
  AdminPopup.fromJson(Json j)
      : id = j['id'] as String,
        sellerId = j['sellerId'] as String,
        sellerName = j['sellerName'] as String,
        phone = j['phone'] as String?,
        sellerBlocked = j['sellerBlocked'] as bool? ?? false,
        status = PopupStatus.values.byName(j['status'] as String),
        items = [for (final i in j['items'] as List) PopupItem.fromJson(i as Json)],
        latitude = _double(j['latitude']),
        longitude = _double(j['longitude']),
        days = (j['days'] as num).toInt(),
        startsAt = _date(j['startsAt'])!,
        endsAt = _date(j['endsAt'])!,
        stoppedAt = _date(j['stoppedAt']),
        removedAt = _date(j['removedAt']),
        removedReason = j['removedReason'] as String?,
        movedAt = _date(j['movedAt']),
        reportCount = (j['reportCount'] as num?)?.toInt() ?? 0,
        reports = [for (final r in j['reports'] as List? ?? const []) PopupReportEntry.fromJson(r as Json)],
        vendorId = j['vendorId'] as String?,
        vendorName = j['vendorName'] as String?,
        feeMinor = (j['feeMinor'] as num?)?.toInt() ?? 0,
        paymentProvider = j['paymentProvider'] as String?,
        paidAt = _date(j['paidAt']);

  final String id;
  final String sellerId;
  final String sellerName;
  final String? phone;
  final bool sellerBlocked;
  final PopupStatus status;
  final List<PopupItem> items;
  final double latitude;
  final double longitude;
  final int days;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? stoppedAt;
  final DateTime? removedAt;
  final String? removedReason;
  final DateTime? movedAt;
  final int reportCount;
  final List<PopupReportEntry> reports;
  final String? vendorId;
  final String? vendorName;
  final int feeMinor;

  /// SHOP_BALANCE when taken from the shop's balance, else the online provider.
  final String? paymentProvider;
  final DateTime? paidAt;
}
