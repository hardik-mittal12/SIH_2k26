import 'package:flutter/material.dart';

import '../domain/language.dart';
import '../inference/model_manager.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({
    super.key,
    required this.manager,
    required this.direction,
  });

  final ModelManager manager;
  final TranslationDirection direction;

  String _duration(Duration? value) =>
      value == null ? '—' : '${value.inMilliseconds} ms';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Service timings (developer)')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Backend status: ${manager.state.name}'),
            Text('Direction: ${direction.source.label} → ${direction.target.label}'),
            Text('Service/model: ${manager.modelVersion}'),
            Text('Backend initialization: ${_duration(manager.modelLoadTime)}'),
            Text('Last translation request: ${_duration(manager.lastInferenceTime)}'),
            Text('Last speech-to-text request: ${_duration(manager.lastSpeechTime)}'),
            Text(
              'Average translation request: ${manager.averageInferenceMs?.toStringAsFixed(1) ?? '—'} ms',
            ),
            Text('Cached translation results: ${manager.cache.count}'),
            const SizedBox(height: 16),
            const Text(
              'Live benchmark runs are intentionally not generated from canned sentences. Use native-reviewed Hindi and Santali samples for real integration measurements.',
            ),
          ],
        ),
      );
}
