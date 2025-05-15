import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'data_storage_service.dart';

class CurrencyService {
  static DataStorageService? _dataStorageService;
  static const String _kCoinsKey = 'k_coins';
  static const String _starCoinsKey = 'star_coins';
  static const String _lastRewardKey = 'last_reward_time';
  static const String _lastRewardAmountKey = 'last_reward_amount';
  static const String _initializedKey = 'initialized';

  static Future<void> initialize(DataStorageService dataStorageService) async {
    try {
      _dataStorageService = dataStorageService;
      await _logBalance(); // Esperar o log completar
    } catch (e) {
      debugPrint('Erro ao inicializar CurrencyService: $e');
    }
  }

  static Future<void> _logBalance() async {
    try {
      if (_dataStorageService == null) {
        print('DataStorageService não inicializado');
        return;
      }
      
      final balance = await _dataStorageService!.getBalance();
      print('=== Saldo Atual ===');
      print('K-coins: ${balance['k_coins']}');
      print('Star-coins: ${balance['star_coins']}');
      print('==================');
    } catch (e) {
      print('Erro ao registrar saldo: $e');
    }
  }

  static Future<void> initializeDefaultValues() async {
    if (_dataStorageService == null) return;
    final prefs = await SharedPreferences.getInstance();
    final bool initialized = prefs.getBool(_initializedKey) ?? false;

    if (!initialized) {
      await _dataStorageService!.updateKCoins(300);
      await _dataStorageService!.updateStarCoins(0);
      await _dataStorageService
          ?.updateLastRewardTime(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await prefs.setInt(_lastRewardAmountKey, 0);
      await prefs.setBool(_initializedKey, true);
    }
    await _logBalance();
  }

  static Future<bool> hasEnoughKCoins(int amount) async {
    if (_dataStorageService == null) return false;
    final balance = await _dataStorageService!.getBalance();
    return balance['k_coins']! >= amount;
  }

  static Future<void> spendKCoins(int amount) async {
    if (_dataStorageService == null) return;
    final balance = await _dataStorageService!.getBalance();
    final currentBalance = balance['k_coins']!;
    if (currentBalance >= amount) {
      await _dataStorageService!.updateKCoins(currentBalance - amount);
    }
  }

  static Future<void> addKCoins(int amount) async {
    if (_dataStorageService == null) return;
    final balance = await _dataStorageService!.getBalance();
    final currentBalance = balance['k_coins']!;
    await _dataStorageService!.updateKCoins(currentBalance + amount);
  }

  static Future<int> getKCoins() async {
    if (_dataStorageService == null) return 0;
    final balance = await _dataStorageService!.getBalance();
    return balance['k_coins']!;
  }

  static Future<int> getStarCoins() async {
    if (_dataStorageService == null) return 0;
    final balance = await _dataStorageService!.getBalance();
    return balance['star_coins']!;
  }

  static Future<int> getSecondsSinceLastReward() async {
    if (_dataStorageService == null) return 0;
    final lastRewardTime = await _dataStorageService!.getLastRewardTime();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - lastRewardTime).toInt();
  }

  static Future<void> updateLastRewardTime() async {
    if (_dataStorageService == null) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _dataStorageService!.updateLastRewardTime(now);
  }

  static Future<bool> hasReceivedReward(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final lastRewardAmount = prefs.getInt(_lastRewardAmountKey) ?? 0;
    final rewardAmount = (seconds ~/ 60) * 10;
    return lastRewardAmount >= rewardAmount;
  }

  static Future<void> registerReward(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRewardAmountKey, amount);
  }

  static Future<void> addStarCoins(int amount) async {
    if (_dataStorageService == null) return;
    final balance = await _dataStorageService!.getBalance();
    final currentBalance = balance['star_coins']!;
    await _dataStorageService!.updateStarCoins(currentBalance + amount);
  }
}
