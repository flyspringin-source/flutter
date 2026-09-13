class UpstoxSlot {
  const UpstoxSlot({
    required this.apiKey,
    required this.apiSecret,
    this.accessToken = '',
    this.userId = '',
    this.generatedAt,
  });

  final String apiKey;
  final String apiSecret;
  final String accessToken;
  final String userId;
  final DateTime? generatedAt;

  bool get hasToken => accessToken.trim().isNotEmpty;

  UpstoxSlot copyWith({
    String? apiKey,
    String? apiSecret,
    String? accessToken,
    String? userId,
    DateTime? generatedAt,
    bool clearToken = false,
  }) {
    return UpstoxSlot(
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      accessToken: clearToken ? '' : (accessToken ?? this.accessToken),
      userId: clearToken ? '' : (userId ?? this.userId),
      generatedAt: clearToken ? null : (generatedAt ?? this.generatedAt),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'apiKey': apiKey,
      'apiSecret': apiSecret,
      'accessToken': accessToken,
      'userId': userId,
      'generatedAt': generatedAt?.toIso8601String(),
    };
  }

  factory UpstoxSlot.fromJson(Map<dynamic, dynamic> json) {
    return UpstoxSlot(
      apiKey: json['apiKey'] as String? ?? '',
      apiSecret: json['apiSecret'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? ''),
    );
  }
}
