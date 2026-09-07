import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/android_profile_baseline.dart '
      '<device-id> <package-name>',
    );
    exitCode = 64;
    return;
  }

  final deviceId = arguments[0];
  final packageName = arguments[1];
  final adb = _adbPath();

  Future<String> runAdb(List<String> args) async {
    final result = await Process.run(adb, ['-s', deviceId, ...args]);
    if (result.exitCode != 0) {
      throw ProcessException(
        adb,
        args,
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }
    return result.stdout.toString();
  }

  Future<String> runShell(String command) => runAdb(['shell', command]);

  await runShell('input keyevent KEYCODE_WAKEUP');
  await runShell('wm dismiss-keyguard');
  await runShell('am force-stop $packageName');
  await runShell('am start -W -n $packageName/.MainActivity');

  final sizeOutput = await runShell('wm size');
  final sizes = RegExp(r'(?:Physical|Override) size: (\d+)x(\d+)')
      .allMatches(sizeOutput)
      .toList();
  if (sizes.isEmpty) {
    throw StateError('Unable to read the Android display size.');
  }
  final width = int.parse(sizes.last.group(1)!);
  final height = int.parse(sizes.last.group(2)!);
  final left = (width * 0.2).round();
  final right = (width * 0.8).round();
  final y = (height * 0.45).round();

  final layerList = await runShell('dumpsys SurfaceFlinger --list');
  final layer = layerList.split('\n').firstWhere(
        (line) =>
            line.contains('SurfaceView[$packageName/') &&
            line.contains('(BLAST)'),
        orElse: () => throw StateError(
          'Unable to find the Flutter BLAST Surface for $packageName.',
        ),
      );

  await runShell(
    "dumpsys SurfaceFlinger --latency-clear '${_shellQuote(layer)}'",
  );
  for (var index = 0; index < 16; index++) {
    final fromX = index.isEven ? right : left;
    final toX = index.isEven ? left : right;
    await runShell('input swipe $fromX $y $toX $y 300');
  }

  final latency = await runShell(
    "dumpsys SurfaceFlinger --latency '${_shellQuote(layer)}'",
  );
  final report = _summarizeLatency(latency);
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'deviceId': deviceId,
      'packageName': packageName,
      'surface': layer,
      'gestureCount': 16,
      ...report,
    }),
  );
}

String _adbPath() {
  final sdk = Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'];
  if (sdk != null) {
    return '$sdk/platform-tools/adb';
  }
  final userHome = Platform.environment['HOME'];
  final macOsDefault = '$userHome/Library/Android/sdk/platform-tools/adb';
  return userHome != null && File(macOsDefault).existsSync()
      ? macOsDefault
      : 'adb';
}

String _shellQuote(String value) => value.replaceAll("'", "'\\''");

Map<String, Object> _summarizeLatency(String raw) {
  final lines = raw.trim().split(RegExp(r'\r?\n'));
  final refreshMs = int.parse(lines.first.trim()) / 1000000;
  final presented = <int>[];
  for (final line in lines.skip(1)) {
    final values = line
        .trim()
        .split(RegExp(r'\s+'))
        .map(int.tryParse)
        .toList(growable: false);
    if (values.length == 3 && values.every((value) => value != null)) {
      presented.add(values[1]!);
    }
  }

  final activeIntervals = <double>[];
  for (var index = 1; index < presented.length; index++) {
    final intervalMs = (presented[index] - presented[index - 1]) / 1000000;
    if (intervalMs > 0 && intervalMs <= 100) {
      activeIntervals.add(intervalMs);
    }
  }
  if (activeIntervals.isEmpty) {
    throw StateError('SurfaceFlinger returned no active frame intervals.');
  }

  final sorted = [...activeIntervals]..sort();
  double percentile(double value) =>
      sorted[((sorted.length - 1) * value).round()];
  final jankThreshold = refreshMs * 1.5;
  final jankCount =
      activeIntervals.where((value) => value > jankThreshold).length;
  final missedVsyncs = activeIntervals.fold<int>(
    0,
    (total, value) => total + ((value / refreshMs).round() - 1).clamp(0, 1000),
  );

  return {
    'refreshMs': refreshMs,
    'capturedPresentedFrames': presented.length,
    'activeFrameIntervals': activeIntervals.length,
    'p50Ms': percentile(0.50),
    'p90Ms': percentile(0.90),
    'p95Ms': percentile(0.95),
    'p99Ms': percentile(0.99),
    'maxActiveMs': sorted.last,
    'jankIntervalsOver1_5xRefresh': jankCount,
    'estimatedMissedVsyncs': missedVsyncs,
  };
}
