class ProductModel {
  final String id;
  final String name;
  final double costPrice;
  final double price;
  final int stock;
  final String? imagePath;

  ProductModel({
    required this.id,
    required this.name,
    required this.costPrice,
    required this.price,
    required this.stock,
    this.imagePath,
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['name'] ?? '',
      costPrice: (map['costPrice'] ?? 0.0).toDouble(),
      price: (map['price'] ?? 0.0).toDouble(),
      stock: (map['stock'] ?? 0) as int,
      imagePath: map['imagePath'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'costPrice': costPrice,
      'price': price,
      'stock': stock,
      'imagePath': imagePath,
    };
  }
}