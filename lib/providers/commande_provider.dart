import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/models/commande.dart';
import 'package:paragalien/providers/produit_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/core/constants.dart';
import 'package:paragalien/models/profile.dart';

// 1. Orders Provider (User-specific)
final userCommandesProvider = FutureProvider.autoDispose
    .family<List<Commande>, String>((ref, userId) async {
      final res = await Supabase.instance.client
          .from(SupabaseConstants.ordersTable)
          .select('*, commande_items(*, produits(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return res.map((o) => Commande.fromJson(o)).toList();
    });

// 2. All Orders Provider (Admin)
final allCommandesProvider = FutureProvider.autoDispose<List<Commande>>((
  ref,
) async {
  final res = await Supabase.instance.client
      .from(SupabaseConstants.ordersTable)
      .select('''
        *, 
        commande_items(*, produits(*)),
        profiles:profiles(*)
      ''') // Join with profiles table
      .order('created_at', ascending: false);

  return res.map((o) {
    // Add user profile to the commande
    final commande = Commande.fromJson(o);
    if (o['profiles'] != null) {
      commande.userProfile = Profile.fromJson(o['profiles']);
    }
    return commande;
  }).toList();
});

// 3. Order Notifier Provider
final commandeNotifierProvider = Provider<CommandeNotifier>(
  (ref) => CommandeNotifier(),
);

class CommandeNotifier {
  final client = Supabase.instance.client;

  

  // User submits order
  Future<void> submitOrder(
    List<SelectedProduct> products,
    String userId,
  ) async {
    final orderRes =
        await client
            .from('commandes')
            .insert({'user_id': userId, 'is_approved': false})
            .select()
            .single();

    await client
        .from('commande_items')
        .insert(
          products
              .map(
                (p) => {
                  'commande_id': orderRes['id'],
                  'produit_id': p.produit.id,
                  'quantity': p.quantity,
                  'price_at_order': p.produit.price,
                },
              )
              .toList(),
        );
  }



  Future<void> submitOrderWithNotes(
    List<SelectedProduct> products,
    String userId,
    String? note,
  ) async {
    final orderRes = await client
        .from('commandes')
        .insert({
          'user_id': userId,
          'is_approved': false,
          'client_notes': note?.isNotEmpty == true ? note : null,
        })
        .select()
        .single();

    await client.from('commande_items').insert(
      products.map((p) => {
        'commande_id': orderRes['id'],
        'produit_id': p.produit.id,
        'quantity': p.quantity,
        'price_at_order': p.produit.price,
      }).toList(),
    );
  }



  

  // Admin approves order and updates stock
  Future<void> approveOrder(int orderId) async {
  try {
    // Get full order details
    final order = await getOrderById(orderId);

    // Update product quantities (will allow negative stock)
    for (final item in order.items) {
      // Get current stock first
      final product = await client
          .from('produits')
          .select('"Stock ( Unité )"')
          .eq('id', item.produit.id)
          .single();

      final currentStock = (product['Stock ( Unité )'] as num).toDouble();
      final newStock = currentStock - item.quantity;

      await client
          .from('produits')
          .update({
            'Stock ( Unité )': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', item.produit.id);
    }

    // Mark order as approved
    await client
        .from('commandes')
        .update({
          'is_approved': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);

  } catch (e) {
    rethrow;
  }
}

  Future<Commande> getOrderById(int orderId) async {
    final res =
        await client
            .from('commandes')
            .select('*, commande_items(*, produits(*))')
            .eq('id', orderId)
            .single();
    return Commande.fromJson(res);
  }

 Future<void> deleteOrdersOlderThan(DateTime cutoffDate) async {
  final supabase = Supabase.instance.client;
  
  await supabase
    .from('commandes')
    .delete()
    .lt('created_at', cutoffDate.toIso8601String());
}
}
