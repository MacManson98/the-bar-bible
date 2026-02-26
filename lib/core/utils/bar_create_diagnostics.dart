import 'dart:async';

import 'package:flutter/foundation.dart';

class BarCreateDiagnosticsFlow {
  static int _nextFlowId = 1;

  final bool _enabled;
  final int _id;
  final String _owner;
  final Stopwatch _stopwatch;
  final List<_StepEntry> _steps = <_StepEntry>[];
  final Map<String, int> _counters = <String, int>{};
  Timer? _stallTimer;
  int _lastTickMs = 0;
  int _createSetStateCount = 0;
  bool _finished = false;

  BarCreateDiagnosticsFlow._(this._enabled, this._id, this._owner)
    : _stopwatch = Stopwatch()..start();

  factory BarCreateDiagnosticsFlow.start(String owner) {
    if (!kDebugMode) {
      return BarCreateDiagnosticsFlow._(false, 0, owner);
    }
    final flow = BarCreateDiagnosticsFlow._(true, _nextFlowId++, owner);
    flow.step('flowStart');
    flow.startStallDetector();
    return flow;
  }

  bool get enabled => _enabled;
  int get id => _id;

  void step(String stepName) {
    if (!_enabled || _finished) return;
    final elapsed = _stopwatch.elapsedMilliseconds;
    _steps.add(_StepEntry(stepName, elapsed));
    debugPrint(
      '[BAR_CREATE#$_id +${elapsed.toString().padLeft(4, '0')}ms]'
      '[$_owner] Step: $stepName',
    );
  }

  void incrementSetState(String reason) {
    if (!_enabled || _finished) return;
    _createSetStateCount++;
    debugPrint(
      '[BAR_CREATE#$_id +${_stopwatch.elapsedMilliseconds.toString().padLeft(4, '0')}ms]'
      '[$_owner] setState(createPath): $reason (#$_createSetStateCount)',
    );
  }

  void incrementCounter(
    String key, {
    int warnThreshold = 3,
    StackTrace? stackTrace,
  }) {
    if (!_enabled || _finished) return;
    final next = (_counters[key] ?? 0) + 1;
    _counters[key] = next;
    if (next > warnThreshold) {
      final stack = _trimStack(stackTrace ?? StackTrace.current);
      debugPrint(
        '[BAR_CREATE#$_id][$_owner] WARNING: counter "$key" hit $next. '
        'Possible loop.\n$stack',
      );
    }
  }

  void startStallDetector() {
    if (!_enabled || _finished) return;
    _lastTickMs = _stopwatch.elapsedMilliseconds;
    _stallTimer?.cancel();
    _stallTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_finished) return;
      final nowMs = _stopwatch.elapsedMilliseconds;
      final delta = nowMs - _lastTickMs;
      _lastTickMs = nowMs;
      if (delta <= 900) return;
      final stack = StackTrace.current;
      debugPrint(
        '[BAR_CREATE#$_id][$_owner] MAIN THREAD STALL detected: '
        '${delta - 100}ms delayed tick',
      );
      debugPrint('[BAR_CREATE#$_id][$_owner] Stack:\n${_trimStack(stack)}');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError(
            'Main thread stall during bar create flow #$_id ($_owner)',
          ),
          stack: stack,
          library: 'bar_create_diagnostics',
          context: ErrorDescription('While running bar create flow'),
        ),
      );
    });
  }

  void finish({String result = 'completed'}) {
    if (!_enabled || _finished) return;
    step('flowEnd:$result');
    _finished = true;
    _stallTimer?.cancel();
    _stopwatch.stop();
    final total = _stopwatch.elapsedMilliseconds;
    debugPrint('[BAR_CREATE#$_id][$_owner] Summary start (total ${total}ms)');
    if (_steps.length > 1) {
      for (var i = 0; i < _steps.length - 1; i++) {
        final start = _steps[i];
        final end = _steps[i + 1];
        final delta = end.elapsedMs - start.elapsedMs;
        debugPrint(
          '[BAR_CREATE#$_id][$_owner]  - ${start.name.padRight(32)} ${delta}ms',
        );
      }
    }
    debugPrint(
      '[BAR_CREATE#$_id][$_owner] Counters: '
      'setStateInCreate=$_createSetStateCount, '
      '${_counters.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
    );
    debugPrint('[BAR_CREATE#$_id][$_owner] Summary end');
  }

  String get owner => _owner;

  static String _trimStack(StackTrace stack, {int maxLines = 8}) {
    final lines = stack.toString().split('\n');
    return lines.take(maxLines).join('\n');
  }
}

class _StepEntry {
  final String name;
  final int elapsedMs;
  const _StepEntry(this.name, this.elapsedMs);
}
