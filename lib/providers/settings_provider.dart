// lib/providers/settings_provider.dart
// 앱 설정을 관리하는 프로바이더

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String _languageKey = 'language_code';
  
  // 기본 언어는 한국어
  Locale _locale = const Locale('ko');
  Locale get locale => _locale;

  // 지원하는 모든 언어 목록
  final List<Locale> supportedLocales = [
    const Locale('ko'), // 한국어
    const Locale('en'), // 영어
  ];
  
  // 각 Locale에 해당하는 언어 이름
  String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'ko':
        return '한국어';
      case 'en':
        return 'English';
      default:
        return '한국어';
    }
  }

  // 초기화 함수: 저장된 설정을 불러옴
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString(_languageKey);
    
    if (savedLanguageCode != null) {
      _locale = Locale(savedLanguageCode);
      notifyListeners();
    }
  }

  // 언어 설정 함수
  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    
    _locale = newLocale;
    notifyListeners();
    
    // 설정을 로컬에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, newLocale.languageCode);
  }
}