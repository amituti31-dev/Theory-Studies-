import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

/// Checks the GitHub Releases of the project for a newer version and, when one
/// exists, exposes the release page URL so the user can download the update.
class UpdateService {
  /// Bump this on every release; must match the release tag (e.g. tag v1.1.0).
  static const currentVersion = '1.1.4';

  static const _repo = 'amituti31-dev/Theory-Studies';
  static const _latestApi =
      'https://api.github.com/repos/$_repo/releases/latest';

  /// The releases page, used as a safe fallback download link.
  static const releasesPage = 'https://github.com/$_repo/releases';

  /// Returns update info when a newer release exists, otherwise null.
  /// [assetUrl] is the direct download link for this platform's installer/APK
  /// (null on platforms without a prebuilt binary, e.g. Linux); [pageUrl] is
  /// the release web page (used as a fallback).
  static Future<({String version, String pageUrl, String? assetUrl})?>
      checkForUpdate() async {
    try {
      final r = await http.get(
        Uri.parse(_latestApi),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;

      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?)?.trim();
      if (tag == null || tag.isEmpty) return null;
      final remote = tag.replaceFirst(RegExp('^v'), '');
      if (!_isNewer(remote, currentVersion)) return null;

      final pageUrl = (data['html_url'] as String?) ?? releasesPage;

      // Pick the direct download URL for this platform's asset.
      final wantExt = Platform.isWindows
          ? '.exe'
          : Platform.isAndroid
              ? '.apk'
              : null;
      String? assetUrl;
      if (wantExt != null) {
        for (final a in (data['assets'] as List? ?? const [])) {
          final name = ((a as Map)['name'] as String? ?? '').toLowerCase();
          if (name.endsWith(wantExt)) {
            assetUrl = a['browser_download_url'] as String?;
            break;
          }
        }
      }
      return (version: remote, pageUrl: pageUrl, assetUrl: assetUrl);
    } catch (_) {
      return null;
    }
  }

  /// Compares dotted numeric versions (e.g. "1.2.0" > "1.1.9").
  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final l = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }
}
