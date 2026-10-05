import 'dart:typed_data';

/// App instalada en el dispositivo (extiende el modelo nativo existente).
class ManagedApp {
  const ManagedApp({
    required this.packageName,
    required this.name,
    this.category = 'other',
    this.usageMinutes = 0,
    this.icon,
    this.isBookmarked = false,
    this.localReview,
  });

  final String packageName;
  final String name;
  final String category;
  final int usageMinutes;
  final Uint8List? icon;
  final bool isBookmarked;
  final LocalAppReview? localReview;

  ManagedApp copyWith({
    bool? isBookmarked,
    LocalAppReview? localReview,
  }) {
    return ManagedApp(
      packageName: packageName,
      name: name,
      category: category,
      usageMinutes: usageMinutes,
      icon: icon,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      localReview: localReview ?? this.localReview,
    );
  }
}

/// Reseña local (solo dispositivo).
class LocalAppReview {
  const LocalAppReview({
    this.performance = 5.0,
    this.privacy = 5.0,
    this.note = '',
  });

  final double performance; // 0–10
  final double privacy; // 0–10
  final String note;

  Map<String, dynamic> toJson() => {
        'performance': performance,
        'privacy': privacy,
        'note': note,
      };

  factory LocalAppReview.fromJson(Map<String, dynamic> j) => LocalAppReview(
        performance: (j['performance'] as num?)?.toDouble() ?? 5.0,
        privacy: (j['privacy'] as num?)?.toDouble() ?? 5.0,
        note: (j['note'] as String?) ?? '',
      );
}

/// Resultado del análisis estático de un APK.
enum RiskLevel { bajo, moderado, alto }

class ApkRiskReport {
  const ApkRiskReport({
    required this.score,
    required this.level,
    required this.permissions,
    required this.trackingSdks,
    required this.fileName,
    required this.packageName,
    this.sha256,
  });

  final int score; // 0–100
  final RiskLevel level;
  final List<ApkPermission> permissions;
  final List<String> trackingSdks;
  final String fileName;
  final String packageName;
  final String? sha256;

  static RiskLevel levelFromScore(int score) {
    if (score <= 30) return RiskLevel.bajo;
    if (score <= 70) return RiskLevel.moderado;
    return RiskLevel.alto;
  }
}

class ApkPermission {
  const ApkPermission({
    required this.name,
    required this.description,
    this.critical = false,
  });

  final String name;
  final String description;
  final bool critical;
}

/// Estado de verificación de firma contra el oráculo.
enum SignatureStatus { verified, cacheHit, unverified, error }

class SignatureCheckResult {
  const SignatureCheckResult({
    required this.status,
    required this.packageName,
    required this.versionLabel,
    this.certSha256,
    this.cacheAgeDays,
    this.message,
  });

  final SignatureStatus status;
  final String packageName;
  final String versionLabel;
  final String? certSha256;
  final int? cacheAgeDays;
  final String? message;
}
