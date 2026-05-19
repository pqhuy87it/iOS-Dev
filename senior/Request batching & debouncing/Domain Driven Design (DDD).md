# Domain Driven Design (DDD) trong Flutter

## 1. DDD là gì — Tư duy cốt lõi

### Vấn đề DDD giải quyết

```
Thực tế phổ biến — Code tổ chức theo TECHNICAL layer:

  lib/
  ├── models/          ← 50+ files, đủ loại entity lẫn lộn
  │   ├── user.dart
  │   ├── product.dart
  │   ├── order.dart
  │   ├── payment.dart
  │   └── ...
  ├── services/        ← "God services" làm mọi thứ
  │   ├── api_service.dart        (3000 dòng)
  │   ├── database_service.dart   (2000 dòng)
  │   └── auth_service.dart       (1500 dòng)
  ├── providers/
  ├── screens/
  └── widgets/

  Hậu quả:
  • Thêm feature mới → sửa 10+ files across nhiều folders
  • "Order" dùng chung cho: hiển thị list, tạo order, tracking, refund
  • Business logic nằm rải rác trong UI, service, model
  • 2 developer sửa cùng api_service.dart → merge conflict liên tục
  • Không ai hiểu "quy trình tạo đơn hàng" nằm ở đâu
```

```
DDD — Code tổ chức theo BUSINESS DOMAIN:

  lib/
  ├── features/
  │   ├── auth/           ← Mọi thứ liên quan authentication
  │   ├── catalog/        ← Browsing, search, product details
  │   ├── ordering/       ← Tạo order, cart, checkout
  │   ├── payment/        ← Payment processing
  │   ├── delivery/       ← Tracking, shipping
  │   └── profile/        ← User profile, preferences
  │
  │ Mỗi feature chứa đầy đủ layers bên trong

  Lợi ích:
  • Thêm feature "refund" → tạo folder mới, không sửa code cũ
  • Developer A làm ordering, Developer B làm payment → zero conflict
  • Business nói "sửa quy trình checkout" → mở folder ordering/
  • Mỗi domain có model riêng, phù hợp context riêng
```

### Triết lý cốt lõi

DDD không phải là folder structure. Đó chỉ là biểu hiện bên ngoài. Bản chất của DDD là:

**Code phải phản ánh cách business nghĩ về vấn đề, không phải cách developer nghĩ về technology.**

Khi Product Manager nói "Khách hàng đặt đơn hàng, hệ thống kiểm tra tồn kho, tính phí vận chuyển, rồi xác nhận thanh toán" → code phải đọc được gần giống như vậy, không phải `apiService.post('/orders', data)`.

---

## 2. Ubiquitous Language — Nền tảng mọi thứ

### Khái niệm

Ubiquitous Language là **ngôn ngữ chung** giữa developer, PM, designer, business stakeholder. Cùng một từ phải có cùng một nghĩa ở mọi nơi: trong meeting, trong Jira ticket, trong code, trong database.

```dart
// ❌ Developer đặt tên theo kỹ thuật, business không hiểu
class DataModel {
  final String str1;      // product name
  final double val1;      // price
  final int flag;         // status: 0=pending, 1=confirmed, 2=shipped
  final String refId;     // customer ID
}

void processItem(DataModel d) {
  if (d.flag == 0) {
    updateDB(d.str1, d.val1);
    sendNotification(d.refId);
  }
}

// ✅ Code dùng ngôn ngữ business
class Order {
  final ProductName productName;
  final Money price;
  final OrderStatus status;
  final CustomerId customerId;
}

void confirmOrder(Order order) {
  if (order.status == OrderStatus.pendingConfirmation) {
    order.confirm();
    notifyCustomer(order.customerId);
  }
}

// PM đọc code: "À, confirm order khi status là pending confirmation,
// rồi notify customer" → HIỂU ĐƯỢC
```

### Thực hành trong Flutter project

```dart
// Buổi họp với PM:
// "Khi rider ACCEPT một delivery, hệ thống phải CHECK
// rider đang không có active delivery nào khác.
// Nếu ok thì ASSIGN delivery cho rider và NOTIFY customer."

// Code phản ánh 1:1 ngôn ngữ trên:

class DeliveryService {
  Result<Delivery, DeliveryError> acceptDelivery({
    required Rider rider,
    required Delivery delivery,
  }) {
    // "check rider đang không có active delivery nào khác"
    if (rider.hasActiveDelivery) {
      return Failure(DeliveryError.riderAlreadyBusy);
    }

    // "assign delivery cho rider"
    final assigned = delivery.assignTo(rider);

    // "notify customer"
    _notificationService.notifyCustomer(
      delivery.customer,
      event: DeliveryEvent.riderAssigned(rider),
    );

    return Success(assigned);
  }
}
```

---

## 3. Strategic Design — Bounded Context

### Cùng một từ, khác nghĩa

