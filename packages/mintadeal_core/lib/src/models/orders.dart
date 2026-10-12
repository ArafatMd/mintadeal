import 'enums.dart';
import 'models.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

List<T> _list<T>(Object? v, T Function(Json) f) => [for (final e in (v as List? ?? const [])) f(e as Json)];

class QuoteLine {
  QuoteLine.fromJson(Json j)
      : listingId = j['listingId'] as String,
        listingType = ListingType.parse(j['listingType']),
        title = j['title'] as String,
        imageUrl = j['imageUrl'] as String?,
        unitPriceMinor = _int(j['unitPriceMinor']),
        originalPriceMinor = _int(j['originalPriceMinor']),
        quantity = _int(j['quantity']),
        lineTotalMinor = _int(j['lineTotalMinor']),
        stockLeft = (j['stockLeft'] as num?)?.toInt(),
        problem = j['problem'] as String?;

  final String listingId;
  final ListingType listingType;
  final String title;
  final String? imageUrl;
  final int unitPriceMinor;
  final int originalPriceMinor;
  final int quantity;
  final int lineTotalMinor;
  final int? stockLeft;
  final String? problem;
}

class VendorRef {
  VendorRef.fromJson(Json j)
      : id = j['id'] as String,
        name = j['name'] as String,
        area = j['area'] as String?,
        logoUrl = j['logoUrl'] as String?,
        phone = j['phone'] as String?;

  final String id;
  final String name;
  final String? area;
  final String? logoUrl;
  final String? phone;
}

/// The items from one shop that become one order. Offers form their own group.
class QuoteGroup {
  QuoteGroup.fromJson(Json j)
      : key = j['key'] as String,
        vendor = VendorRef.fromJson(j['vendor'] as Json),
        kind = ListingType.parse(j['kind']),
        lines = _list(j['lines'], QuoteLine.fromJson),
        availableModes = [for (final m in j['availableModes'] as List) FulfilmentMode.parse(m)],
        selectedMode = j['selectedMode'] == null ? null : FulfilmentMode.parse(j['selectedMode']),
        itemsTotalMinor = _int(j['itemsTotalMinor']),
        deliveryFeeMinor = _int(j['deliveryFeeMinor']),
        totalMinor = _int(j['totalMinor']),
        minOrderMinor = _int(j['minOrderMinor']),
        problems = [for (final p in j['problems'] as List) '$p'];

  final String key;
  final VendorRef vendor;
  final ListingType kind;
  final List<QuoteLine> lines;
  final List<FulfilmentMode> availableModes;
  final FulfilmentMode? selectedMode;
  final int itemsTotalMinor;
  final int deliveryFeeMinor;
  final int totalMinor;
  final int minOrderMinor;
  final List<String> problems;
}

class Quote {
  Quote.fromJson(Json j)
      : groups = _list(j['groups'], QuoteGroup.fromJson),
        itemsTotalMinor = _int(j['itemsTotalMinor']),
        deliveryTotalMinor = _int(j['deliveryTotalMinor']),
        grandTotalMinor = _int(j['grandTotalMinor']),
        onlinePaymentAvailable = j['onlinePaymentAvailable'] as bool,
        payOnDeliveryAllowed = j['payOnDeliveryAllowed'] as bool,
        addressRequired = j['addressRequired'] as bool,
        problems = [for (final p in j['problems'] as List) '$p'],
        canPlace = j['canPlace'] as bool;

  final List<QuoteGroup> groups;
  final int itemsTotalMinor;
  final int deliveryTotalMinor;
  final int grandTotalMinor;
  final bool onlinePaymentAvailable;
  final bool payOnDeliveryAllowed;
  final bool addressRequired;
  final List<String> problems;
  final bool canPlace;
}

class DeliveryAddress {
  const DeliveryAddress({required this.line, required this.area, this.landmark, required this.lat, required this.lng});

  final String line;
  final String area;
  final String? landmark;
  final double lat;
  final double lng;

  Json toJson() => {'line': line, 'area': area, 'landmark': landmark, 'latitude': lat, 'longitude': lng};
}

class OrderSummary {
  OrderSummary.fromJson(Json j)
      : id = j['id'] as String,
        code = j['code'] as String,
        checkoutCode = j['checkoutCode'] as String,
        vendorId = j['vendorId'] as String,
        vendorName = j['vendorName'] as String,
        status = OrderStatus.parse(j['status']),
        fulfilmentMode = FulfilmentMode.parse(j['fulfilmentMode']),
        itemCount = _int(j['itemCount']),
        firstItemTitle = j['firstItemTitle'] as String?,
        totalMinor = _int(j['totalMinor']),
        paymentMethod = PaymentMethod.parse(j['paymentMethod']),
        paymentStatus = PaymentStatus.parse(j['paymentStatus']),
        acceptDeadline = _date(j['acceptDeadline']),
        createdAt = _date(j['createdAt'])!;

  final String id;
  final String code;
  final String checkoutCode;
  final String vendorId;
  final String vendorName;
  final OrderStatus status;
  final FulfilmentMode fulfilmentMode;
  final int itemCount;
  final String? firstItemTitle;
  final int totalMinor;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final DateTime? acceptDeadline;
  final DateTime createdAt;
}

class CheckoutResult {
  CheckoutResult.fromJson(Json j)
      : id = j['id'] as String,
        code = j['code'] as String,
        paymentMethod = PaymentMethod.parse(j['paymentMethod']),
        paymentStatus = PaymentStatus.parse(j['paymentStatus']),
        paymentUrl = j['paymentUrl'] as String?,
        paymentDeadline = _date(j['paymentDeadline']),
        grandTotalMinor = _int(j['grandTotalMinor']),
        orders = _list(j['orders'], OrderSummary.fromJson);

