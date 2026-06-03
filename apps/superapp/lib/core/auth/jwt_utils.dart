import 'dart:convert';

/// Minimal JWT helpers. We deliberately do NOT add a `dart_jwt` dep — the
/// only claim we care about client-side is `exp` (expiry).
class JwtUtils {
  JwtUtils._();

  /// Returns the `exp` claim (UTC) of [token] if present and parseable,
  /// otherwise `null`. The function never throws.
  static DateTime? expiry(String token) {
    if (token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payloadJson = _b64UrlDecode(parts[1]);
      if (payloadJson == null || payloadJson.isEmpty) return null;
      final decoded = json.decode(payloadJson);
      if (decoded is! Map<String, dynamic>) return null;

      // `exp` is the standard claim (seconds since epoch, UTC).
      // Some servers also use `expiresAt`; we accept both.
      final raw = decoded['exp'] ?? decoded['expiresAt'];
      if (raw is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          raw.toInt() * 1000,
          isUtc: true,
        );
      }
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed.toUtc();
      }
    } catch (_) {
      // Any decode error — return null so the caller treats the token
      // as "no expiry info" rather than crashing.
    }
    return null;
  }

  /// True if [token]'s `exp` claim is in the past (or unset/now). False
  /// if there is a future expiry.
  static bool isExpired(String? token) {
    if (token == null) return true;
    final exp = expiry(token);
    if (exp == null) return false;
    return !exp.isAfter(DateTime.now().toUtc());
  }

  /// Decode a base64url segment with padding recovery. Returns `null`
  /// on failure.
  static String? _b64UrlDecode(String segment) {
    try {
      // base64url → base64
      var s = segment.replaceAll('-', '+').replaceAll('_', '/');
      // Pad to multiple of 4
      while (s.length % 4 != 0) {
        s += '=';
      }
      return utf8.decode(base64.decode(s));
    } catch (_) {
      return null;
    }
  }
}
