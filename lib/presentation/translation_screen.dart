import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/language.dart';
import '../inference/model_manager.dart';
import 'translation_controller.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key, required this.controller});
  final TranslationController controller;

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.controller.boot();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final direction = controller.direction;
    final busy = controller.isBusy;
    final serviceReady = controller.models.state == ModelState.ready;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/santali_setu_icon.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                semanticLabel: 'Santali Setu app icon',
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Santali Setu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Hindi ↔ Santali speech translation',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: busy ? null : controller.clear,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Text(
                  'A bridge between\nlanguages.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                        letterSpacing: -0.7,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Speak naturally. See your words in the other language.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 22),
                _DirectionCard(
                  direction: direction,
                  enabled: !busy,
                  onSwap: controller.swap,
                ),
                const SizedBox(height: 24),
                _RecordControl(
                  phase: controller.phase,
                  language: direction.source,
                  enabled: serviceReady && !busy,
                  onTap: controller.phase == TranslationPhase.recording
                      ? controller.stopVoice
                      : controller.startVoice,
                ),
                const SizedBox(height: 22),
                if (busy) ...[
                  _ProcessingCard(phase: controller.phase),
                  const SizedBox(height: 16),
                ],
                if (controller.error != null) ...[
                  _ErrorCard(
                    message: controller.error!,
                    onRetry: controller.retry,
                  ),
                  const SizedBox(height: 16),
                ],
                _TextResultCard(
                  title: 'Recognized speech',
                  subtitle: 'In ${direction.source.label}',
                  text: controller.input,
                  emptyTitle: 'Your words will appear here',
                  emptyBody: 'Choose your speaking language above, then tap the microphone.',
                  icon: Icons.graphic_eq_rounded,
                ),
                const SizedBox(height: 14),
                _TranslationResultCard(
                  language: direction.target,
                  text: controller.output,
                  onCopy: controller.output.isEmpty
                      ? null
                      : () => _copy(context, controller.output),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: colors.surface,
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Translation copied'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }
}

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    required this.direction,
    required this.enabled,
    required this.onSwap,
  });

  final TranslationDirection direction;
  final bool enabled;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _LanguageLabel(
                overline: 'SPEAK IN',
                language: direction.source,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Swap languages',
              onPressed: enabled ? onSwap : null,
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
            Expanded(
              child: _LanguageLabel(
                overline: 'TRANSLATE TO',
                language: direction.target,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageLabel extends StatelessWidget {
  const _LanguageLabel({
    required this.overline,
    required this.language,
    this.alignEnd = false,
  });

  final String overline;
  final Language language;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          overline,
          textAlign: textAlign,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          language.label,
          textAlign: textAlign,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _RecordControl extends StatefulWidget {
  const _RecordControl({
    required this.phase,
    required this.language,
    required this.enabled,
    required this.onTap,
  });

  final TranslationPhase phase;
  final Language language;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_RecordControl> createState() => _RecordControlState();
}

class _RecordControlState extends State<_RecordControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  bool get _recording => widget.phase == TranslationPhase.recording;

  @override
  void initState() {
    super.initState();
    if (_recording) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _RecordControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_recording && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_recording && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recording = _recording;
    final label = recording
        ? 'Listening… Tap to finish (up to 30 seconds).'
        : switch (widget.phase) {
            TranslationPhase.booting => 'Getting things ready…',
            TranslationPhase.uploading => 'Sending your recording…',
            TranslationPhase.transcribing => 'Recognizing and translating…',
            TranslationPhase.translating => 'Preparing your translation…',
            TranslationPhase.success => 'Your translation is ready.',
            TranslationPhase.error => 'Try again when you are ready.',
            _ => 'Tap the microphone and speak in ${widget.language.label}.',
          };
    final icon = recording ? Icons.stop_rounded : Icons.mic_rounded;
    final buttonLabel = recording
        ? 'Stop recording'
        : 'Start recording in ${widget.language.label}';

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            label,
            key: ValueKey('$label-${widget.phase}'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final scale = recording ? 1 + (_pulse.value * 0.045) : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 144,
                height: 144,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: recording
                      ? colors.errorContainer.withOpacity(
                          0.75 + (_pulse.value * 0.2),
                        )
                      : colors.primaryContainer.withOpacity(0.8),
                ),
                child: Center(
                  child: Semantics(
                    button: true,
                    label: buttonLabel,
                    child: Material(
                      color: widget.enabled || recording
                          ? (recording ? colors.error : colors.primary)
                          : colors.surfaceVariant,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: (widget.enabled || recording)
                            ? widget.onTap
                            : null,
                        child: SizedBox(
                          width: 108,
                          height: 108,
                          child: Icon(
                            icon,
                            size: 48,
                            color: widget.enabled || recording
                                ? colors.onPrimary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          recording ? 'Listening…' : 'Tap to speak',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({required this.phase});
  final TranslationPhase phase;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      TranslationPhase.uploading => 'Sending your recording…',
      TranslationPhase.transcribing => 'Recognizing speech and preparing translation…',
      TranslationPhase.translating => 'Preparing your translation…',
      _ => 'Working on your translation…',
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextResultCard extends StatelessWidget {
  const _TextResultCard({
    required this.title,
    required this.subtitle,
    required this.text,
    required this.emptyTitle,
    required this.emptyBody,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String text;
  final String emptyTitle;
  final String emptyBody;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEmpty = text.trim().isEmpty;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: isEmpty
                  ? Column(
                      key: const ValueKey('empty-transcript'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emptyTitle,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          emptyBody,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                      ],
                    )
                  : Text(
                      text,
                      key: ValueKey('transcript-$text'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.55,
                            fontSize: 18,
                          ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslationResultCard extends StatelessWidget {
  const _TranslationResultCard({
    required this.language,
    required this.text,
    required this.onCopy,
  });

  final Language language;
  final String text;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEmpty = text.trim().isEmpty;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.primaryContainer.withOpacity(0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.primary.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.translate_rounded, color: colors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Translation',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  language.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Copy translation',
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: isEmpty
                  ? Row(
                      key: const ValueKey('empty-result'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: colors.onSurfaceVariant, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your translation will appear here.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      text,
                      key: ValueKey('translation-$text'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.55,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onErrorContainer,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onErrorContainer,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