```
"Product" nghĩa khác nhau tùy context:

  ┌─ Catalog Context ──────────────┐
  │ Product:                       │
  │   • name, description          │
  │   • images, categories         │
  │   • ratings, reviews           │
  │   • SEO metadata               │
  │                                │
  │ Quan tâm: hiển thị, tìm kiếm  │
  └────────────────────────────────┘

  ┌─ Ordering Context ─────────────┐
  │ Product:                       │
  │   • productId, name (tóm tắt)  │
  │   • unitPrice, quantity        │
  │   • discount applied           │
  │                                │
  │ Quan tâm: tính tiền, số lượng  │
  └────────────────────────────────┘

  ┌─ Inventory Context ────────────┐
  │ Product:                       │
  │   • SKU, warehouseLocation     │
  │   • stockCount, reorderLevel   │
  │   • supplier info              │
  │                                │
  │ Quan tâm: tồn kho, nhập hàng  │
  └────────────────────────────────┘

  ┌─ Delivery Context ─────────────┐
  │ Product:                       │
  │   • weight, dimensions         │
  │   • fragile flag               │
  │   • packaging requirements     │
  │                                │
  │ Quan tâm: vận chuyển, đóng gói │
  └────────────────────────────────┘
```

**Nếu dùng 1 class `Product` chung cho tất cả** → class phình to, mọi thay đổi ở 1 context ảnh hưởng tất cả context khác. DDD giải quyết bằng **Bounded Context**: mỗi context có model riêng, chỉ chứa thông tin context đó cần.

### Flutter project structure theo Bounded Context

```
lib/
├── core/                              ← Shared infrastructure
│   ├── network/
│   ├── storage/
│   └── errors/
│
├── features/
│   ├── catalog/                       ← Bounded Context: Catalog
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── catalog_product.dart    ← Product TRONG catalog
│   │   │   ├── value_objects/
│   │   │   │   ├── product_name.dart
│   │   │   │   └── rating.dart
│   │   │   ├── repositories/
│   │   │   │   └── catalog_repository.dart
│   │   │   └── services/
│   │   │       └── search_service.dart
│   │   ├── application/
│   │   │   └── catalog_bloc.dart
│   │   ├── infrastructure/
│   │   │   ├── catalog_repository_impl.dart
│   │   │   └── catalog_api.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       └── widgets/
│   │
│   ├── ordering/                      ← Bounded Context: Ordering
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── order.dart
│   │   │   │   └── order_item.dart         ← Product TRONG order
│   │   │   ├── value_objects/
│   │   │   │   ├── money.dart
│   │   │   │   └── quantity.dart
│   │   │   ├── repositories/
│   │   │   └── services/
│   │   │       └── pricing_service.dart
│   │   ├── application/
│   │   ├── infrastructure/
│   │   └── presentation/
│   │
│   └── delivery/                      ← Bounded Context: Delivery
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── delivery.dart
│       │   │   └── package_item.dart       ← Product TRONG delivery
│       │   └── ...
│       └── ...
```

---

## 4. Layered Architecture — Bên trong mỗi Bounded Context

### 4 layers

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION                              │
│  Pages, Widgets, BLoC/Cubit/Riverpod                        │
│  Hiển thị UI, nhận user input                               │
│  Chỉ biết Application layer, KHÔNG biết Infrastructure     │
├─────────────────────────────────────────────────────────────┤
│                    APPLICATION                               │
│  Use Cases, BLoC logic, Orchestration                       │
│  Điều phối business flow, KHÔNG chứa business rules        │
│  Gọi Domain objects để thực hiện logic                      │
├─────────────────────────────────────────────────────────────┤
│                      DOMAIN                                  │
│  Entities, Value Objects, Domain Services, Repository       │
│  interfaces (abstract)                                       │
│  ★ TRÁI TIM của app — business rules sống ở đây ★          │
│  KHÔNG phụ thuộc vào bất kỳ layer nào khác                  │
│  KHÔNG import Flutter, HTTP, Database packages              │
├─────────────────────────────────────────────────────────────┤
│                   INFRASTRUCTURE                             │
│  Repository implementations, API clients, Database          │
│  DTOs, Mappers                                               │
│  Implement interfaces mà Domain layer định nghĩa           │
└─────────────────────────────────────────────────────────────┘

Dependency direction (CHỈ đi xuống, KHÔNG đi lên):

  Presentation ──▶ Application ──▶ Domain ◀── Infrastructure
                                     ▲              │
                                     └──────────────┘
                                   (implement interface)
                                   
  Domain KHÔNG phụ thuộc ai → dễ test, dễ thay đổi
  Infrastructure phụ thuộc Domain (Dependency Inversion)
```

---

## 5. Domain Layer — Chi tiết từng building block

### Entity — Có identity, có lifecycle

```dart
// Entity: phân biệt bằng ID, có thể thay đổi state theo thời gian
// 2 Order khác nhau dù cùng nội dung → vì ID khác

import 'package:equatable/equatable.dart';

class Order extends Equatable {
  final OrderId id;
  final CustomerId customerId;
  final List<OrderItem> items;
  final OrderStatus status;
  final Money totalAmount;
  final DateTime createdAt;
  final ShippingAddress? shippingAddress;

  const Order._({
    required this.id,
    required this.customerId,
    required this.items,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.shippingAddress,
  });

