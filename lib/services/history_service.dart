import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result_model.dart';

class HistoryService {
  static const _key = 'scan_history';

  static Future<List<ScanResultModel>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => ScanResultModel.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> addScan(ScanResultModel scan) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(scan.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    if (index >= 0 && index < raw.length) {
      raw.removeAt(index);
      await prefs.setStringList(_key, raw);
    }
  }

  /// Remove by index into the raw list (0 = oldest)
  static Future<void> removeByIndex(int index) async {
    return removeAt(index);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
