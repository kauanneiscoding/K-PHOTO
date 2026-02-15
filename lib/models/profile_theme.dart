import 'package:flutter/material.dart';

enum ProfileThemeType {
  pink,      // Rosa (padrão atual)
  purple,    // Roxo pastel
  light,     // Modo claro
  dark,      // Modo escuro
}

class ProfileTheme {
  final ProfileThemeType type;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color textColor;
  final Color usernameColor;
  final Color accentColor;
  final bool isDark;

  const ProfileTheme({
    required this.type,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textColor,
    required this.usernameColor,
    required this.accentColor,
    required this.isDark,
  });

  // Tema Rosa (padrão atual - tons pastel suaves)
  static const ProfileTheme pink = ProfileTheme(
    type: ProfileThemeType.pink,
    name: 'Rosa',
    primaryColor: Color(0xFFF48FB1),      // Rosa mais suave
    secondaryColor: Color(0xFFFCE4EC),    // Rosa muito claro
    backgroundColor: Color(0xFFFFF5F7),   // Fundo quase branco com rosa
    surfaceColor: Color(0xFFFCE4EC),      // Superfície rosa clara
    textColor: Color(0xFFAD1457),         // Texto rosa mais suave
    usernameColor: Color(0xFFEC407A),    // Username rosa médio
    accentColor: Color(0xFFF06292),       // Acento rosa
    isDark: false,
  );

  // Tema Roxo Pastel
  static const ProfileTheme purple = ProfileTheme(
    type: ProfileThemeType.purple,
    name: 'Roxo Pastel',
    primaryColor: Color(0xFF9C27B0),      // Roxo mais forte para contraste
    secondaryColor: Color(0xFFCE93D8),    // Roxo muito claro
    backgroundColor: Color(0xFFF3E5F5),   // Fundo roxo muito claro
    surfaceColor: Color(0xFFE1BEE7),      // Superfície roxa clara
    textColor: Color(0xFF6A1B9A),         // Texto roxo mais forte
    usernameColor: Color(0xFF7B1FA2),    // Username roxo médio
    accentColor: Color(0xFFAB47BC),       // Acento roxo mais visível
    isDark: false,
  );

  // Tema Claro
  static const ProfileTheme light = ProfileTheme(
    type: ProfileThemeType.light,
    name: 'Claro',
    primaryColor: Color(0xFF64B5F6),      // Azul suave
    secondaryColor: Color(0xFF90CAF9),    // Azul claro
    backgroundColor: Color(0xFFE3F2FD),   // Fundo azul muito claro
    surfaceColor: Color(0xFFBBDEFB),      // Superfície azul clara
    textColor: Color(0xFF1976D2),         // Texto azul médio
    usernameColor: Color(0xFF2196F3),    // Username azul
    accentColor: Color(0xFF42A5F5),       // Acento azul
    isDark: false,
  );

  // Tema Escuro
  static const ProfileTheme dark = ProfileTheme(
    type: ProfileThemeType.dark,
    name: 'Escuro',
    primaryColor: Color(0xFF757575),      // Cinza médio
    secondaryColor: Color(0xFF9E9E9E),    // Cinza claro
    backgroundColor: Color(0xFF1E1E1E),   // Fundo escuro suave
    surfaceColor: Color(0xFF2E2E2E),      // Superfície cinza escura
    textColor: Color(0xFFE0E0E0),         // Texto cinza claro
    usernameColor: Color(0xFFBDBDBD),    // Username cinza médio
    accentColor: Color(0xFF616161),       // Acento cinza
    isDark: true,
  );

  static List<ProfileTheme> get allThemes => [pink, purple, light, dark];

  static ProfileTheme fromType(ProfileThemeType type) {
    switch (type) {
      case ProfileThemeType.pink:
        return pink;
      case ProfileThemeType.purple:
        return purple;
      case ProfileThemeType.light:
        return light;
      case ProfileThemeType.dark:
        return dark;
    }
  }

  static ProfileTheme fromString(String themeString) {
    for (final theme in allThemes) {
      if (theme.type.name == themeString) {
        return theme;
      }
    }
    return pink; // Padrão
  }

  Map<String, dynamic> toMap() {
    return {
      'theme_type': type.name,
      'name': name,
      'primary_color': primaryColor.value,
      'secondary_color': secondaryColor.value,
      'background_color': backgroundColor.value,
      'surface_color': surfaceColor.value,
      'text_color': textColor.value,
      'username_color': usernameColor.value,
      'accent_color': accentColor.value,
      'is_dark': isDark,
    };
  }

  factory ProfileTheme.fromMap(Map<String, dynamic> map) {
    final typeString = map['theme_type'] as String? ?? 'pink';
    final type = ProfileThemeType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => ProfileThemeType.pink,
    );
    return fromType(type);
  }
}
