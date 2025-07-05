import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/models/produit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/core/constants.dart';

class SelectedProduct {
  final Produit produit;
  final double quantity;

  SelectedProduct(this.produit, this.quantity);

  Map<String, dynamic> toMap() {
    return {'produit': produit.toMap(), 'quantity': quantity};
  }

  SelectedProduct copyWith({Produit? produit, double? quantity}) {
    return SelectedProduct(produit ?? this.produit, quantity ?? this.quantity);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedProduct &&
          produit == other.produit &&
          quantity == other.quantity;

  @override
  int get hashCode => produit.hashCode ^ quantity.hashCode;
}




final produitsProvider = FutureProvider.autoDispose<List<Produit>>((ref) async {
  final res = await Supabase.instance.client
      .from(SupabaseConstants.productsTable)
      .select()
      .order('name', ascending: true);

  // Convert all results to Produit objects
  final allProducts = res.map((p) => Produit.fromJson(p)).toList();

  // Filter to keep only products with:
  // 1. Unique names
  // 2. Price > 0
  // Don't filter by quantity here - we'll handle that in the UI
  final uniqueProducts = <Produit>[];
  final seenNames = <String>{};

  for (final product in allProducts) {
    if (!seenNames.contains(product.name) && product.price > 0) {
      seenNames.add(product.name);
      uniqueProducts.add(product);
    }
  }

  return uniqueProducts;
});

final selectedProduitsProvider =
    StateNotifierProvider<SelectedProduitsNotifier, List<SelectedProduct>>(
      (ref) => SelectedProduitsNotifier(),
    );

class SelectedProduitsNotifier extends StateNotifier<List<SelectedProduct>> {
  SelectedProduitsNotifier() : super([]);


  void updateProduct(SelectedProduct updatedProduct) {
  state = [
    for (final product in state)
      if (product.produit.id == updatedProduct.produit.id) updatedProduct else product
  ];
}

  void add(Produit produit, double quantity) {
    final existingIndex = state.indexWhere((sp) => sp.produit.id == produit.id);

    if (existingIndex >= 0) {
      state = [
        ...state.sublist(0, existingIndex),
        state[existingIndex].copyWith(
          quantity: state[existingIndex].quantity + quantity,
        ),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, SelectedProduct(produit, quantity)];
    }
  }

  void remove(Produit produit) {
    state = state.where((sp) => sp.produit.id != produit.id).toList();
  }

  void clear() {
    state = [];
  }

  double getTotalPrice() {
    return state.fold(0.0, (sum, sp) => sum + (sp.produit.price * sp.quantity));
  }

  bool containsProduct(Produit produit) {
    return state.any((sp) => sp.produit.id == produit.id);
  }
}
