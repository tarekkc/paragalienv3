class OrderHistory {
  final String id;
  final DateTime date;
  final bool isApproved;
  final double total;
  final String? approvedBy; // MODIFICATION 3: This field already exists, keeping it as is
  final List<OrderItem> items;

  OrderHistory({
    required this.id,
    required this.date,
    required this.isApproved,
    required this.total,
    required this.items,
    this.approvedBy, // MODIFICATION 4: This field already exists, keeping it as is
  });

  factory OrderHistory.empty() => OrderHistory(
        id: '',
        date: DateTime.now(),
        isApproved: false,
        total: 0.0,
        items: [],
      );

  factory OrderHistory.fromJson(Map<String, dynamic> json) {
    try {
      return OrderHistory(
        id: json['id']?.toString() ?? '',
        date: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toString()),
        isApproved: _parseApprovalStatus(json['is_approved']),
        total: _parseDouble(json['total']),
        items: _parseItems(json['items']),
        // MODIFICATION 5: Enhanced parsing to get admin name from approved_by field or profiles join
        approvedBy: _parseApprovedBy(json),
      );
    } catch (e) {
      print('Error parsing OrderHistory: $e');
      print('Problematic JSON: $json');
      rethrow;
    }
  }

  // MODIFICATION 6: Added new method to parse approved by admin name
  static String? _parseApprovedBy(Map<String, dynamic> json) {
    // Try to get from direct approved_by field first
    if (json['approved_by'] != null) {
      return json['approved_by'].toString();
    }
    
    // Try to get from profiles join (if the query includes admin profile data)
    if (json['approved_by_profile'] != null && json['approved_by_profile']['name'] != null) {
      return json['approved_by_profile']['name'].toString();
    }
    
    // Try alternative field names that might be used
    if (json['admin_name'] != null) {
      return json['admin_name'].toString();
    }
    
    return null;
  }

  static bool _parseApprovalStatus(dynamic status) {
    if (status == null) return false;
    if (status is bool) return status;
    if (status is String) return status.toLowerCase() == 'true';
    return false;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static List<OrderItem> _parseItems(dynamic items) {
    if (items == null) return [];
    if (items is! List) return [];
    
    return items.map<OrderItem>((item) {
      try {
        if (item is Map<String, dynamic>) {
          return OrderItem.fromJson(item);
        }
        return OrderItem.empty();
      } catch (e) {
        print('Error parsing order item: $e');
        return OrderItem.empty();
      }
    }).toList();
  }
}

class OrderItem {
  final String id;
  final String name;
  final double price;
  final double quantity;

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.empty() => OrderItem(
        id: '',
        name: 'Unknown',
        price: 0.0,
        quantity: 0.0,
      );

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['produit']?['name']?.toString() ?? 'Unknown',
      price: _parsePrice(json),
      quantity: _parseQuantity(json),
    );
  }

  static double _parsePrice(Map<String, dynamic> json) {
    final price = json['Price'] ?? json['produit']?['Price'];
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  static double _parseQuantity(Map<String, dynamic> json) {
    final quantity = json['quantity'];
    if (quantity == null) return 0.0;
    if (quantity is double) return quantity;
    if (quantity is int) return quantity.toDouble();
    if (quantity is String) {
      if (quantity.isEmpty) return 0.0;
      return double.tryParse(quantity) ?? 0.0;
    }
    return 0.0;
  }
}