  // Factory: business rules cho việc TẠO order
  factory Order.create({
    required CustomerId customerId,
    required List<OrderItem> items,
  }) {
    if (items.isEmpty) {
      throw DomainException('Order must have at least one item');
    }

    final total = items.fold(
      Money.zero,
      (sum, item) => sum + item.subtotal,
    );

    return Order._(
      id: OrderId.generate(),
      customerId: customerId,
      items: List.unmodifiable(items),
      status: OrderStatus.draft,
      totalAmount: total,
      createdAt: DateTime.now(),
    );
  }

  // Business method: LOGIC nằm trong Entity, không phải Service
  Order addItem(OrderItem item) {
    if (status != OrderStatus.draft) {
      throw DomainException('Can only add items to draft orders');
    }

    final updatedItems = [...items, item];
    final newTotal = updatedItems.fold(
      Money.zero,
      (sum, item) => sum + item.subtotal,
    );

    return _copyWith(items: updatedItems, totalAmount: newTotal);
  }

  Order removeItem(ProductId productId) {
    if (status != OrderStatus.draft) {
      throw DomainException('Can only remove items from draft orders');
    }

    final updatedItems = items.where((i) => i.productId != productId).toList();
    if (updatedItems.isEmpty) {
      throw DomainException('Order must have at least one item');
    }

    final newTotal = updatedItems.fold(
      Money.zero,
      (sum, item) => sum + item.subtotal,
    );

    return _copyWith(items: updatedItems, totalAmount: newTotal);
  }

  // Transition logic: Order chỉ có thể đi theo flow hợp lệ
  // draft → confirmed → paid → shipped → delivered
  //                           → cancelled (từ confirmed hoặc paid)
  Order confirm() {
    if (status != OrderStatus.draft) {
      throw DomainException('Can only confirm draft orders');
    }
    if (shippingAddress == null) {
      throw DomainException('Shipping address required before confirmation');
    }
    return _copyWith(status: OrderStatus.confirmed);
  }

  Order markPaid() {
    if (status != OrderStatus.confirmed) {
      throw DomainException('Can only pay for confirmed orders');
    }
    return _copyWith(status: OrderStatus.paid);
  }

  Order cancel() {
    if (!status.isCancellable) {
      throw DomainException('Order in status ${status.name} cannot be cancelled');
    }
    return _copyWith(status: OrderStatus.cancelled);
  }

  Order _copyWith({
    List<OrderItem>? items,
    OrderStatus? status,
    Money? totalAmount,
    ShippingAddress? shippingAddress,
  }) {
    return Order._(
      id: id,
      customerId: customerId,
      items: items ?? this.items,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt,
      shippingAddress: shippingAddress ?? this.shippingAddress,
    );
  }

  // Equatable: Entity so sánh bằng ID, không phải value
  @override
  List<Object?> get props => [id];
}

enum OrderStatus {
  draft,
  confirmed,
  paid,
  shipped,
  delivered,
  cancelled;

  bool get isCancellable => this == confirmed || this == paid;
}
```

### Value Object — Không có identity, bất biến, self-validating

```dart
// Value Object: so sánh bằng VALUE, không có ID
// Money(100, 'VND') == Money(100, 'VND') → true
// Luôn immutable, luôn valid (validate trong constructor)

class Money extends Equatable {
  final double amount;
  final String currency;

  const Money._(this.amount, this.currency);

  factory Money(double amount, String currency) {
    if (amount < 0) {
      throw DomainException('Money amount cannot be negative');
    }
    if (currency.length != 3) {
      throw DomainException('Currency must be 3-letter ISO code');
    }
    return Money._(amount, currency.toUpperCase());
  }

  static const zero = Money._(0, 'VND');

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money._(amount + other.amount, currency);
  }

  Money operator *(int quantity) {
    return Money._(amount * quantity, currency);
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return amount > other.amount;
  }

  Money applyDiscount(Percentage discount) {
    final discounted = amount * (1 - discount.value / 100);
    return Money._(discounted, currency);
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw DomainException('Cannot operate on different currencies: $currency vs ${other.currency}');
    }
  }

  @override
  List<Object> get props => [amount, currency];

  @override
  String toString() => '$amount $currency';
}
```

```dart
// Thêm ví dụ Value Objects

class EmailAddress extends Equatable {
  final String value;

  factory EmailAddress(String input) {
    final trimmed = input.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(trimmed)) {
      throw DomainException('Invalid email: $input');
    }
    return EmailAddress._(trimmed.toLowerCase());
  }

  const EmailAddress._(this.value);

  @override
  List<Object> get props => [value];
}

class Quantity extends Equatable {
  final int value;

  factory Quantity(int value) {
    if (value <= 0) {
      throw DomainException('Quantity must be positive');
    }
    if (value > 9999) {
      throw DomainException('Quantity exceeds maximum');
    }
    return Quantity._(value);
  }

  const Quantity._(this.value);

  Quantity increment() => Quantity(value + 1);
  Quantity decrement() => Quantity(value - 1);

  @override
  List<Object> get props => [value];
}

class PhoneNumber extends Equatable {
  final String countryCode;
  final String number;

