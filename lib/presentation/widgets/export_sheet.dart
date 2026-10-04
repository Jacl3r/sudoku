import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/data/services/share_service.dart';
import 'package:sudoku/domain/export/puzzle_export.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/presentation/screens/about_screen.dart';

Future<void> showExportSheet(BuildContext context, GameState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ExportSheet(state: state),
  );
}

class ExportSheet extends StatefulWidget {
  const ExportSheet({required this.state, super.key});

  final GameState state;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  // Remember the last choice for the rest of the session.
  static ExportContent _lastContent = ExportContent.notes;
  static ExportFormat _lastFormat = ExportFormat.pencilmarks;
  static bool _lastPrompt = true;

  late ExportContent content = _lastContent;
  late ExportFormat format = _lastFormat;
  late bool withPrompt = _lastPrompt;
  bool copied = false;
  Timer? _copiedTimer;

  late final PuzzleExport export = PuzzleExport.fromState(widget.state);

  String get text =>
      export.build(content: content, format: format, withPrompt: withPrompt);

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _remember() {
    _lastContent = content;
    _lastFormat = format;
    _lastPrompt = withPrompt;
  }

  Future<void> _copy() async {
    _remember();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => copied = false);
    });
  }

  Future<void> _share() async {
    _remember();
    final opened = await shareText(text);
    if (!opened && mounted) {
      setState(() => copied = true);
    }
  }

  Future<void> _open() async {
    _remember();
    final url = PuzzleExport.toSudokuWikiLink(export.digitsFor(content));
    await launchUrlHelper(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final label = theme.textTheme.labelLarge?.copyWith(
      fontWeight: .bold,
      color: scheme.onSurfaceVariant,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Center(
                child: Text('Export', style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: 20),
              Text('Content', style: label),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ExportContent>(
                  showSelectedIcon: false,
                  segments: [
                    for (final c in ExportContent.values)
                      ButtonSegment(value: c, label: Text(c.label)),
                  ],
                  selected: {content},
                  onSelectionChanged: (s) => setState(() => content = s.first),
                ),
              ),
              const SizedBox(height: 6),
              Text(content.description, style: muted),
              const SizedBox(height: 20),
              Text('Format', style: label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in ExportFormat.values)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: format == f,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => format = f),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(format.description, style: muted),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add AI prompt'),
                subtitle: Text(
                  'Asks for a nudge first, not the solution.',
                  style: muted,
                ),
                value: withPrompt,
                onChanged: (v) => setState(() => withPrompt = v),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const .all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: .circular(6),
                ),
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copy,
                      icon: Icon(
                        copied ? Icons.check_rounded : Icons.copy_rounded,
                      ),
                      label: Text(copied ? 'Copied' : 'Copy'),
                    ),
                  ),
                  Expanded(
                    child: format == ExportFormat.link && !withPrompt
                        ? FilledButton.icon(
                            onPressed: _open,
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open'),
                          )
                        : FilledButton.icon(
                            onPressed: _share,
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
