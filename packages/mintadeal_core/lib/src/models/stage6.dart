import 'enums.dart';
import 'models.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
int _int(Object? v) => (v as num?)?.toInt() ?? 0;

// --- Ratings ---

class Review {
  Review.fromJson(Json j)
      : id = j['id'] as String,
        rating = _int(j['rating']),
        comment = j['comment'] as String?,
        customerName = j['customerName'] as String? ?? 'A customer',
        reply = j['reply'] as String?,
        createdAt = _date(j['createdAt'])!,
        orderCode = j['orderCode'] as String?,
        mine = j['mine'] as bool? ?? false;

  final String id;
  final int rating;
  final String? comment;
  final String customerName;

  /// The shop's reply, if it wrote one.
  final String? reply;
  final DateTime createdAt;
  final String? orderCode;
  final bool mine;
}

/// Whether the customer can rate an order, and their review if they already did.
class OrderReview {
  OrderReview.fromJson(Json j)
      : canReview = j['canReview'] as bool? ?? false,
        review = j['review'] == null ? null : Review.fromJson(j['review'] as Json);

  final bool canReview;
  final Review? review;
}

class AdminReview {
  AdminReview.fromJson(Json j)
      : id = j['id'] as String,
        vendorName = j['vendorName'] as String?,
        rating = _int(j['rating']),
        comment = j['comment'] as String?,
        customerPhone = j['customerPhone'] as String?,
        reply = j['reply'] as String?,
        orderCode = j['orderCode'] as String?,
        hidden = j['hidden'] as bool? ?? false,
        hiddenReason = j['hiddenReason'] as String?,
        createdAt = _date(j['createdAt'])!;

  final String id;
  final String? vendorName;
  final int rating;
  final String? comment;
  final String? customerPhone;
  final String? reply;
  final String? orderCode;
  final bool hidden;
  final String? hiddenReason;
  final DateTime createdAt;
}

// --- Help requests ---

class TicketSummary {
  TicketSummary.fromJson(Json j)
      : id = j['id'] as String,
        code = j['code'] as String,
        topic = TicketTopic.parse(j['topic']),
        subject = j['subject'] as String,
        status = TicketStatus.parse(j['status']),
        orderCode = j['orderCode'] as String?,
        openerRole = Role.parse(j['openerRole']),
        openerName = j['openerName'] as String?,
        openerPhone = j['openerPhone'] as String?,
        createdAt = _date(j['createdAt'])!,
        lastMessageAt = _date(j['lastMessageAt'])!;

  final String id;
  final String code;
  final TicketTopic topic;
  final String subject;
  final TicketStatus status;
  final String? orderCode;
  final Role openerRole;
  final String? openerName;
  final String? openerPhone;
  final DateTime createdAt;
  final DateTime lastMessageAt;
}

class TicketMessage {
  TicketMessage.fromJson(Json j)
      : id = j['id'] as String,
        staff = j['staff'] as bool? ?? false,
        authorName = j['authorName'] as String?,
        body = j['body'] as String,
        createdAt = _date(j['createdAt'])!;

  final String id;
  final bool staff;
  final String? authorName;
  final String body;
  final DateTime createdAt;
}

class TicketDetail {
  TicketDetail.fromJson(Json j)
      : ticket = TicketSummary.fromJson(j['ticket'] as Json),
        orderId = j['orderId'] as String?,
        messages = [for (final m in j['messages'] as List) TicketMessage.fromJson(m as Json)];

  final TicketSummary ticket;
  final String? orderId;
  final List<TicketMessage> messages;
}

// --- Stats ---

/// One day of orders and their value.
class DayStat {
  DayStat.fromJson(Json j)
      : date = DateTime.parse(j['date'] as String),
        orders = _int(j['orders']),
        valueMinor = _int(j['valueMinor']);

  final DateTime date;
  final int orders;
  final int valueMinor;
}

class AdminOverview {
  AdminOverview.fromJson(Json j)
      : ordersToday = _int(j['ordersToday']),
        completedToday = _int(j['completedToday']),
        cancelledToday = _int(j['cancelledToday']),
        valueTodayMinor = _int(j['valueTodayMinor']),
        last7Days = [for (final d in j['last7Days'] as List) DayStat.fromJson(d as Json)],
        liveShops = _int(j['liveShops']),
        customers = _int(j['customers']),
        newCustomersThisWeek = _int(j['newCustomersThisWeek']),
        openTickets = _int((j['attention'] as Json)['openTickets']),
        ordersWaitingForShop = _int((j['attention'] as Json)['ordersWaitingForShop']),
        jobsWaitingForRider = _int((j['attention'] as Json)['jobsWaitingForRider']),
        failedNotifications24h = _int((j['attention'] as Json)['failedNotifications24h']),
        failedRefunds = _int((j['attention'] as Json)['failedRefunds']),
        failedPayouts = _int((j['attention'] as Json)['failedPayouts']),
        shopsWaitingForReview = _int((j['attention'] as Json)['shopsWaitingForReview']);

  final int ordersToday;
  final int completedToday;
  final int cancelledToday;
  final int valueTodayMinor;
  final List<DayStat> last7Days;
  final int liveShops;
  final int customers;
  final int newCustomersThisWeek;
  final int openTickets;
  final int ordersWaitingForShop;
  final int jobsWaitingForRider;
  final int failedNotifications24h;
  final int failedRefunds;
  final int failedPayouts;
  final int shopsWaitingForReview;
}

class TopItem {
  TopItem.fromJson(Json j)
      : title = j['title'] as String,
        quantity = _int(j['quantity']),
        valueMinor = _int(j['valueMinor']);

  final String title;
  final int quantity;
  final int valueMinor;
}

class VendorStats {
  VendorStats.fromJson(Json j)
      : days = _int(j['days']),
        orders = _int(j['orders']),
        completed = _int(j['completed']),
        cancelledByShop = _int(j['cancelledByShop']),
        missed = _int(j['missed']),
        acceptanceRate = (j['acceptanceRate'] as num?)?.toDouble() ?? 0,
        avgAcceptMinutes = (j['avgAcceptMinutes'] as num?)?.toDouble(),
        salesMinor = _int(j['salesMinor']),
        avgOrderMinor = _int(j['avgOrderMinor']),
        rating = (j['rating'] as num?)?.toDouble(),
        ratingCount = _int(j['ratingCount']),
        followers = _int(j['followers']),
        topItems = [for (final t in j['topItems'] as List) TopItem.fromJson(t as Json)],
        daily = [for (final d in j['daily'] as List) DayStat.fromJson(d as Json)];

  final int days;
  final int orders;
  final int completed;
  final int cancelledByShop;

  /// Orders the shop did not answer in time.
  final int missed;
  final double acceptanceRate;
  final double? avgAcceptMinutes;
  final int salesMinor;
  final int avgOrderMinor;
  final double? rating;
  final int ratingCount;
  final int followers;
  final List<TopItem> topItems;
  final List<DayStat> daily;
}
