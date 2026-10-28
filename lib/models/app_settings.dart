import 'package:hive_ce/hive_ce.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.readerTheme = 'light',
    this.libraryLayout = 'grid',
    this.fontFamily = 'default',
    this.fontSize = 18.0,
    this.lineHeight = 1.6,
    this.pageMargin = 16.0,
    this.readerParagraphSpacing = 12.0,
    this.readerTextAlign = 'left',
    this.readerShowProgress = true,
    this.ttsSpeed = 1.0,
    this.defaultVoiceId,
    this.keepScreenOn = true,
    this.autoScroll = false,
    this.incognitoMode = false,
    this.showUnreadBadges = true,
    this.updatedAt,
  });

  factory AppSettings.defaults() => const AppSettings();

  final String themeMode;
  final String readerTheme;
  final String libraryLayout;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double pageMargin;
  final double readerParagraphSpacing;
  final String readerTextAlign;
  final bool readerShowProgress;
  final double ttsSpeed;
  final int? defaultVoiceId;
  final bool keepScreenOn;
  final bool autoScroll;
  final bool incognitoMode;
  final bool showUnreadBadges;
  final DateTime? updatedAt;

  AppSettings copyWith({
    String? themeMode,
    String? readerTheme,
    String? libraryLayout,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? pageMargin,
    double? readerParagraphSpacing,
    String? readerTextAlign,
    bool? readerShowProgress,
    double? ttsSpeed,
    int? defaultVoiceId,
    bool? keepScreenOn,
    bool? autoScroll,
    bool? incognitoMode,
    bool? showUnreadBadges,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      readerTheme: readerTheme ?? this.readerTheme,
      libraryLayout: libraryLayout ?? this.libraryLayout,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      pageMargin: pageMargin ?? this.pageMargin,
      readerParagraphSpacing:
          readerParagraphSpacing ?? this.readerParagraphSpacing,
      readerTextAlign: readerTextAlign ?? this.readerTextAlign,
      readerShowProgress: readerShowProgress ?? this.readerShowProgress,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      defaultVoiceId: defaultVoiceId ?? this.defaultVoiceId,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      autoScroll: autoScroll ?? this.autoScroll,
      incognitoMode: incognitoMode ?? this.incognitoMode,
      showUnreadBadges: showUnreadBadges ?? this.showUnreadBadges,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 2;

  @override
  AppSettings read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      themeMode: fields[0] as String? ?? 'system',
      readerTheme: fields[1] as String? ?? 'light',
      libraryLayout: fields[2] as String? ?? 'grid',
      fontFamily: fields[3] as String? ?? 'default',
      fontSize: (fields[4] as num?)?.toDouble() ?? 18.0,
      lineHeight: (fields[5] as num?)?.toDouble() ?? 1.6,
      pageMargin: (fields[6] as num?)?.toDouble() ?? 16.0,
      readerParagraphSpacing: (fields[14] as num?)?.toDouble() ?? 12.0,
      readerTextAlign: fields[15] as String? ?? 'left',
      readerShowProgress: fields[16] as bool? ?? true,
      ttsSpeed: (fields[7] as num?)?.toDouble() ?? 1.0,
      defaultVoiceId: fields[8] as int?,
      keepScreenOn: fields[9] as bool? ?? true,
      autoScroll: fields[10] as bool? ?? false,
      incognitoMode: fields[11] as bool? ?? false,
      showUnreadBadges: fields[12] as bool? ?? true,
      updatedAt: fields[13] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[13] as int),
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.themeMode)
      ..writeByte(1)
      ..write(obj.readerTheme)
      ..writeByte(2)
      ..write(obj.libraryLayout)
      ..writeByte(3)
      ..write(obj.fontFamily)
      ..writeByte(4)
      ..write(obj.fontSize)
      ..writeByte(5)
      ..write(obj.lineHeight)
      ..writeByte(6)
      ..write(obj.pageMargin)
      ..writeByte(7)
      ..write(obj.ttsSpeed)
      ..writeByte(8)
      ..write(obj.defaultVoiceId)
      ..writeByte(9)
      ..write(obj.keepScreenOn)
      ..writeByte(10)
      ..write(obj.autoScroll)
      ..writeByte(11)
      ..write(obj.incognitoMode)
      ..writeByte(12)
      ..write(obj.showUnreadBadges)
      ..writeByte(13)
      ..write(obj.updatedAt?.millisecondsSinceEpoch)
      ..writeByte(14)
      ..write(obj.readerParagraphSpacing)
      ..writeByte(15)
      ..write(obj.readerTextAlign)
      ..writeByte(16)
      ..write(obj.readerShowProgress);
  }
}
