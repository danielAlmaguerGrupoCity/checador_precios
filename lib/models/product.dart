class PriceEntry {
  final double minQuantity;
  final double price;

  final String packagingName;
  final bool hasPackaging;
  final double totalPrice;

  PriceEntry({
    required this.minQuantity,
    required this.price,
    required this.packagingName,
    required this.hasPackaging,
    required this.totalPrice,
  });

  factory PriceEntry.fromJson(Map<String, dynamic> json) {
    return PriceEntry(
      minQuantity: (json['min_quantity'] as num?)?.toDouble() ?? 0.0,

      price: (json['price_formula'] as num?)?.toDouble() ?? 0.0,

      packagingName: json['packaging_name'] ?? '',

      hasPackaging: json['has_packaging'] ?? false,

      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
class Promotion {
  final String promoName;

  Promotion({required this.promoName});

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      promoName: json['promo_name'] ?? '',
    );
  }
}

class Product {
  //final int productId;
  final String productName;
  final String uom;
  //final String productCode;
  final String imageBase64;
  final List<PriceEntry> priceList;
  final List<Promotion> promotions;

  Product({
    //required this.productId,
    required this.productName,
    required this.uom,
    //required this.productCode,
    required this.imageBase64,
    required this.priceList,
    required this.promotions,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final List<dynamic> priceListJson = json['price_list'] ?? [];
    final List<dynamic> promotionsJson = json['promotions'] ?? [];

    return Product(
      //productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      uom: json['uom'] ?? '',
      //productCode: json['product_code'] ?? '',
      imageBase64: json['image_url'] ?? '',
      priceList:
          priceListJson.map((e) => PriceEntry.fromJson(e)).toList(),
      promotions:
          promotionsJson.map((e) => Promotion.fromJson(e)).toList(),
    );
  }
}
