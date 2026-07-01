String toBackendLocalIso(DateTime dt) {
  final local = dt.toLocal().toIso8601String();
  return local.split('.').first;
}

String? resolvePhotoUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  final apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nexolab.cloud-ip.cc/api',
  ).trim();
  final baseUri = Uri.parse(apiBase.isEmpty ? 'https://nexolab.cloud-ip.cc/api' : apiBase);
  final origin = '${baseUri.scheme}://${baseUri.authority}';

  if (value.startsWith('/api/')) {
    return '$origin$value';
  }
  if (value.startsWith('api/')) {
    return '$origin/$value';
  }
  if (value.startsWith('/uploads/')) {
    return '$origin/api$value';
  }
  if (value.startsWith('uploads/')) {
    return '$origin/api/$value';
  }

  return value;
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  if (name.isNotEmpty) {
    return name.substring(0, name.length > 2 ? 2 : name.length).toUpperCase();
  }
  return 'NL';
}

String formatTime(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatChatTime(DateTime? dt) {
  if (dt == null) {
    return '';
  }
  final now = DateTime.now();
  final diff = now.difference(dt).inDays;
  if (diff == 0) {
    return formatTime(dt);
  }
  if (diff == 1) {
    return 'ayer';
  }
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
}
