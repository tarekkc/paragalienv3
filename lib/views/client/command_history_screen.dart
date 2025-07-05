import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/history_provider.dart';
import '../../models/orderhistory.dart';

class CommandHistoryScreen extends ConsumerWidget {
  final String userId;

  const CommandHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des commandes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(orderHistoryProvider(userId)),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading orders',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(orderHistoryProvider(userId)),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text('No orders found', style: TextStyle(fontSize: 18)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderHistoryProvider(userId));
              await ref.read(orderHistoryProvider(userId).future);
            },
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder:
                  (context, index) =>
                      _buildOrderCard(context, ref, orders[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    WidgetRef ref,
    OrderHistory order,
  ) {
    final total = order.items.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    final shortId =
        order.id.length > 8
            ? '${order.id.substring(0, 4)}...${order.id.substring(order.id.length - 4)}'
            : order.id;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOrderDetails(context, ref, order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'commande #$shortId',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text(
                      order.isApproved ? 'Approvée' : 'en attente',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor:
                        order.isApproved ? Colors.green : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM dd, yyyy - hh:mm a').format(order.date),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    NumberFormat.currency(
                      symbol: 'DA ',
                      decimalDigits: 2,
                    ).format(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(
    BuildContext context,
    WidgetRef ref,
    OrderHistory order,
  ) {
    final total = order.items.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    final shortId =
        order.id.length > 8
            ? '${order.id.substring(0, 4)}...${order.id.substring(order.id.length - 4)}'
            : order.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 70, 70, 70),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'commande #$shortId',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(order.date),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    order.isApproved ? 'Approvée avec ces modifications' : 'en attente',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor:
                      order.isApproved ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child:
                      order.items.isEmpty
                          ? const Center(child: Text('No items in this order'))
                          : ListView.builder(
                            itemCount: order.items.length,
                            itemBuilder:
                                (context, index) => _buildOrderItem(
                                  context,
                                  ref,
                                  order,
                                  order.items[index],
                                ),
                          ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ORDER TOTAL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                          symbol: 'DA ',
                          decimalDigits: 2,
                        ).format(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color.fromARGB(255, 161, 161, 161),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildOrderItem(
    BuildContext context,
    WidgetRef ref,
    OrderHistory order,
    OrderItem item,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 37, 37, 37),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name and Total Price
                Row(
                  children: [
                    // Product Name
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Unit Price and Quantity with Action Buttons
                Row(
                  children: [
                    // Unit Price and Quantity
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          Text(
                            '${item.price.toStringAsFixed(2)} DA/unité',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '×${item.quantity.toInt()}',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Action Buttons
                    if (!order.isApproved)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.blue.shade600,
                            ),
                            onPressed:
                                () => _showQuantityDialog(
                                  context,
                                  ref,
                                  order.id,
                                  item.id,
                                  item.quantity,
                                ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red.shade600,
                            ),
                            onPressed:
                                () => _showDeleteConfirmation(
                                  context,
                                  ref,
                                  order.id,
                                  item.id,
                                ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    String itemId,
    double currentQuantity,
  ) {
    final quantityController = TextEditingController(
      text: currentQuantity.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Modify Quantity'),
            content: TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final newQuantity =
                      double.tryParse(quantityController.text) ??
                      currentQuantity;
                  if (newQuantity > 0) {
                    await _updateQuantity(
                      context,
                      ref,
                      orderId,
                      itemId,
                      newQuantity,
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Quantity must be greater than 0'),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    String itemId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Item'),
            content: const Text(
              'Are you sure you want to remove this item from your order?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final params = OrderParams(orderId: orderId, userId: userId);
        final notifier = ref.read(orderModificationProvider(params).notifier);
        await notifier.removeItem(itemId);
        await notifier.recalculateOrderTotal();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed successfully')),
        );
        return true;
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        return false;
      }
    }
    return false;
  }

  Future<void> _updateQuantity(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    String itemId,
    double newQuantity,
  ) async {
    try {
      if (newQuantity <= 0) {
        await _showDeleteConfirmation(context, ref, orderId, itemId);
        return;
      }

      final params = OrderParams(orderId: orderId, userId: userId);
      final notifier = ref.read(orderModificationProvider(params).notifier);
      await notifier.updateItemQuantity(itemId, newQuantity);
      await notifier.recalculateOrderTotal();

      // Refresh the history
      ref.invalidate(orderHistoryProvider(userId));
      await ref.read(orderHistoryProvider(userId).future);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }
}
