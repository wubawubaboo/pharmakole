import 'package:flutter/foundation.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() {
    return _instance;
  }
  CartService._internal();

  final List<Map<String, dynamic>> cart = [];
  bool isSenior = false;
  bool isPWD = false;

  Map<String, dynamic>? currentUser;

  void setUser(Map<String, dynamic> user) {
    currentUser = user;
  }

 


  final ValueNotifier<int> itemCount = ValueNotifier(0);

  void add(Map<String, dynamic> product) {
    final idx = cart.indexWhere((c) => c['product_id'] == product['id']);
    if (idx >= 0) {
      cart[idx]['quantity'] += 1;
    } else {
      cart.add({
        'product_id': product['id'],
        'name': product['name'],
        'unit_price': (product['unit_price'] ?? product['price'] ?? 0),
        'quantity': 1
      });
    }
    _updateCount();
  }

  void remove(int index) {
    cart.removeAt(index);
    _updateCount();
  }

  void updateQuantity(int index, int newQty) {
    if (newQty > 0) {
      cart[index]['quantity'] = newQty;
    } else {
      remove(index);
    }
  }

  void clear() {
    cart.clear();
    isSenior = false;
    isPWD = false;

    _updateCount();
  }

  void _updateCount() {
    itemCount.value = cart.length;
  }

  double get subtotal => cart.fold(
      0.0,
      (s, it) =>
          s +
          ((double.tryParse(it['unit_price'].toString()) ?? 0.0) *
              it['quantity']));
  double get discountRate => (isSenior || isPWD) ? 0.20 : 0.0;
  double get discount => subtotal * discountRate;
  double get tax => (subtotal - discount) * 0.12;
  double get total => (subtotal - discount) + tax;
}