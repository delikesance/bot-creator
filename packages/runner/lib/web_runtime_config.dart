import 'dart:io';

String normalizeRunnerApiToken(String? value) => (value ?? '').trim();

bool isRunnerLoopbackHost(String host) {
  final normalized = host.trim();
  if (normalized.isEmpty) {
    return false;
  }

  final lower = normalized.toLowerCase();
  if (lower == 'localhost') {
    return true;
  }

  final unwrapped =
      normalized.startsWith('[') && normalized.endsWith(']')
          ? normalized.substring(1, normalized.length - 1)
          : normalized;
  final parsed = InternetAddress.tryParse(unwrapped);
  return parsed?.isLoopback ?? false;
}

String? validateRunnerWebConfiguration({
  required String host,
  required String apiToken,
}) {
  if (!isRunnerLoopbackHost(host) && apiToken.trim().isEmpty) {
    return 'BOT_CREATOR_API_TOKEN or --api-token is required when binding the runner to a non-loopback host.';
  }

  return null;
}
