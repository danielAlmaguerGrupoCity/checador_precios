import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/product.dart';





class ProductService {
  Future<Product?> fetchProductByCode(
    String productCode, {
    required int companyId,
    required String baseUrl,
    required String branchId, // 👈 ahora viene desde config local
  }) async {
    final uri = Uri.parse(
      '$baseUrl/getPrice?warehouse_id=$branchId&company_id=$companyId&product_code=$productCode',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      if (data.isEmpty) {
        return null;
      }

      return Product.fromJson(data[0]);
    }

    // Caso especial 500 con HTML → producto no existente
    if (response.statusCode == 500 &&
        (response.headers['content-type']?.contains('text/html') ?? false) &&
        response.body.contains('Internal Server Error')) {
      return null;
    }

    throw Exception(
      'Error al obtener precio. Código: ${response.statusCode}',
    );
  }
}


