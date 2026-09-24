import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/performance/performance_metrics.dart';
import '../domain/language.dart';
import '../inference/model_manager.dart';
import 'performance_screen.dart';
import 'translation_controller.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key, required this.controller});
  final TranslationController controller;
  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  late final TextEditingController _input;
  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.controller.input);
    widget.controller.addListener(_sync);
    widget.controller.boot();
  }

  void _sync() {
    if (_input.text != widget.controller.input) {
      _input.value = _input.value.copyWith(
        text: widget.controller.input,
        selection: TextSelection.collapsed(
          offset: widget.controller.input.length,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final busy = c.phase == TranslationPhase.translating ||
        c.phase == TranslationPhase.listening ||
        c.phase == TranslationPhase.booting;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Santali Setu'),
        actions: [
          IconButton(
            tooltip: 'Performance developer panel',
            icon: const Icon(Icons.speed),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PerformanceScreen(
                  manager: c.models,
                  direction: c.direction,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _ModelNotice(),
            const SizedBox(height: 16),
            _DirectionSelector(
              direction: c.direction,
              onSwap: busy ? null : c.swap,
            ),
            const SizedBox(height: 24),
            Text(
              'SOURCE LANGUAGE · ${c.direction.source.label.toUpperCase()}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _input,
              enabled: !busy,
              minLines: 5,
              maxLines: 8,
              onChanged: c.updateInput,
              decoration: InputDecoration(
                hintText: 'Enter ${c.direction.source.label} text',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: c.phase == TranslationPhase.listening
                  ? c.stopVoice
                  : busy
                      ? null
                      : c.startVoice,
              icon: Icon(
                c.phase == TranslationPhase.listening
                    ? Icons.stop_circle_outlined
                    : Icons.mic_none,
              ),
              label: Text(
                c.phase == TranslationPhase.listening
                    ? 'Stop listening'
                    : c.direction.source.speechLabel,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : c.translate,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('TRANSLATE'),
            ),
            if (c.error != null) ...[
              const SizedBox(height: 14),
              _ErrorCard(message: c.error!, onRetry: c.retry),
            ],
            const SizedBox(height: 24),
            Text(
              'TARGET LANGUAGE · ${c.direction.target.label.toUpperCase()}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 140),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                c.output.isEmpty ? 'Translation will appear here.' : c.output,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: c.output.isEmpty
                      ? null
                      : () => Clipboard.setData(ClipboardData(text: c.output)),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Listen'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _StatusCard(controller: c),
          ],
        ),
      ),
    );
  }
}

class _ModelNotice extends StatelessWidget {
  const _ModelNotice();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'On-device AI only. This repository does not package IndicConformer or IndicTrans2 weights. The status below reports whether local inference is available; the production app does not fall back to mock output.',
        ),
      );
}

class _DirectionSelector extends StatelessWidget {
  const _DirectionSelector({required this.direction, this.onSwap});
  final TranslationDirection direction;
  final VoidCallback? onSwap;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            direction.source.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Swap language direction',
            onPressed: onSwap,
          ),
          Text(
            direction.target.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.error_outline),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});
  final TranslationController controller;
  @override
  Widget build(BuildContext context) {
    final ready = controller.models.state == ModelState.ready;
    final failed = controller.models.state == ModelState.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ready ? Icons.check_circle : Icons.pending,
                  color: ready ? Colors.green : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ready
                        ? 'Local inference runtime ready'
                        : failed
                            ? 'Local models unavailable'
                            : 'Checking local model availability',
                  ),
                ),
              ],
            ),
            if (controller.metrics != null) ...[
              const SizedBox(height: 8),
              _MetricsText(metrics: controller.metrics!),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricsText extends StatelessWidget {
  const _MetricsText({required this.metrics});
  final TranslationMetrics metrics;
  @override
  Widget build(BuildContext context) => Text(
        metrics.fromCache
            ? 'Response: instant (cached)'
            : '${metrics.speechRecognition == null ? '' : 'Speech: ${metrics.speechRecognition!.inMilliseconds} ms · '}Pre: ${metrics.preprocessing.inMilliseconds} ms · Translation: ${metrics.inference.inMilliseconds} ms · Post: ${metrics.postprocessing.inMilliseconds} ms\nResponse: ${metrics.totalLabel}',
      );
}
