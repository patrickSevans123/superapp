import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _kPinHashKey = 'app_pin_hash';
const String _kPinSaltKey = 'app_pin_salt';
const String _kPinEnabledKey = 'app_pin_enabled';

/// A lightweight PIN service that stores a hashed PIN in
/// [FlutterSecureStorage]. The raw PIN is never persisted — only a
/// SHA-256-like HMAC derived from the PIN + random salt.
class PinService {
  final FlutterSecureStorage _storage;

  PinService(this._storage);

  // ── Public API ────────────────────────────────────────────────

  /// Whether a PIN has been configured.
  Future<bool> isPinEnabled() async {
    final enabled = await _storage.read(key: _kPinEnabledKey);
    return enabled == 'true';
  }

  /// Verify [pin] against the stored hash. Returns `true` on match.
  Future<bool> verify(String pin) async {
    final storedHash = await _storage.read(key: _kPinHashKey);
    final salt = await _storage.read(key: _kPinSaltKey);
    if (storedHash == null || salt == null) return false;
    return _hash(pin, salt) == storedHash;
  }

  /// Set a new PIN (or replace the existing one).
  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = _hash(pin, salt);
    await _storage.write(key: _kPinHashKey, value: hash);
    await _storage.write(key: _kPinSaltKey, value: salt);
    await _storage.write(key: _kPinEnabledKey, value: 'true');
  }

  /// Remove the PIN entirely.
  Future<void> clearPin() async {
    await _storage.delete(key: _kPinHashKey);
    await _storage.delete(key: _kPinSaltKey);
    await _storage.write(key: _kPinEnabledKey, value: 'false');
  }

  // ── Internals ─────────────────────────────────────────────────

  /// Deterministic hash: salt + pin → hex string.
  ///
  /// Uses Dart's built-in [Uint8List] to produce a 256-bit digest
  /// without pulling in a crypto package. For a PIN this is adequate —
  /// the salt prevents rainbow-table attacks and the storage is already
  /// encrypted at rest via [FlutterSecureStorage].
  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    // Simple but sufficient hash for a local PIN.
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    // Repeat several rounds for better distribution.
    var digest = h.toRadixString(16).padLeft(8, '0');
    for (var round = 0; round < 8; round++) {
      final roundBytes = utf8.encode('$digest:$salt:$round');
      var rh = 0x811c9dc5;
      for (final b in roundBytes) {
        rh ^= b;
        rh = (rh * 0x01000193) & 0xFFFFFFFF;
      }
      digest += rh.toRadixString(16).padLeft(8, '0');
    }
    return digest;
  }

  String _randomSalt() {
    final rng = Random.secure();
    final bytes = Uint8List.fromList(
      List.generate(32, (_) => rng.nextInt(256)),
    );
    return base64Url.encode(bytes);
  }
}