  factory PhoneNumber({required String countryCode, required String number}) {
    final cleanNumber = number.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length < 9 || cleanNumber.length > 11) {
      throw DomainException('Invalid phone number length');
    }
    return PhoneNumber._(countryCode, cleanNumber);
  }

  const PhoneNumber._(this.countryCode, this.number);

  String get formatted => '+$countryCode $number';

  @override
  List<Object> get props => [countryCode, number];
}
```

**Tại sao không dùng `String` và `double` trực tiếp?**

```dart
// ❌ Primitive obsession — bug dễ xảy ra
void createOrder(String email, double amount, String currency, int qty) {
  // Có thể gọi: createOrder("invalid", -100, "X", 0)
  // Không ai validate, bug chỉ phát hiện khi runtime crash
  // Dễ nhầm thứ tự: createOrder("VND", 100, "user@email.com", 1)
}

// ✅ Value Objects — compiler giúp bắt lỗi
void createOrder(EmailAddress email, Money amount, Quantity qty) {
  // Không thể tạo EmailAddress invalid → DomainException ngay
  // Không thể tạo Money âm → DomainException ngay  
  // Không thể nhầm thứ tự email vs money → type system bắt
}
```

### Aggregate — Ranh giới nhất quán

```dart
// Aggregate: nhóm Entities + Value Objects phải nhất quán cùng lúc
// Order là Aggregate Root
// OrderItem là Entity thuộc Order aggregate
// Mọi thay đổi OrderItem PHẢI đi qua Order

// ❌ Sai: sửa OrderItem trực tiếp từ bên ngoài
orderItem.quantity = Quantity(5);  // Ai cập nhật totalAmount?

// ✅ Đúng: sửa qua Aggregate Root
final updatedOrder = order.updateItemQuantity(
  productId: productId,
  newQuantity: Quantity(5),
);
// Order.updateItemQuantity tự recalculate totalAmount

class Order extends Equatable {
  // ... (properties như trên)

  Order updateItemQuantity({
    required ProductId productId,
    required Quantity newQuantity,
  }) {
    if (status != OrderStatus.draft) {
      throw DomainException('Can only modify draft orders');
    }

    final updatedItems = items.map((item) {
      if (item.productId == productId) {
        return item.copyWith(quantity: newQuantity);
      }
      return item;
    }).toList();

    // Aggregate Root đảm bảo tính nhất quán:
    // Khi quantity thay đổi → totalAmount PHẢI được recalculate
    final newTotal = updatedItems.fold(
      Money.zero,
      (sum, item) => sum + item.subtotal,
    );

    return _copyWith(items: updatedItems, totalAmount: newTotal);
  }
}
```

### Domain Service — Logic không thuộc về Entity nào

```dart
// Khi logic liên quan NHIỀU Aggregate → không thuộc về entity nào
// → Đặt vào Domain Service

// PricingService: tính giá liên quan Product, Customer, Promotion
class PricingService {
  Money calculateFinalPrice({
    required CatalogProduct product,
    required Customer customer,
    required Quantity quantity,
    List<Promotion> activePromotions = const [],
  }) {
    var price = product.basePrice * quantity.value;

    // Loyalty discount
    if (customer.tier == CustomerTier.gold) {
      price = price.applyDiscount(Percentage(5));
    } else if (customer.tier == CustomerTier.platinum) {
      price = price.applyDiscount(Percentage(10));
    }

    // Best promotion (không stack)
    final bestPromotion = activePromotions
        .where((p) => p.isApplicableTo(product))
        .fold<Percentage>(
          Percentage.zero,
          (best, p) => p.discount > best ? p.discount : best,
        );

    price = price.applyDiscount(bestPromotion);

    return price;
  }
}

// Shipping cost: liên quan Order, Address, ShippingProvider
class ShippingCostCalculator {
  Money calculate({
    required Order order,
    required ShippingAddress destination,
    required ShippingMethod method,
  }) {
    final totalWeight = order.items.fold(
      0.0,
      (sum, item) => sum + item.weight.inKg * item.quantity.value,
    );

    final baseRate = method.ratePerKg;
    final distanceFactor = _distanceFactor(destination.region);

    var cost = Money(totalWeight * baseRate.amount * distanceFactor, 'VND');

    // Free shipping cho order > 500K
    if (order.totalAmount > Money(500000, 'VND')) {
      cost = Money.zero;
    }

    return cost;
  }
}
```

### Repository Interface — Domain định nghĩa, Infrastructure implement

```dart
// Domain layer CHỈ định nghĩa interface (abstract class)
// KHÔNG biết data đến từ đâu (API? Database? File?)

abstract class OrderRepository {
  Future<Order?> findById(OrderId id);
  Future<List<Order>> findByCustomer(CustomerId customerId);
  Future<List<Order>> findPending();
  Future<void> save(Order order);
  Future<void> delete(OrderId id);
}

// Tại sao method names dùng ngôn ngữ domain (findById, save)
// thay vì technical (getFromApi, insertToDb)?
// → Domain không quan tâm HOW, chỉ quan tâm WHAT
```

### Domain Event — Giao tiếp giữa các Bounded Context

```dart
// Khi Order được confirm → các context khác cần biết
// KHÔNG gọi trực tiếp (tight coupling)
// Dùng Domain Event (loose coupling)

abstract class DomainEvent {
  final DateTime occurredAt;
  const DomainEvent({required this.occurredAt});
}

