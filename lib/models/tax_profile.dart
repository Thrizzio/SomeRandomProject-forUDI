import 'dart:convert';

class TaxDeductions {
  final double section80C; // Max 1.5 Lakhs
  final double section80D; // Max 25k/50k for medical insurance
  final double section80G; // Donations
  final double npsSection80CCD1B; // NPS up to 50k
  final double educationLoanInterest; // Section 80E
  final double homeLoanInterest; // Section 24b up to 2 Lakhs

  TaxDeductions({
    this.section80C = 0.0,
    this.section80D = 0.0,
    this.section80G = 0.0,
    this.npsSection80CCD1B = 0.0,
    this.educationLoanInterest = 0.0,
    this.homeLoanInterest = 0.0,
  });

  double getTotalDeductions() {
    // 80C is capped at 1,50,000
    final capped80C = section80C > 150000.0 ? 150000.0 : section80C;
    // 80D is capped at 25,000 (usually 25k, can be 50k for parents, we cap at 50k max to be safe)
    final capped80D = section80D > 50000.0 ? 50000.0 : section80D;
    // NPS 80CCD(1B) is capped at 50,000
    final cappedNPS = npsSection80CCD1B > 50000.0 ? 50000.0 : npsSection80CCD1B;
    // Home Loan Interest u/s 24b is capped at 2,000,000
    final cappedHomeLoan = homeLoanInterest > 200000.0 ? 200000.0 : homeLoanInterest;

    return capped80C + capped80D + section80G + cappedNPS + educationLoanInterest + cappedHomeLoan;
  }

  Map<String, dynamic> toJson() {
    return {
      'section80C': section80C,
      'section80D': section80D,
      'section80G': section80G,
      'npsSection80CCD1B': npsSection80CCD1B,
      'educationLoanInterest': educationLoanInterest,
      'homeLoanInterest': homeLoanInterest,
    };
  }

  factory TaxDeductions.fromJson(Map<String, dynamic> json) {
    return TaxDeductions(
      section80C: (json['section80C'] as num?)?.toDouble() ?? 0.0,
      section80D: (json['section80D'] as num?)?.toDouble() ?? 0.0,
      section80G: (json['section80G'] as num?)?.toDouble() ?? 0.0,
      npsSection80CCD1B: (json['npsSection80CCD1B'] as num?)?.toDouble() ?? 0.0,
      educationLoanInterest: (json['educationLoanInterest'] as num?)?.toDouble() ?? 0.0,
      homeLoanInterest: (json['homeLoanInterest'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TaxProfile {
  final String professionType; // 'freelancer', 'consultant', 'developer', 'delivery', 'gig', 'self_employed'
  final String taxRegime; // 'old', 'new'
  final String businessCategory; // '44ada', '44ad', 'regular'
  final double expectedAnnualIncome;
  final String businessType;
  final TaxDeductions deductions;
  final int version;
  final DateTime updatedAt;

  TaxProfile({
    required this.professionType,
    required this.taxRegime,
    required this.businessCategory,
    required this.expectedAnnualIncome,
    required this.businessType,
    required this.deductions,
    this.version = 1,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'professionType': professionType,
      'taxRegime': taxRegime,
      'businessCategory': businessCategory,
      'expectedAnnualIncome': expectedAnnualIncome,
      'businessType': businessType,
      'deductions': deductions.toJson(),
      'version': version,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TaxProfile.fromJson(Map<String, dynamic> json) {
    return TaxProfile(
      professionType: json['professionType'] ?? 'freelancer',
      taxRegime: json['taxRegime'] ?? 'new',
      businessCategory: json['businessCategory'] ?? '44ada',
      expectedAnnualIncome: (json['expectedAnnualIncome'] as num?)?.toDouble() ?? 500000.0,
      businessType: json['businessType'] ?? 'Software Development',
      deductions: json['deductions'] != null
          ? TaxDeductions.fromJson(json['deductions'])
          : TaxDeductions(),
      version: json['version'] ?? 1,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    );
  }

  factory TaxProfile.defaultProfile() {
    return TaxProfile(
      professionType: 'freelancer',
      taxRegime: 'new',
      businessCategory: '44ada',
      expectedAnnualIncome: 600000.0,
      businessType: 'Software Development',
      deductions: TaxDeductions(),
      version: 1,
      updatedAt: DateTime.now(),
    );
  }

  TaxProfile copyWith({
    String? professionType,
    String? taxRegime,
    String? businessCategory,
    double? expectedAnnualIncome,
    String? businessType,
    TaxDeductions? deductions,
    int? version,
  }) {
    return TaxProfile(
      professionType: professionType ?? this.professionType,
      taxRegime: taxRegime ?? this.taxRegime,
      businessCategory: businessCategory ?? this.businessCategory,
      expectedAnnualIncome: expectedAnnualIncome ?? this.expectedAnnualIncome,
      businessType: businessType ?? this.businessType,
      deductions: deductions ?? this.deductions,
      version: version ?? this.version + 1,
      updatedAt: DateTime.now(),
    );
  }
}
