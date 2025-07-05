import '../models/orderhistory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final orderHistoryProvider = FutureProvider.autoDispose
    .family<List<OrderHistory>, String>((ref, userId) async {
  try {
    // MODIFICATION 7: Enhanced query to include admin profile information for approved orders
    final response = await Supabase.instance.client
        .from('commandes')
        .select('''
          id,
          created_at,
          is_approved,
          total,
          approved_by,
          approved_by_profile:profiles!approved_by(name),
          items:commande_items(
            id,
            produit:produits(
              name,
              Price
            ),
            quantity
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response.map<OrderHistory>((order) {
      try {
        return OrderHistory.fromJson(order);
      } catch (e) {
        print('Error parsing order: $e');
        return OrderHistory.empty();
      }
    }).toList();
  } catch (e) {
    print('Error fetching order history: $e');
    return [];
  }
});

final orderModificationProvider = StateNotifierProvider.autoDispose
    .family<OrderModificationNotifier, OrderHistory, OrderParams>((ref, params) {
  return OrderModificationNotifier(ref: ref, orderId: params.orderId, userId: params.userId);
});

class OrderParams {
  final String orderId;
  final String userId;

  OrderParams({required this.orderId, required this.userId});
}

class OrderModificationNotifier extends StateNotifier<OrderHistory> {
  final String orderId;
  final String userId;
  final Ref ref;
  final supabase = Supabase.instance.client;
  bool _isDisposed = false;

  OrderModificationNotifier({
    required this.ref,
    required this.orderId,
    required this.userId,
  }) : super(OrderHistory.empty()) {
    _loadOrder();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      // MODIFICATION 8: Enhanced query to include admin profile information when loading single order
      final response = await supabase
          .from('commandes')
          .select('''
            id,
            created_at,
            is_approved,
            total,
            approved_by,
            approved_by_profile:profiles!approved_by(name),
            items:commande_items(
              id,
              produit:produits(
                name,
                Price
              ),
              quantity
            )
          ''')
          .eq('id', orderId)
          .single();

      if (_isDisposed) return;
      state = OrderHistory.fromJson(response);
    } catch (e) {
      print('Error loading order: $e');
      if (!_isDisposed) {
        throw Exception('Failed to load order: ${e.toString()}');
      }
    }
  }

  void _refreshHistory() {
    if (!_isDisposed) {
      ref.invalidate(orderHistoryProvider(userId));
    }
  }

  Future<void> updateItemQuantity(String itemId, double newQuantity) async {
    if (_isDisposed) return;
    if (state.isApproved) {
      throw Exception('Cannot modify an approved order');
    }

    if (newQuantity <= 0) {
      await removeItem(itemId);
      return;
    }

    try {
      final response = await supabase
          .from('commande_items')
          .update({'quantity': newQuantity})
          .eq('id', itemId)
          .select();

      if (response.isEmpty) throw Exception('No rows affected');

      await _loadOrder();
      _refreshHistory();
    } catch (e) {
      print('Error updating item quantity: $e');
      throw Exception('Failed to update quantity: ${e.toString()}');
    }
  }

  Future<void> removeItem(String itemId) async {
    if (_isDisposed) return;
    if (state.isApproved) {
      throw Exception('Cannot modify an approved order');
    }

    try {
      final response = await supabase
          .from('commande_items')
          .delete()
          .eq('id', itemId)
          .select();

      if (response.isEmpty) throw Exception('No rows affected');

      await _loadOrder();
      _refreshHistory();
    } catch (e) {
      print('Error removing item: $e');
      throw Exception('Failed to remove item: ${e.toString()}');
    }
  }

  Future<void> recalculateOrderTotal() async {
    if (_isDisposed || state.isApproved) return;

    final newTotal = state.items.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    try {
      await supabase
          .from('commandes')
          .update({'total': newTotal})
          .eq('id', state.id);

      _refreshHistory();
    } catch (e) {
      print('Error updating order total: $e');
      throw Exception('Failed to update order total');
    }
  }
}