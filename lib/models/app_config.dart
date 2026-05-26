class AppConfig {
  final String companyName;
  final String branchName;
  final String companyLogoBase64;

  AppConfig({
    required this.companyName,
    required this.branchName,
    required this.companyLogoBase64,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      companyName: json['company_name'] ?? '',
      branchName: json['branch_name'] ?? '',
      companyLogoBase64: json['company_logo'] ?? '',
    );
  }
}

