import 'dart:io';

import 'soundpad_api_service.dart';

class NetworkDiscoveryService {
  const NetworkDiscoveryService(this._apiService);

  final SoundpadApiService _apiService;

  Future<List<String>> discoverHosts({
    Duration timeoutPerHost = const Duration(milliseconds: 350),
    int batchSize = 40,
  }) async {
    final candidates = await _buildCandidateHosts();
    if (candidates.isEmpty) {
      return const [];
    }

    final reachable = <String>[];
    for (int i = 0; i < candidates.length; i += batchSize) {
      final upperBound = (i + batchSize) > candidates.length
          ? candidates.length
          : (i + batchSize);
      final batch = candidates.sublist(i, upperBound);

      final results = await Future.wait(
        batch.map((host) async {
          final ok = await _apiService.isHealthy(host, timeout: timeoutPerHost);
          return ok ? host : null;
        }),
      );

      reachable.addAll(results.whereType<String>());
    }

    reachable.sort((a, b) {
      if (a == '127.0.0.1') {
        return -1;
      }
      if (b == '127.0.0.1') {
        return 1;
      }
      return a.compareTo(b);
    });

    return reachable;
  }

  Future<List<String>> _buildCandidateHosts() async {
    final hosts = <String>{'127.0.0.1'};
    final prefixes = <String>{};

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );

      for (final networkInterface in interfaces) {
        for (final address in networkInterface.addresses) {
          final rawAddress = address.address;
          final parts = rawAddress.split('.');
          if (parts.length != 4) {
            continue;
          }
          hosts.add(rawAddress);
          prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
    } catch (_) {
      // Keep localhost fallback.
    }

    for (final prefix in prefixes) {
      for (int i = 1; i <= 254; i++) {
        hosts.add('$prefix.$i');
      }
    }

    return hosts.toList(growable: false);
  }
}