class OrderConfirmed extends DomainEvent {
  final OrderId orderId;
  final CustomerId customerId;
  final Money totalAmount;
  final List<OrderItemSummary> items;

  const OrderConfirmed({
    required this.orderId,
    required this.customerId,
    required this.totalAmount,
    required this.items,
    required super.occurredAt,
  });
}

class OrderCancelled extends DomainEvent {
  final OrderId orderId;
  final String reason;

  const OrderCancelled({
    required this.orderId,
    required this.reason,
    required super.occurredAt,
  });
}

// Các context khác lắng nghe event:
// Inventory context: OrderConfirmed → giảm stock
// Payment context: OrderConfirmed → tạo payment request
// Notification context: OrderConfirmed → gửi email cho customer
// Analytics context: OrderConfirmed → track conversion
```

---

## 6. Application Layer — Use Cases

### Orchestration, không chứa business logic

```dart
// Use Case: điều phối flow, gọi Domain objects làm việc
// KHÔNG chứa business rules (rules nằm trong Entity/Domain Service)

class PlaceOrderUseCase {
  final OrderRepository _orderRepository;
  final CustomerRepository _customerRepository;
  final InventoryService _inventoryService;
  final PricingService _pricingService;
  final EventBus _eventBus;

  PlaceOrderUseCase({
    required OrderRepository orderRepository,
    required CustomerRepository customerRepository,
    required InventoryService inventoryService,
    required PricingService pricingService,
    required EventBus eventBus,
  })  : _orderRepository = orderRepository,
        _customerRepository = customerRepository,
        _inventoryService = inventoryService,
        _pricingService = pricingService,
        _eventBus = eventBus;

  Future<Result<Order, OrderError>> execute(PlaceOrderCommand command) async {
    // 1. Load entities
    final customer = await _customerRepository.findById(command.customerId);
    if (customer == null) {
      return Failure(OrderError.customerNotFound);
    }

    // 2. Check inventory (Domain Service)
    for (final item in command.items) {
      final available = await _inventoryService.checkStock(
        item.productId,
        item.quantity,
      );
      if (!available) {
        return Failure(OrderError.outOfStock(item.productId));
      }
    }

    // 3. Calculate prices (Domain Service)
    final orderItems = command.items.map((item) {
      final price = _pricingService.calculateFinalPrice(
        product: item.product,
        customer: customer,
        quantity: item.quantity,
      );
      return OrderItem(
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: price,
      );
    }).toList();

    // 4. Create Order (Entity business logic)
    final order = Order.create(
      customerId: customer.id,
      items: orderItems,
    );

    // 5. Persist
    await _orderRepository.save(order);

    // 6. Publish domain event
    _eventBus.publish(OrderConfirmed(
      orderId: order.id,
      customerId: customer.id,
      totalAmount: order.totalAmount,
      items: order.items.map((i) => i.toSummary()).toList(),
      occurredAt: DateTime.now(),
    ));

    return Success(order);
  }
}

// Command: DTO cho input, KHÔNG phải domain object
class PlaceOrderCommand {
  final CustomerId customerId;
  final List<OrderItemInput> items;
  final ShippingAddress shippingAddress;

  const PlaceOrderCommand({
    required this.customerId,
    required this.items,
    required this.shippingAddress,
  });
}
```

### Tích hợp với BLoC

```dart
class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final PlaceOrderUseCase _placeOrder;
  final CancelOrderUseCase _cancelOrder;
  final GetOrderHistoryUseCase _getHistory;

  OrderBloc({
    required PlaceOrderUseCase placeOrder,
    required CancelOrderUseCase cancelOrder,
    required GetOrderHistoryUseCase getHistory,
  })  : _placeOrder = placeOrder,
        _cancelOrder = cancelOrder,
        _getHistory = getHistory,
        super(const OrderState.initial()) {
    on<PlaceOrderRequested>(_onPlaceOrder);
    on<CancelOrderRequested>(_onCancelOrder);
    on<OrderHistoryRequested>(_onLoadHistory);
  }

  Future<void> _onPlaceOrder(
    PlaceOrderRequested event,
    Emitter<OrderState> emit,
  ) async {
    emit(state.copyWith(status: OrderStatus.loading));

    final result = await _placeOrder.execute(
      PlaceOrderCommand(
        customerId: event.customerId,
        items: event.items,
        shippingAddress: event.shippingAddress,
      ),
    );

    result.when(
      success: (order) => emit(state.copyWith(
        status: OrderStatus.success,
        currentOrder: order,
      )),
      failure: (error) => emit(state.copyWith(
        status: OrderStatus.error,
        error: error,
      )),
    );
  }
}
```

---

## 7. Infrastructure Layer — Implementation chi tiết

### Repository Implementation

```dart
class OrderRepositoryImpl implements OrderRepository {
  final OrderApi _api;
  final OrderLocalDataSource _localDb;
  final NetworkInfo _networkInfo;

  OrderRepositoryImpl({
    required OrderApi api,
    required OrderLocalDataSource localDb,
    required NetworkInfo networkInfo,
  })  : _api = api,
        _localDb = localDb,
        _networkInfo = networkInfo;