  final String id;
  final String code;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? paymentUrl;
  final DateTime? paymentDeadline;
  final int grandTotalMinor;
  final List<OrderSummary> orders;
}

class OrderLineItem {
  OrderLineItem.fromJson(Json j)
      : listingId = j['listingId'] as String,
        listingType = ListingType.parse(j['listingType']),
        title = j['title'] as String,
        imageUrl = j['imageUrl'] as String?,
        unitPriceMinor = _int(j['unitPriceMinor']),
        originalPriceMinor = _int(j['originalPriceMinor']),
        quantity = _int(j['quantity']),
        lineTotalMinor = _int(j['lineTotalMinor']);

  final String listingId;
  final ListingType listingType;
  final String title;
  final String? imageUrl;
  final int unitPriceMinor;
  final int originalPriceMinor;
  final int quantity;
  final int lineTotalMinor;
}

class OrderEventEntry {
  OrderEventEntry.fromJson(Json j)
      : status = OrderStatus.parse(j['status']),
        actorType = j['actorType'] as String,
        note = j['note'] as String?,
        createdAt = _date(j['createdAt'])!;

  final OrderStatus status;
  final String actorType;
  final String? note;
  final DateTime createdAt;
}

class Party {
  Party.fromJson(Json j)
      : name = j['name'] as String?,
        phone = j['phone'] as String?;

  final String? name;
  final String? phone;
}

class OrderDetail {
  OrderDetail.fromJson(Json j)
      : id = j['id'] as String,
        code = j['code'] as String,
        checkoutId = j['checkoutId'] as String,
        checkoutCode = j['checkoutCode'] as String,
        status = OrderStatus.parse(j['status']),
        fulfilmentMode = FulfilmentMode.parse(j['fulfilmentMode']),
        shop = Party.fromJson(j['shop'] as Json),
        vendorId = j['vendorId'] as String,
        shopAddress = j['shopArea'] as String?,
        customer = j['customer'] == null ? null : Party.fromJson(j['customer'] as Json),
        address = j['address'] == null
            ? null
            : DeliveryAddress(
                line: (j['address'] as Json)['line'] as String,
                area: (j['address'] as Json)['area'] as String,
                landmark: (j['address'] as Json)['landmark'] as String?,
                lat: ((j['address'] as Json)['latitude'] as num?)?.toDouble() ?? 0,
                lng: ((j['address'] as Json)['longitude'] as num?)?.toDouble() ?? 0,
              ),
        note = j['note'] as String?,
        lines = _list(j['lines'], OrderLineItem.fromJson),
        itemsTotalMinor = _int(j['itemsTotalMinor']),
        deliveryFeeMinor = _int(j['deliveryFeeMinor']),
        totalMinor = _int(j['totalMinor']),
        paymentMethod = PaymentMethod.parse(j['paymentMethod']),
        paymentStatus = PaymentStatus.parse(j['paymentStatus']),
        paymentUrl = j['paymentUrl'] as String?,
        acceptDeadline = _date(j['acceptDeadline']),
        cancelledBy = j['cancelledBy'] as String?,
        cancelReason = j['cancelReason'] as String?,
        refundStatus = j['refund'] == null ? null : RefundStatus.parse((j['refund'] as Json)['status']),
        refundAmountMinor = j['refund'] == null ? null : _int((j['refund'] as Json)['amountMinor']),
        events = _list(j['events'], OrderEventEntry.fromJson),
        actions = [for (final a in j['actions'] as List) OrderAction.parse(a)],
        createdAt = _date(j['createdAt'])!;

  final String id;
  final String code;
  final String checkoutId;
  final String checkoutCode;
  final OrderStatus status;
  final FulfilmentMode fulfilmentMode;
  final Party shop;
  final String vendorId;
  final String? shopAddress;
  final Party? customer;
  final DeliveryAddress? address;
  final String? note;
  final List<OrderLineItem> lines;
  final int itemsTotalMinor;
  final int deliveryFeeMinor;
  final int totalMinor;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? paymentUrl;
  final DateTime? acceptDeadline;
  final String? cancelledBy;
  final String? cancelReason;
  final RefundStatus? refundStatus;
  final int? refundAmountMinor;
  final List<OrderEventEntry> events;
  final List<OrderAction> actions;
  final DateTime createdAt;
}

class SecretState {
  SecretState.fromJson(Json j)
      : set = j['set'] as bool,
        hint = j['hint'] as String?;

  final bool set;
  final String? hint;
}

/// An integration as the admin website sees it. Secret values are never sent back, only whether they are set.
class IntegrationSettingView {
  IntegrationSettingView.fromJson(Json j)
      : provider = IntegrationProvider.parse((j['setting'] as Json)['provider']),
        enabled = (j['setting'] as Json)['enabled'] as bool,
        complete = (j['setting'] as Json)['complete'] as bool,
        config = ((j['setting'] as Json)['config'] as Json).map((k, v) => MapEntry(k, '${v ?? ''}')),
        secrets = ((j['setting'] as Json)['secrets'] as Json).map((k, v) => MapEntry(k, SecretState.fromJson(v as Json))),
        updatedAt = _date((j['setting'] as Json)['updatedAt']),
        info = (j['info'] as Json).map((k, v) => MapEntry(k, '${v ?? ''}'));

  final IntegrationProvider provider;
  final bool enabled;
  final bool complete;
  final Map<String, String> config;
  final Map<String, SecretState> secrets;
  final DateTime? updatedAt;
  final Map<String, String> info;
}

class VendorOrderCounts {
  VendorOrderCounts.fromJson(Json j)
      : newOrders = _int(j['newOrders']),
        activeOrders = _int(j['activeOrders']);

  final int newOrders;
  final int activeOrders;
}
