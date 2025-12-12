import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:first_flutter/data/auth_service.dart';
class FeatureService {
  // Android emulator
   static String get apiUrl =>
      "${AuthService.baseUrl}/api/features";

  static final FeatureService _instance = FeatureService._internal();
  factory FeatureService() => _instance;
  FeatureService._internal();

  final Map<String, bool> _cache = {};

  // =========================
  // TOKEN
  // =========================
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ??
        prefs.getString('token');
  }

  // =========================
  // INIT FROM BACKEND
  // =========================
  Future<void> initialize() async {
    try {
      final res = await http.get(Uri.parse(apiUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();

        for (var f in data["features"]) {
          final id = f["featureId"];
          final enabled = f["isEnabled"] == true;

          _cache[id] = enabled;
          await prefs.setBool(id, enabled);
        }
      } else {
        await _loadLocal();
      }
    } catch (_) {
      await _loadLocal();
    }
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    for (var k in prefs.getKeys()) {
      final v = prefs.getBool(k);
      if (v != null) _cache[k] = v;
    }
  }

  // =========================
  // CHECK FEATURE
  // =========================
  Future<bool> isFeatureEnabled(String featureId) async {
    if (_cache.containsKey(featureId)) {
      return _cache[featureId]!;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(featureId) ?? true;
  }

  // =========================
  // UPDATE FEATURE (ADMIN)
  // =========================
  Future<void> update(String id, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final oldValue = _cache[id] ?? (prefs.getBool(id) ?? true);

    // optimistic update
    _cache[id] = enabled;
    await prefs.setBool(id, enabled);

    try {
      final token = await _getToken();

      final res = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "featureId": id,
          "isEnabled": enabled,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception("Backend rejected update");
      }
    } catch (e) {
      // rollback
      _cache[id] = oldValue;
      await prefs.setBool(id, oldValue);
      rethrow;
    }
  }

  // =========================
  // ROLE CHECK
  // =========================
  Future<bool> canAccess(String featureId, String role) async {
    if (role == "admin") return true;
    return await isFeatureEnabled(featureId);
  }

  // =========================
  // POLLING
  // =========================
  void startListening(Function() onUpdate) {
    Stream.periodic(const Duration(seconds: 10)).listen((_) async {
      await initialize();
      onUpdate();
    });
  }
}
