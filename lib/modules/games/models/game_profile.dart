/// Perfil por juego o global para el modo gamer.
class GameProfile {
  const GameProfile({
    required this.packageName,
    this.displayName = '',
    this.boosterOnLaunch = true,
    this.focusOnLaunch = true,
    this.lockBrightness = false,
    this.extendScreenTimeout = true,
    this.showHud = true,
    this.targetFps = 0,
    this.preferHighRefresh = true,
    this.blockNotifications = true,
  });

  final String packageName;
  final String displayName;
  final bool boosterOnLaunch;
  final bool focusOnLaunch;
  final bool lockBrightness;
  final bool extendScreenTimeout;
  final bool showHud;
  /// 0 = auto (refresh del panel); 30/60/90/120 = preferencia UI.
  final int targetFps;
  final bool preferHighRefresh;
  final bool blockNotifications;

  GameProfile copyWith({
    String? displayName,
    bool? boosterOnLaunch,
    bool? focusOnLaunch,
    bool? lockBrightness,
    bool? extendScreenTimeout,
    bool? showHud,
    int? targetFps,
    bool? preferHighRefresh,
    bool? blockNotifications,
  }) =>
      GameProfile(
        packageName: packageName,
        displayName: displayName ?? this.displayName,
        boosterOnLaunch: boosterOnLaunch ?? this.boosterOnLaunch,
        focusOnLaunch: focusOnLaunch ?? this.focusOnLaunch,
        lockBrightness: lockBrightness ?? this.lockBrightness,
        extendScreenTimeout: extendScreenTimeout ?? this.extendScreenTimeout,
        showHud: showHud ?? this.showHud,
        targetFps: targetFps ?? this.targetFps,
        preferHighRefresh: preferHighRefresh ?? this.preferHighRefresh,
        blockNotifications: blockNotifications ?? this.blockNotifications,
      );

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'displayName': displayName,
        'boosterOnLaunch': boosterOnLaunch,
        'focusOnLaunch': focusOnLaunch,
        'lockBrightness': lockBrightness,
        'extendScreenTimeout': extendScreenTimeout,
        'showHud': showHud,
        'targetFps': targetFps,
        'preferHighRefresh': preferHighRefresh,
        'blockNotifications': blockNotifications,
      };

  factory GameProfile.fromJson(Map<String, dynamic> m) => GameProfile(
        packageName: m['packageName'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        boosterOnLaunch: m['boosterOnLaunch'] != false,
        focusOnLaunch: m['focusOnLaunch'] != false,
        lockBrightness: m['lockBrightness'] == true,
        extendScreenTimeout: m['extendScreenTimeout'] != false,
        showHud: m['showHud'] != false,
        targetFps: (m['targetFps'] as num?)?.toInt() ?? 0,
        preferHighRefresh: m['preferHighRefresh'] != false,
        blockNotifications: m['blockNotifications'] != false,
      );
}

class GameSessionStats {
  const GameSessionStats({
    required this.packageName,
    required this.startedAt,
    this.endedAt,
    this.peakFps = 0,
    this.avgFps = 0,
    this.minRamMb = 0,
  });

  final String packageName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double peakFps;
  final double avgFps;
  final int minRamMb;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);
}