  @override
  Future<Order?> findById(OrderId id) async {
    if (await _networkInfo.isConnected) {
      try {
        final dto = await _api.getOrder(id.value);
        final order = OrderMapper.toDomain(dto);
        // Cache locally
        await _localDb.cacheOrder(dto);
        return order;
      } catch (e) {
        // Network error → fallback to local
        return _getFromLocal(id);
      }
    } else {
      return _getFromLocal(id);
    }
  }

  Future<Order?> _getFromLocal(OrderId id) async {
    final localDto = await _localDb.getOrder(id.value);
    return localDto != null ? OrderMapper.toDomain(localDto) : null;
  }

  @override
  Future<void> save(Order order) async {
    final dto = OrderMapper.toDto(order);

    if (await _networkInfo.isConnected) {
      final response = await _api.createOrder(dto);
      await _localDb.cacheOrder(response);
    } else {
      // Offline: lưu local + đánh dấu cần sync
      await _localDb.cacheOrder(dto);
      await _localDb.markPendingSync(order.id.value);
    }
  }
}
```

### DTO & Mapper — Tách biệt Domain khỏi API

```dart
// DTO: phản ánh structure của API response
// KHÔNG dùng trực tiếp trong Domain layer

class OrderDto {
  final String id;
  final String customer_id;      // snake_case từ API
  final List<OrderItemDto> items;
  final String status;
  final double total_amount;
  final String currency;
  final String created_at;

  OrderDto.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        customer_id = json['customer_id'],
        items = (json['items'] as List)
            .map((e) => OrderItemDto.fromJson(e))
            .toList(),
        status = json['status'],
        total_amount = (json['total_amount'] as num).toDouble(),
        currency = json['currency'],
        created_at = json['created_at'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customer_id,
        'items': items.map((e) => e.toJson()).toList(),
        'status': status,
        'total_amount': total_amount,
        'currency': currency,
        'created_at': created_at,
      };
}

// Mapper: chuyển đổi giữa DTO ↔ Domain
class OrderMapper {
  static Order toDomain(OrderDto dto) {
    return Order.reconstitute(
      id: OrderId(dto.id),
      customerId: CustomerId(dto.customer_id),
      items: dto.items.map(OrderItemMapper.toDomain).toList(),
      status: _mapStatus(dto.status),
      totalAmount: Money(dto.total_amount, dto.currency),
      createdAt: DateTime.parse(dto.created_at),
    );
  }

  static OrderDto toDto(Order order) {
    return OrderDto(
      id: order.id.value,
      customer_id: order.customerId.value,
      items: order.items.map(OrderItemMapper.toDto).toList(),
      status: order.status.name,
      total_amount: order.totalAmount.amount,
      currency: order.totalAmount.currency,
      created_at: order.createdAt.toIso8601String(),
    );
  }

  static OrderStatus _mapStatus(String raw) {
    return switch (raw) {
      'draft' => OrderStatus.draft,
      'confirmed' => OrderStatus.confirmed,
      'paid' => OrderStatus.paid,
      'shipped' => OrderStatus.shipped,
      'delivered' => OrderStatus.delivered,
      'cancelled' => OrderStatus.cancelled,
      _ => throw DomainException('Unknown order status: $raw'),
    };
  }
}
```

**Tại sao cần Mapper riêng thay vì `fromJson` trong Entity?**

```
Nếu Entity có fromJson:
  • Entity phụ thuộc vào API structure → API đổi field name = sửa Entity
  • Entity import dart:convert, json_annotation → domain "ô nhiễm"
  • Không test được Entity logic mà không mock JSON

Với Mapper riêng:
  • API đổi structure → chỉ sửa DTO + Mapper
  • Entity hoàn toàn pure Dart, không dependency ngoài
  • Test Entity bằng cách gọi constructor/factory trực tiếp
```

---

## 8. Kết nối các Bounded Context

### Anti-Corruption Layer

```dart
// Khi Ordering context cần data từ Catalog context
// KHÔNG import trực tiếp Catalog entities
// Dùng Anti-Corruption Layer để translate

// Trong ordering/domain/
abstract class ProductInfoProvider {
  Future<OrderProductInfo?> getProductInfo(ProductId id);
}

// Ordering context chỉ cần thông tin TỐI THIỂU
class OrderProductInfo {
  final ProductId id;
  final String name;
  final Money basePrice;
  final Weight weight;

  const OrderProductInfo({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.weight,
  });
}

// Trong ordering/infrastructure/
// Translate từ Catalog's CatalogProduct → Ordering's OrderProductInfo
class ProductInfoProviderImpl implements ProductInfoProvider {
  final CatalogRepository _catalogRepo;

  @override
  Future<OrderProductInfo?> getProductInfo(ProductId id) async {
    final catalogProduct = await _catalogRepo.findById(id);
    if (catalogProduct == null) return null;

    // Anti-Corruption: chỉ lấy data Ordering cần
    // Catalog thay đổi → chỉ sửa mapper này
    return OrderProductInfo(
      id: catalogProduct.id,
      name: catalogProduct.name.value,
      basePrice: catalogProduct.price,
      weight: catalogProduct.weight,
    );
  }
}
```

### Event-driven communication

```dart
// EventBus: loose coupling giữa contexts

