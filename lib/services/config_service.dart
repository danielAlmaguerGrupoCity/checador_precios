import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_config.dart';

class ConfigService {
  Future<AppConfig> fetchConfig({
    required int branchId,
    required int companyId,
    required String baseUrl, // 👈 ahora viene desde config local
  }) async {
    final uri = Uri.parse(
      '$baseUrl/getCompanyData?branch_id=$branchId&company_id=$companyId',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return AppConfig.fromJson(data);
    } else {
      throw Exception(
        'Error al obtener configuración. Código: ${response.statusCode}',
      );
    }
  }
}

