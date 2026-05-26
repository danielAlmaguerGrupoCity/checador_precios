import 'package:shared_preferences/shared_preferences.dart';

import '../models/branch_company_config.dart';

class LocalConfigService {
  static const String _branchIdKey = 'branch_id';
  static const String _companyIdKey = 'company_id';
  static const String _baseUrlKey  = 'api_base_url';
  static const String _displayDurationKey = 'display_duration_seconds';
  static const String _showBarcodeFieldKey = 'show_barcode_field';
  static const String _initialNavigateDelayKey = 'initial_navigate_delay_seconds';
  //static const String _initialAutoNavigateDoneKey = 'initial_auto_navigate_done'; // 👈 NUEVO

  static const String _defaultBaseUrl = 'http://odoo-pruebas.gcp.local:11569';
  static const int _defaultDisplayDuration = 5;
  static const bool _defaultShowBarcodeField = false;
  static const int _defaultInitialNavigateDelay = 5;
  /// Carga los valores guardados.
  /// Si no hay nada, usa branch_id = 8, company_id = 2 y la URL por defecto.
  Future<BranchCompanyConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final branchId = prefs.getInt(_branchIdKey) ?? 8;
    final companyId = prefs.getInt(_companyIdKey) ?? 2;
    final baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    final displayDurationSeconds = prefs.getInt(_displayDurationKey) ?? _defaultDisplayDuration;
    final showBarcodeField = prefs.getBool(_showBarcodeFieldKey) ?? _defaultShowBarcodeField;
    final initialNavigateDelaySeconds = prefs.getInt(_initialNavigateDelayKey) ?? _defaultInitialNavigateDelay;
    

    return BranchCompanyConfig(
      branchId: branchId,
      companyId: companyId,
      baseUrl: baseUrl,
      displayDurationSeconds: displayDurationSeconds,
      showBarcodeField: showBarcodeField,
      initialNavigateDelaySeconds: initialNavigateDelaySeconds,
    );
  }

  /// Guarda branch_id, company_id y opcionalmente baseUrl
  Future<void> saveConfig({
    required int branchId,
    required int companyId,
    String? baseUrl,
    int? displayDurationSeconds, // 👈 NUEVO
    bool? showBarcodeField,
    int? initialNavigateDelaySeconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_branchIdKey, branchId);
    await prefs.setInt(_companyIdKey, companyId);

    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      var normalized = baseUrl.trim();
      if (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }
      await prefs.setString(_baseUrlKey, normalized);
    }

    if (displayDurationSeconds != null && displayDurationSeconds > 0) {
      await prefs.setInt(_displayDurationKey, displayDurationSeconds);
    }
    if (showBarcodeField != null) {
    await prefs.setBool(_showBarcodeFieldKey, showBarcodeField);
    }
    if (initialNavigateDelaySeconds != null &&initialNavigateDelaySeconds > 0) {
      await prefs.setInt(
        _initialNavigateDelayKey,
        initialNavigateDelaySeconds,
      );
    }
  }

}