class EventBus {
  final _controller = StreamController<DomainEvent>.broadcast();

  void publish(DomainEvent event) {
    _controller.add(event);
  }

  Stream<T> on<T extends DomainEvent>() {
    return _controller.stream.whereType<T>();
  }

  void dispose() {
    _controller.close();
  }
}

// Inventory context lắng nghe OrderConfirmed
class InventoryEventHandler {
  final InventoryRepository _repository;
  final EventBus _eventBus;
  late final StreamSubscription _subscription;

  InventoryEventHandler({
    required InventoryRepository repository,
    required EventBus eventBus,
  })  : _repository = repository,
        _eventBus = eventBus {
    _subscription = _eventBus.on<OrderConfirmed>().listen(_onOrderConfirmed);
  }

  Future<void> _onOrderConfirmed(OrderConfirmed event) async {
    for (final item in event.items) {
      await _repository.decreaseStock(
        item.productId,
        item.quantity,
      );
    }
  }

  void dispose() => _subscription.cancel();
}

// Notification context lắng nghe OrderConfirmed
class NotificationEventHandler {
  final NotificationService _notificationService;
  final EventBus _eventBus;

  // ...
  Future<void> _onOrderConfirmed(OrderConfirmed event) async {
    await _notificationService.send(
      to: event.customerId,
      message: 'Your order #${event.orderId.value} has been confirmed!',
    );
  }
}
```

---

## 9. Result Type — Error handling theo DDD

```dart
// Domain KHÔNG throw exception cho business errors
// Dùng Result type → explicit, compiler enforce handling

sealed class Result<T, E> {
  const Result();

  factory Result.success(T value) = Success<T, E>;
  factory Result.failure(E error) = Failure<T, E>;

  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  });
}

class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);

  @override
  R when<R>({
    required R Function(T) success,
    required R Function(E) failure,
  }) => success(value);
}

class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);

  @override
  R when<R>({
    required R Function(T) success,
    required R Function(E) failure,
  }) => failure(error);
}

// Domain errors: explicit, typed
enum OrderError {
  customerNotFound,
  outOfStock,
  paymentDeclined,
  invalidShippingAddress,
  orderAlreadyCancelled;

  String get message => switch (this) {
        customerNotFound => 'Customer not found',
        outOfStock => 'Product is out of stock',
        paymentDeclined => 'Payment was declined',
        invalidShippingAddress => 'Invalid shipping address',
        orderAlreadyCancelled => 'Order is already cancelled',
      };
}

// Usage trong UseCase
Future<Result<Order, OrderError>> execute(command) async {
  // ...
  if (!available) {
    return Result.failure(OrderError.outOfStock);
  }
  // ...
  return Result.success(order);
}

// Usage trong BLoC — PHẢI handle cả 2 case
result.when(
  success: (order) => emit(OrderLoaded(order)),
  failure: (error) => emit(OrderError(error.message)),
);
```

---

## 10. Dependency Injection — Wiring Everything

```dart
// get_it hoặc injectable package

final sl = GetIt.instance;

void setupDependencies() {
  // ── Core ──
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
  sl.registerLazySingleton<EventBus>(() => EventBus());

  // ── Ordering Context ──
  // Infrastructure
  sl.registerLazySingleton<OrderApi>(() => OrderApiImpl(sl()));
  sl.registerLazySingleton<OrderLocalDataSource>(
    () => OrderLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(
      api: sl(),
      localDb: sl(),
      networkInfo: sl(),
    ),
  );

  // Domain Services
  sl.registerLazySingleton(() => PricingService());
  sl.registerLazySingleton(() => ShippingCostCalculator());

  // Use Cases
  sl.registerFactory(() => PlaceOrderUseCase(
        orderRepository: sl(),
        customerRepository: sl(),
        inventoryService: sl(),
        pricingService: sl(),
        eventBus: sl(),
      ));

  // BLoC
  sl.registerFactory(() => OrderBloc(
        placeOrder: sl(),
        cancelOrder: sl(),
        getHistory: sl(),
      ));

  // ── Event Handlers (cross-context) ──
  sl.registerLazySingleton(() => InventoryEventHandler(
        repository: sl(),
        eventBus: sl(),
      ));
}
```

---

## 11. Testing — DDD giúp test dễ hơn

```dart
// Domain Entity test: KHÔNG cần mock gì cả
// Pure Dart, không dependency

