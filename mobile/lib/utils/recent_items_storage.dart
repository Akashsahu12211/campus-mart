import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/item_model.dart';

class RecentItemsStorage {
  static const String _key = 'campusmart_recent_items';
  static const int _maxItems = 12;

  static Future<List<Item>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        return [];
      }
      return parsed
          .whereType<Map>()
          .map((item) => Item.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(Item item) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
    final deduped = existing.where((saved) => saved.id != item.id).toList();
    final snapshot = Item.fromJson(item.toJson());
    final next = [snapshot, ...deduped].take(_maxItems).toList();
    await prefs.setString(
      _key,
      jsonEncode(next.map((entry) => entry.toJson()).toList()),
    );
  }
}
