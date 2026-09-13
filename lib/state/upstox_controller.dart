import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/upstox_config.dart';
import '../models/upstox_slot.dart';
import '../services/upstox_auth.dart';

class UpstoxController extends ChangeNotifier {
  UpstoxController({this.tokenExchanger, bool? persistEnabled})
    : _persistEnabled = persistEnabled;

  static const slotCount = 6;
  static const _prefsKey = 'upstox_config_v1';

  final Future<Map<String, dynamic>> Function({
    required String code,
    required String apiKey,
    required String apiSecret,
    required String redirectUrl,
  })?
  tokenExchanger;
  final bool? _persistEnabled;

  var _redirectUrl = upstoxRedirectUrl;
  var _roundRobinIndex = 0;
  var _slots = _defaultSlots();
  String? _error;
  var _busyIndex = -1;
  var _revision = 0;
  Future<void>? _loadFuture;

  String get redirectUrl => _redirectUrl;
  List<UpstoxSlot> get slots => List.unmodifiable(_slots);
  String? get error => _error;
  int get busyIndex => _busyIndex;
  int get revision => _revision;
  int get readyTokenCount => _slots.where((slot) => slot.hasToken).length;
  bool get hasReadyToken => readyTokenCount > 0;

  static List<UpstoxSlot> _defaultSlots() {
    return [
      for (var i = 0; i < slotCount; i++)
        UpstoxSlot(
          apiKey: upstoxDefaultApiKeys[i],
          apiSecret: upstoxDefaultApiSecrets[i],
        ),
    ];
  }

  Future<void> load() {
    return _loadFuture ??= _readPersisted();
  }

  Future<void> _readPersisted() async {
    if (!_canPersist) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _redirectUrl = data['redirectUrl'] as String? ?? upstoxRedirectUrl;
      _roundRobinIndex = data['roundRobinIndex'] as int? ?? 0;
      final saved = (data['slots'] as List?) ?? const [];
      _slots = [
        for (var i = 0; i < slotCount; i++)
          i < saved.length && saved[i] is Map
              ? UpstoxSlot.fromJson(saved[i] as Map)
              : _defaultSlots()[i],
      ];
      _revision += 1;
      notifyListeners();
    } catch (error) {
      debugPrint('Upstox config load failed: $error');
    }
  }

  Future<void> setRedirectUrl(String value) async {
    _redirectUrl = value.trim().isEmpty ? upstoxRedirectUrl : value.trim();
    notifyListeners();
    await _persist();
  }

  Future<void> updateSlot(int index, {String? apiKey, String? apiSecret}) async {
    if (index < 0 || index >= _slots.length) {
      return;
    }
    _slots[index] = _slots[index].copyWith(
      apiKey: apiKey,
      apiSecret: apiSecret,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> updateCredentials(
    List<({String apiKey, String apiSecret})> values,
  ) async {
    for (var i = 0; i < slotCount && i < values.length; i++) {
      _slots[i] = _slots[i].copyWith(
        apiKey: values[i].apiKey,
        apiSecret: values[i].apiSecret,
      );
    }
    notifyListeners();
    await _persist();
  }

  Future<void> exchangeCode(int index, String code) async {
    if (index < 0 || index >= _slots.length) {
      return;
    }
    final slot = _slots[index];
    _busyIndex = index;
    _error = null;
    notifyListeners();
    try {
      final payload = tokenExchanger != null
          ? await tokenExchanger!(
              code: code,
              apiKey: slot.apiKey,
              apiSecret: slot.apiSecret,
              redirectUrl: _redirectUrl,
            )
          : await exchangeUpstoxCode(
              code: code,
              apiKey: slot.apiKey,
              apiSecret: slot.apiSecret,
              redirectUrl: _redirectUrl,
            );
      final data = payload['data'] is Map<String, dynamic>
          ? payload['data'] as Map<String, dynamic>
          : payload;
      final token = data['access_token'] as String? ?? '';
      if (token.isEmpty) {
        throw Exception('Access token missing in Upstox response');
      }
      _slots[index] = slot.copyWith(
        accessToken: token,
        userId: data['user_id'] as String? ?? '',
        generatedAt: DateTime.now(),
      );
    } catch (error) {
      _error = '$error';
      rethrow;
    } finally {
      _busyIndex = -1;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> clearToken(int index) async {
    if (index < 0 || index >= _slots.length) {
      return;
    }
    _slots[index] = _slots[index].copyWith(clearToken: true);
    notifyListeners();
    await _persist();
  }

  /// Uses the first ready token so profile/funds/orders stay on one account.
  String? primaryAccessToken() {
    for (final slot in _slots) {
      if (slot.hasToken) {
        return slot.accessToken;
      }
    }
    return null;
  }

  /// Uses the next round-robin access token for an Upstox REST call.
  Future<Map<String, dynamic>> authorizedGet(String path) async {
    final token = primaryAccessToken();
    if (token == null) {
      throw Exception('Generate Upstox access tokens in Settings');
    }
    return upstoxGet(path, accessToken: token);
  }

  /// Returns the next ready access token, cycling across the 6 slots.
  String? nextAccessToken() {
    final ready = <int>[];
    for (var i = 0; i < _slots.length; i++) {
      if (_slots[i].hasToken) {
        ready.add(i);
      }
    }
    if (ready.isEmpty) {
      return null;
    }
    final pick = ready[_roundRobinIndex % ready.length];
    _roundRobinIndex += 1;
    _persist();
    return _slots[pick].accessToken;
  }

  bool get _canPersist {
    if (_persistEnabled != null) {
      return _persistEnabled!;
    }
    return !_isWidgetTest;
  }

  Future<void> _persist() async {
    if (!_canPersist) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'redirectUrl': _redirectUrl,
          'roundRobinIndex': _roundRobinIndex,
          'slots': _slots.map((slot) => slot.toJson()).toList(),
        }),
      );
    } catch (error) {
      debugPrint('Upstox persist failed: $error');
    }
  }

  bool get _isWidgetTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString() ==
          'AutomatedTestWidgetsFlutterBinding';
    } catch (_) {
      return true;
    }
  }
}