void main() {
  group('Order', () {
    test('should calculate total from items', () {
      final order = Order.create(
        customerId: CustomerId('c1'),
        items: [
          OrderItem(
            productId: ProductId('p1'),
            productName: 'Widget',
            quantity: Quantity(2),
            unitPrice: Money(50000, 'VND'),
          ),
          OrderItem(
            productId: ProductId('p2'),
            productName: 'Gadget',
            quantity: Quantity(1),
            unitPrice: Money(100000, 'VND'),
          ),
        ],
      );

      expect(order.totalAmount, equals(Money(200000, 'VND')));
    });

    test('should not confirm without shipping address', () {
      final order = Order.create(
        customerId: CustomerId('c1'),
        items: [someItem],
      );

      expect(
        () => order.confirm(),
        throwsA(isA<DomainException>()),
      );
    });

    test('should follow valid status transitions', () {
      var order = Order.create(
        customerId: CustomerId('c1'),
        items: [someItem],
      ).copyWithAddress(someAddress);

      order = order.confirm();
      expect(order.status, OrderStatus.confirmed);

      order = order.markPaid();
      expect(order.status, OrderStatus.paid);

      // Cannot confirm a paid order
      expect(() => order.confirm(), throwsA(isA<DomainException>()));
    });
  });

  group('Money', () {
    test('should not allow negative amount', () {
      expect(() => Money(-100, 'VND'), throwsA(isA<DomainException>()));
    });

    test('should not add different currencies', () {
      final vnd = Money(100, 'VND');
      final usd = Money(5, 'USD');
      expect(() => vnd + usd, throwsA(isA<DomainException>()));
    });

    test('should apply discount correctly', () {
      final price = Money(200000, 'VND');
      final discounted = price.applyDiscount(Percentage(10));
      expect(discounted, equals(Money(180000, 'VND')));
    });
  });
}

// Use Case test: mock Repository, test orchestration logic
void main() {
  group('PlaceOrderUseCase', () {
    late PlaceOrderUseCase useCase;
    late MockOrderRepository mockOrderRepo;
    late MockCustomerRepository mockCustomerRepo;
    late MockInventoryService mockInventory;

    setUp(() {
      mockOrderRepo = MockOrderRepository();
      mockCustomerRepo = MockCustomerRepository();
      mockInventory = MockInventoryService();

      useCase = PlaceOrderUseCase(
        orderRepository: mockOrderRepo,
        customerRepository: mockCustomerRepo,
        inventoryService: mockInventory,
        pricingService: PricingService(), // Real — pure logic, no I/O
        eventBus: EventBus(),
      );
    });

    test('should fail when customer not found', () async {
      when(() => mockCustomerRepo.findById(any()))
          .thenAnswer((_) async => null);

      final result = await useCase.execute(someCommand);

      result.when(
        success: (_) => fail('Should have failed'),
        failure: (error) => expect(error, OrderError.customerNotFound),
      );

      verifyNever(() => mockOrderRepo.save(any()));
    });

    test('should fail when product out of stock', () async {
      when(() => mockCustomerRepo.findById(any()))
          .thenAnswer((_) async => someCustomer);
      when(() => mockInventory.checkStock(any(), any()))
          .thenAnswer((_) async => false);

      final result = await useCase.execute(someCommand);

      result.when(
        success: (_) => fail('Should have failed'),
        failure: (error) => expect(error, isA<OrderError>()),
      );
    });
  });
}
```

---

## 12. Tổng kết — Khi nào nên và không nên dùng DDD

```
┌─ DDD PHÙ HỢP khi ──────────────────────────────────────────┐
│                                                               │
│ • Business logic phức tạp (e-commerce, fintech, healthcare)  │
│ • Nhiều domain experts / stakeholders                         │
│ • App sẽ phát triển lâu dài (> 1 năm)                       │
│ • Team > 3 người, cần phân chia rõ ràng                      │
│ • Nhiều bounded contexts tương tác                            │
│ • Business rules thay đổi thường xuyên                       │
│                                                               │
└───────────────────────────────────────────────────────────────┘

┌─ DDD QUÁ MỨC CẦN THIẾT khi ────────────────────────────────┐
│                                                               │
│ • CRUD app đơn giản (todo, notes)                            │
│ • Prototype / MVP cần ship nhanh                              │
│ • Logic chủ yếu ở backend, app chỉ hiển thị                 │
│ • Team 1-2 người, ít budget                                  │
│ • App có lifecycle ngắn (event app, campaign)                │
│                                                               │
└───────────────────────────────────────────────────────────────┘

┌─ Áp dụng từng bước ────────────────────────────────────────┐
│                                                               │
│ Không cần "full DDD" ngay từ đầu:                            │
│                                                               │
│ Bước 1: Ubiquitous Language                                  │
│   → Đặt tên code giống cách business nói                     │
│                                                               │
│ Bước 2: Value Objects cho validation                          │
│   → Money, Email, PhoneNumber thay vì primitive types        │
│                                                               │
│ Bước 3: Repository pattern                                    │
│   → Tách data access khỏi business logic                     │
│                                                               │
│ Bước 4: Bounded Contexts khi app phình to                    │
│   → Tách module khi 2 team bắt đầu conflict                 │
│                                                               │
│ Bước 5: Full tactical patterns khi domain thực sự phức tạp  │
│   → Aggregates, Domain Events, Domain Services               │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

Điểm mấu chốt cho Senior: DDD không phải về folder structure hay design patterns — đó là cách **tư duy** về software. Core idea là: code phải phản ánh business reality, domain layer phải độc lập với mọi framework và infrastructure, và ranh giới giữa các context phải rõ ràng. Khi business nói một từ, developer phải hiểu cùng nghĩa, và code phải dùng cùng từ đó. Patterns (Entity, Value Object, Aggregate, Repository...) chỉ là công cụ phục vụ triết lý này.
