import 'package:nomowear/features/orders/data/models/order_history.dart';

class OrdersCache {
  OrdersCache._();

  static final OrdersCache instance = OrdersCache._();

  List<OrderHistoryItem> _orders = const [];

  List<OrderHistoryItem> get orders => List.unmodifiable(_orders);

  void setOrders(List<OrderHistoryItem> orders) {
    _orders = List<OrderHistoryItem>.from(orders);
  }

  void upsertOrder(OrderHistoryItem order) {
    final index = _orders.indexWhere((item) => item.id == order.id);
    if (index >= 0) {
      final updated = List<OrderHistoryItem>.from(_orders);
      updated[index] = order;
      _orders = updated;
      return;
    }
    _orders = [order, ..._orders];
  }

  OrderHistoryItem? findById(String id) {
    for (final order in _orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  void clear() {
    _orders = const [];
  }
}
