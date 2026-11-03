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
enum PopupStatus { LIVE, ENDED, REMOVED }

/// A stall as its seller sees it.
class MyPopup {
  MyPopup.fromJson(Json j)
      : id = j['id'] as String,
        status = PopupStatus.values.byName(j['status'] as String),
        items = [for (final i in j['items'] as List) PopupItem.fromJson(i as Json)],
        latitude = _double(j['latitude']),
        longitude = _double(j['longitude']),
        days = (j['days'] as num).toInt(),
        startsAt = _date(j['startsAt'])!,
        endsAt = _date(j['endsAt'])!,
        stoppedAt = _date(j['stoppedAt']),
        removedReason = j['removedReason'] as String?;

  final String id;
  final PopupStatus status;
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
        live = j['live'] == null ? null : MyPopup.fromJson(j['live'] as Json),
        history = [for (final p in j['history'] as List? ?? const []) MyPopup.fromJson(p as Json)],
        allowedDays = [for (final d in j['allowedDays'] as List? ?? const [1, 2, 3, 7]) (d as num).toInt()],
        defaultDays = (j['defaultDays'] as num?)?.toInt() ?? 2,
        maxItems = (j['maxItems'] as num?)?.toInt() ?? 6;

  /// Null until the person has opened their first stall.
  final String? name;
  final bool blocked;
  final String? blockedReason;
  final MyPopup? live;
  final List<MyPopup> history;
  final List<int> allowedDays;
  final int defaultDays;
  final int maxItems;
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
        endsAt = _date(j['endsAt'])!;

  final String id;
  final String sellerName;
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
enum PopupFilter { LIVE, REPORTED, ENDED, REMOVED }

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
        reports = [for (final r in j['reports'] as List? ?? const []) PopupReportEntry.fromJson(r as Json)];

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
}
