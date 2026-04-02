import 'package:bot_creator/utils/app_diagnostics.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:flutter/material.dart';

class DiagnosticsLogsPage extends StatefulWidget {
  const DiagnosticsLogsPage({super.key});

  @override
  State<DiagnosticsLogsPage> createState() => _DiagnosticsLogsPageState();
}

class _DiagnosticsLogsPageState extends State<DiagnosticsLogsPage> {
  bool _loading = false;
  bool _copying = false;
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
    });

    final text = await AppDiagnostics.readAllLog();
    if (!mounted) {
      return;
    }

    setState(() {
      _logs = text;
      _loading = false;
    });
  }

  Future<void> _copyAll() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _copying = true;
    });

    try {
      await AppDiagnostics.copyLogToClipboard(maxLines: null);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('settings_diagnostics_copied'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _copying = false;
        });
      }
    }
  }

  Future<void> _clearAndReload() async {
    await AppDiagnostics.clearLog();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.t('settings_logs_cleared'))),
    );
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace');

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('settings_diagnostics_page_title')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.t('settings_diagnostics_page_scope_note'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadLogs,
                    icon: const Icon(Icons.refresh),
                    label: Text(AppStrings.t('settings_diagnostics_refresh')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copying ? null : _copyAll,
                    icon:
                        _copying
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.copy_all),
                    label: Text(AppStrings.t('settings_diagnostics_copy_all')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _clearAndReload,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(AppStrings.t('settings_clear_logs')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      _loading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              _logs.trim().isEmpty
                                  ? AppStrings.t('settings_diagnostics_empty')
                                  : _logs,
                              style: bodyStyle,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
