/// Extracts a one-time code from an SMS [message].
///
/// With [pattern], returns its first capture group (or the whole match if it
/// has no groups). Otherwise returns the first standalone run of exactly
/// [length] digits, or of 4–8 digits when [length] is null.
String? extractOtp(String message, {int? length, RegExp? pattern}) {
  if (pattern != null) {
    final match = pattern.firstMatch(message);
    if (match == null) return null;
    return match.groupCount > 0 ? match.group(1) : match.group(0);
  }
  final digits = length == null ? r'\d{4,8}' : '\\d{$length}';
  return RegExp(
    '(?<![\\dA-Za-z])($digits)(?![\\dA-Za-z])',
  ).firstMatch(message)?.group(1);
}
