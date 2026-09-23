import 'package:flutter/material.dart';
import '../core/performance/performance_metrics.dart';
import '../domain/language.dart';
import '../inference/model_manager.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({
    super.key,
    required this.manager,
    required this.direction,
  });
  final ModelManager manager;
  final TranslationDirection direction;
  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  BenchmarkResult? result;
  bool running = false;
  Future<void> _run() async {
    setState(() => running = true);
    try {
      result = await widget.manager.benchmark(widget.direction);
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  String _duration(Duration? d) => d == null ? '—' : '${d.inMilliseconds} ms';
  @override
  Widget build(BuildContext context) {
    final m = widget.manager;
    return Scaffold(
      appBar: AppBar(title: const Text('Performance (developer)')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Model status: ${m.state.name}'),
          Text(
            'Direction: ${widget.direction.source.label} → ${widget.direction.target.label}',
          ),
          Text('Model version: ${m.modelVersion}'),
          Text('Load time: ${_duration(m.modelLoadTime)}'),
          Text('Warm-up time: ${_duration(m.warmUpTime)}'),
          Text('Last translation inference: ${_duration(m.lastInferenceTime)}'),
          Text('Last speech recognition: ${_duration(m.lastSpeechTime)}'),
          Text(
            'Average inference: ${m.averageInferenceMs?.toStringAsFixed(1) ?? '—'} ms',
          ),
          Text('Cached results: ${m.cache.count}'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: running ? null : _run,
            child: Text(running ? 'RUNNING…' : 'RUN BENCHMARK'),
          ),
          if (result != null) ...[
            const SizedBox(height: 18),
            Text(
              'Min: ${_duration(result!.min)}\nAverage: ${_duration(result!.average)}\nMax: ${_duration(result!.max)}\nP95: ${_duration(result!.p95)}',
            ),
          ],
        ],
      ),
    );
  }
}
