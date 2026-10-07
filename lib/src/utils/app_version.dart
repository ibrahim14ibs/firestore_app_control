/// Semantic versioning parser and comparator.
///
/// Supports versions like `1.0.0`, `1.2`, `1.2.0+10`, `1.2.0-beta.1`, `v2.0.0`.
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final int? buildNumber;
  final String? preRelease;
  final String raw;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildNumber,
    this.preRelease,
    required this.raw,
  });

  static const AppVersion zero = AppVersion(
    major: 0,
    minor: 0,
    patch: 0,
    raw: '0.0.0',
  );

  factory AppVersion.parse(String? versionString) {
    if (versionString == null || versionString.trim().isEmpty) {
      return zero;
    }

    final trimmed = versionString.trim();
    var clean = trimmed.startsWith(RegExp(r'^[vV]'))
        ? trimmed.substring(1)
        : trimmed;

    int? buildNumber;
    String? preRelease;

    if (clean.contains('+')) {
      final parts = clean.split('+');
      clean = parts[0];
      if (parts.length > 1) {
        buildNumber = int.tryParse(parts[1]);
      }
    }

    if (clean.contains('-')) {
      final parts = clean.split('-');
      clean = parts[0];
      if (parts.length > 1) {
        preRelease = parts.sublist(1).join('-');
      }
    }

    final segments = clean.split('.');
    final major = segments.isNotEmpty ? (int.tryParse(segments[0]) ?? 0) : 0;
    final minor = segments.length > 1 ? (int.tryParse(segments[1]) ?? 0) : 0;
    final patch = segments.length > 2 ? (int.tryParse(segments[2]) ?? 0) : 0;

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      buildNumber: buildNumber,
      preRelease: preRelease,
      raw: trimmed,
    );
  }

  static AppVersion? tryParse(String? versionString) {
    if (versionString == null || versionString.trim().isEmpty) return null;
    return AppVersion.parse(versionString);
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    if (preRelease != null && other.preRelease == null) return -1;
    if (preRelease == null && other.preRelease != null) return 1;
    if (preRelease != null && other.preRelease != null) {
      final comp = preRelease!.compareTo(other.preRelease!);
      if (comp != 0) return comp;
    }

    if (buildNumber != null && other.buildNumber != null) {
      return buildNumber!.compareTo(other.buildNumber!);
    }

    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppVersion &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch &&
        other.preRelease == preRelease &&
        other.buildNumber == buildNumber;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease, buildNumber);

  @override
  String toString() {
    final buffer = StringBuffer('$major.$minor.$patch');
    if (preRelease != null) buffer.write('-$preRelease');
    if (buildNumber != null) buffer.write('+$buildNumber');
    return buffer.toString();
  }
}
