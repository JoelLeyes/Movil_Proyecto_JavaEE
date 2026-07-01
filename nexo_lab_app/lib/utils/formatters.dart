import 'dart:convert';

import 'package:flutter/material.dart';

String toBackendLocalIso(DateTime dt) {
  final local = dt.toLocal().toIso8601String();
  return local.split('.').first;
}

String? resolvePhotoUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('data:')) {
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

Widget buildProfileAvatar({
  required String name,
  String? photoUrl,
  double radius = 24,
  Color? backgroundColor,
  TextStyle? initialsStyle,
}) {
  final initialsText = initials(name);
  final url = photoUrl?.trim();

  if (url == null || url.isEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFF0C447C),
      child: Text(
        initialsText,
        style: initialsStyle ?? const TextStyle(color: Colors.white),
      ),
    );
  }

  if (url.startsWith('data:')) {
    final commaIndex = url.indexOf(',');
    if (commaIndex > 0) {
      final raw = url.substring(commaIndex + 1);
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(raw)),
        );
      } catch (_) {
        // Fallback to initials.
      }
    }
  }

  final resolved = resolvePhotoUrl(url);
  if (resolved == null) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFF0C447C),
      child: Text(
        initialsText,
        style: initialsStyle ?? const TextStyle(color: Colors.white),
      ),
    );
  }

  return ClipOval(
    child: SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Image.network(
        resolved,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? const Color(0xFF0C447C),
            child: Text(
              initialsText,
              style: initialsStyle ?? const TextStyle(color: Colors.white),
            ),
          );
        },
      ),
    ),
  );
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
