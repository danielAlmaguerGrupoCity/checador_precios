class BranchCompanyConfig {
  final int branchId;
  final int companyId;
  final String baseUrl;
  final int displayDurationSeconds;
   final bool showBarcodeField;
   final int initialNavigateDelaySeconds;

  BranchCompanyConfig({
    required this.branchId,
    required this.companyId,
    required this.baseUrl,
    required this.displayDurationSeconds,
    required this.showBarcodeField,
    required this.initialNavigateDelaySeconds,
  });
}
