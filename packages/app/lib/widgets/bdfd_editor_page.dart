import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator_shared/utils/bdfd_autocomplete.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:bot_creator_shared/utils/bdfd_signature_hints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _BdfdSyntaxColors {
  static const Color function = Color(0xFFFF9800);
  static const Color bracket = Color(0xFF00ACC1);
  static const Color semicolon = Color(0xFFEF5350);
  static const Color text = Color(0xFFE0E0E0);
}

class BdfdSyntaxController extends TextEditingController {
  BdfdSyntaxController({super.text});

  final BdfdLexer _lexer = BdfdLexer();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    if (source.isEmpty) {
      return TextSpan(text: '', style: style);
    }

    final result = _lexer.tokenize(source);
    final children = <TextSpan>[];

    for (final token in result.tokens) {
      if (token.type == BdfdTokenType.eof) {
        continue;
      }

      final Color color;
      switch (token.type) {
        case BdfdTokenType.function:
          color = _BdfdSyntaxColors.function;
        case BdfdTokenType.openBracket:
        case BdfdTokenType.closeBracket:
          color = _BdfdSyntaxColors.bracket;
        case BdfdTokenType.semicolon:
          color = _BdfdSyntaxColors.semicolon;
        default:
          color = _BdfdSyntaxColors.text;
      }

      children.add(
        TextSpan(text: token.lexeme, style: style?.copyWith(color: color)),
      );
    }

    return TextSpan(style: style, children: children);
  }
}

final RegExp _bdfdIdentifierChar = RegExp(r'[A-Za-z0-9_]');
const int _minAutocompletePrefixLength = 2;
const int _maxAutocompleteItems = 6;

class BdfdEditorPage extends StatefulWidget {
  const BdfdEditorPage({super.key, required this.initialCode, this.title});

  final String initialCode;
  final String? title;

  @override
  State<BdfdEditorPage> createState() => _BdfdEditorPageState();
}

class _BdfdEditorPageState extends State<BdfdEditorPage> {
  late final BdfdSyntaxController _controller;
  final BdfdCompiler _compiler = BdfdCompiler();
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _editorHorizontalScrollController = ScrollController();
  final ScrollController _lineNumberScrollController = ScrollController();
  final FocusNode _editorFocusNode = FocusNode();

  BdfdCompileResult? _compileResult;
  bool _wordWrap = false;
  bool _showDiagnostics = true;
  int _autocompleteSelectedIndex = 0;
  List<MapEntry<String, String>> _autocompleteEntries =
      const <MapEntry<String, String>>[];
  BdfdSignatureContext? _signatureContext;
  final BdfdLexer _signatureLexer = BdfdLexer();

  bool get _isDesktopLike {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    _controller = BdfdSyntaxController(text: widget.initialCode);
    _controller.addListener(_updateAutocomplete);
    _controller.addListener(_updateSignatureHint);
    _editorScrollController.addListener(_syncLineNumberScroll);
    _recompile();
  }

  @override
  void dispose() {
    _controller.removeListener(_updateAutocomplete);
    _controller.removeListener(_updateSignatureHint);
    _editorScrollController.removeListener(_syncLineNumberScroll);
    _editorScrollController.dispose();
    _editorHorizontalScrollController.dispose();
    _lineNumberScrollController.dispose();
    _editorFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _isAutocompleteVisible =>
      _autocompleteEntries.isNotEmpty && _editorFocusNode.hasFocus;

  bool get _isSignatureHintVisible =>
      _signatureContext != null &&
      _editorFocusNode.hasFocus &&
      !_isAutocompleteVisible;

  void _syncLineNumberScroll() {
    if (_lineNumberScrollController.hasClients &&
        _editorScrollController.hasClients) {
      _lineNumberScrollController.jumpTo(_editorScrollController.offset);
    }

    if (_isAutocompleteVisible && mounted) {
      setState(() {});
    }
  }

  bool _sameEntries(
    List<MapEntry<String, String>> a,
    List<MapEntry<String, String>> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key || a[i].value != b[i].value) {
        return false;
      }
    }
    return true;
  }

  int _findPrefixStart(String text, int caretOffset) {
    if (caretOffset <= 0 || caretOffset > text.length) {
      return -1;
    }

    var i = caretOffset - 1;
    while (i >= 0) {
      final c = text[i];
      if (_bdfdIdentifierChar.hasMatch(c)) {
        i -= 1;
        continue;
      }
      if (c == r'$') {
        return i;
      }
      return -1;
    }

    return -1;
  }

  List<MapEntry<String, String>> _computeAutocompleteEntries() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) {
      return const <MapEntry<String, String>>[];
    }

    final caret = sel.baseOffset;
    final start = _findPrefixStart(text, caret);
    if (start < 0) {
      return const <MapEntry<String, String>>[];
    }

    final prefix = text.substring(start + 1, caret).toLowerCase();
    if (prefix.length < _minAutocompletePrefixLength) {
      return const <MapEntry<String, String>>[];
    }

    final matches = bdfdAutocompleteTemplates.entries
      .where((entry) => entry.key.startsWith(prefix))
      .toList(growable: false)..sort((a, b) => a.key.compareTo(b.key));

    if (matches.length == 1 && matches.first.key == prefix) {
      return const <MapEntry<String, String>>[];
    }

    return matches.take(_maxAutocompleteItems).toList(growable: false);
  }

  void _updateAutocomplete() {
    if (!_editorFocusNode.hasFocus) {
      if (_autocompleteEntries.isNotEmpty) {
        setState(() {
          _autocompleteEntries = const <MapEntry<String, String>>[];
          _autocompleteSelectedIndex = 0;
        });
      }
      return;
    }

    final entries = _computeAutocompleteEntries();
    if (entries.length != _autocompleteEntries.length ||
        !_sameEntries(entries, _autocompleteEntries)) {
      final previousValue =
          (_autocompleteEntries.isNotEmpty &&
                  _autocompleteSelectedIndex >= 0 &&
                  _autocompleteSelectedIndex < _autocompleteEntries.length)
              ? _autocompleteEntries[_autocompleteSelectedIndex].value
              : null;

      setState(() {
        _autocompleteEntries = entries;
        if (entries.isEmpty) {
          _autocompleteSelectedIndex = 0;
        } else if (previousValue != null) {
          final restored = entries.indexWhere((e) => e.value == previousValue);
          _autocompleteSelectedIndex = restored >= 0 ? restored : 0;
        } else {
          _autocompleteSelectedIndex = 0;
        }
      });
    }
  }

  void _updateSignatureHint() {
    final source = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid || source.isEmpty) {
      if (_signatureContext != null) {
        setState(() => _signatureContext = null);
      }
      return;
    }

    final caret = sel.baseOffset;
    final lexerResult = _signatureLexer.tokenize(source);
    final ctx = bdfdSignatureContextAt(source, caret, lexerResult);

    if (ctx != _signatureContext) {
      final changed =
          ctx?.functionName != _signatureContext?.functionName ||
          ctx?.activeIndex != _signatureContext?.activeIndex;
      if (changed || (ctx == null) != (_signatureContext == null)) {
        setState(() => _signatureContext = ctx);
      }
    }
  }

  KeyEventResult _handleEditorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_isDesktopLike || !_isAutocompleteVisible) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _autocompleteEntries = const <MapEntry<String, String>>[];
        _autocompleteSelectedIndex = 0;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _autocompleteSelectedIndex =
            (_autocompleteSelectedIndex + 1) % _autocompleteEntries.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _autocompleteSelectedIndex =
            (_autocompleteSelectedIndex - 1 + _autocompleteEntries.length) %
            _autocompleteEntries.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      final idx = _autocompleteSelectedIndex.clamp(
        0,
        _autocompleteEntries.length - 1,
      );
      _insertAutocompleteTemplate(_autocompleteEntries[idx].value);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _insertAutocompleteTemplate(String template) {
    final text = _controller.text;
    final sel = _controller.selection;
    final caret = sel.isValid ? sel.baseOffset : text.length;
    final start = _findPrefixStart(text, caret);
    if (start < 0) {
      return;
    }

    final replaced = text.replaceRange(start, caret, template);
    final bracketIdx = template.indexOf('[]');
    final nextOffset =
        bracketIdx >= 0 ? start + bracketIdx + 1 : start + template.length;

    _controller.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: nextOffset),
    );

    setState(() {
      _recompile();
      _autocompleteEntries = const <MapEntry<String, String>>[];
      _autocompleteSelectedIndex = 0;
    });

    _editorFocusNode.requestFocus();
  }

  void _recompile() {
    final source = _controller.text;
    if (source.trim().isEmpty) {
      _compileResult = null;
      return;
    }
    _compileResult = _compiler.compile(source);
  }

  List<BdfdCompileDiagnostic> get _diagnostics =>
      _compileResult?.diagnostics ?? const <BdfdCompileDiagnostic>[];

  bool get _hasErrors => _diagnostics.any(
    (d) => d.severity == BdfdCompileDiagnosticSeverity.error,
  );

  int get _lineCount => '\n'.allMatches(_controller.text).length + 1;

  double get _lineNumberGutterWidth {
    final count = _lineCount;
    return count > 999 ? 56.0 : (count > 99 ? 48.0 : 40.0);
  }

  ({int line, int column}) _caretLineColumn() {
    final sel = _controller.selection;
    final caret = sel.isValid ? sel.baseOffset : _controller.text.length;
    final safe = caret.clamp(0, _controller.text.length);
    final before = _controller.text.substring(0, safe);
    final lines = before.split('\n');
    return (line: lines.length - 1, column: lines.last.length);
  }

  void _done() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFF263238),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF252526) : const Color(0xFF37474F),
        title: Text(
          widget.title ?? AppStrings.t('bdfd_editor_title'),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: AppStrings.t('bdfd_editor_wrap_toggle'),
            icon: Icon(
              _wordWrap ? Icons.wrap_text : Icons.format_align_left,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _wordWrap = !_wordWrap),
          ),
          IconButton(
            tooltip: AppStrings.t('bdfd_editor_diagnostics_toggle'),
            icon: Icon(
              _showDiagnostics ? Icons.bug_report : Icons.bug_report_outlined,
              color:
                  _hasErrors
                      ? Colors.redAccent
                      : (_diagnostics.isNotEmpty
                          ? Colors.orangeAccent
                          : Colors.green),
            ),
            onPressed:
                () => setState(() => _showDiagnostics = !_showDiagnostics),
          ),
          TextButton(
            onPressed: _done,
            child: Text(
              AppStrings.t('done'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildEditorBody()),
          if (_showDiagnostics) _buildDiagnosticsBar(),
        ],
      ),
    );
  }

  Widget _buildEditorBody() {
    final editorField = _buildTextField();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_wordWrap) {
          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildLineNumbers(), Expanded(child: editorField)],
              ),
              _buildSignatureHintOverlay(constraints),
              _buildAutocompleteOverlay(constraints),
            ],
          );
        }

        return Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLineNumbers(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _editorHorizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicWidth(child: editorField),
                  ),
                ),
              ],
            ),
            _buildSignatureHintOverlay(constraints),
            _buildAutocompleteOverlay(constraints),
          ],
        );
      },
    );
  }

  Widget _buildSignatureHintOverlay(BoxConstraints constraints) {
    if (!_isSignatureHintVisible) {
      return const SizedBox.shrink();
    }

    final ctx = _signatureContext!;

    const lineHeight = 20.0;
    const charWidth = 7.8;
    const editorTopPadding = 12.0;
    const editorLeftPadding = 8.0;

    final caret = _caretLineColumn();

    final scrollY =
        _editorScrollController.hasClients
            ? _editorScrollController.offset
            : 0.0;
    final scrollX =
        (!_wordWrap && _editorHorizontalScrollController.hasClients)
            ? _editorHorizontalScrollController.offset
            : 0.0;

    final desiredLeft =
        _lineNumberGutterWidth +
        editorLeftPadding +
        (caret.column * charWidth) -
        scrollX;
    // Position above the current line.
    final desiredTop =
        editorTopPadding + (caret.line * lineHeight) - scrollY - 32;

    final maxLeft = (constraints.maxWidth - 320).clamp(0.0, double.infinity);
    final left = desiredLeft.clamp(_lineNumberGutterWidth + 4, maxLeft);
    final top = desiredTop.clamp(0.0, constraints.maxHeight - 40);

    // Build the parameter spans with the active one highlighted.
    final spans = <InlineSpan>[];
    spans.add(
      TextSpan(
        text: '${ctx.functionName}[ ',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: _BdfdSyntaxColors.function,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    for (var i = 0; i < ctx.parameters.length; i++) {
      if (i > 0) {
        spans.add(
          const TextSpan(
            text: ' ; ',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: _BdfdSyntaxColors.semicolon,
            ),
          ),
        );
      }

      final isActive = i == ctx.activeIndex;
      spans.add(
        TextSpan(
          text: ctx.parameters[i],
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: isActive ? Colors.white : Colors.grey.shade500,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            decoration: isActive ? TextDecoration.underline : null,
            decorationColor: isActive ? Colors.blue.shade300 : null,
          ),
        ),
      );
    }

    spans.add(
      const TextSpan(
        text: ' ]',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: _BdfdSyntaxColors.bracket,
        ),
      ),
    );

    return Positioned(
      left: left,
      top: top,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFF1E293B),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: RichText(text: TextSpan(children: spans)),
        ),
      ),
    );
  }

  Widget _buildAutocompleteOverlay(BoxConstraints constraints) {
    if (!_isAutocompleteVisible) {
      return const SizedBox.shrink();
    }

    const lineHeight = 20.0;
    const charWidth = 7.8;
    const editorTopPadding = 12.0;
    const editorLeftPadding = 8.0;
    const itemHeight = 30.0;
    const panelVerticalPadding = 8.0;
    const panelMaxHeight = 168.0;

    final caret = _caretLineColumn();
    final panelHeight = (_autocompleteEntries.length * itemHeight +
            panelVerticalPadding)
        .clamp(80.0, panelMaxHeight);

    final scrollY =
        _editorScrollController.hasClients
            ? _editorScrollController.offset
            : 0.0;
    final scrollX =
        (!_wordWrap && _editorHorizontalScrollController.hasClients)
            ? _editorHorizontalScrollController.offset
            : 0.0;

    final desiredLeft =
        _lineNumberGutterWidth +
        editorLeftPadding +
        (caret.column * charWidth) -
        scrollX;
    final desiredTop =
        editorTopPadding + ((caret.line + 1) * lineHeight) - scrollY + 4;

    final maxLeft = (constraints.maxWidth - 220).clamp(0.0, double.infinity);
    final left = desiredLeft.clamp(_lineNumberGutterWidth + 4, maxLeft);
    final minTop = editorTopPadding + lineHeight;
    final maxTop = (constraints.maxHeight - panelHeight).clamp(
      minTop,
      double.infinity,
    );
    final top = desiredTop.clamp(minTop, maxTop);

    return Positioned(
      left: left,
      top: top,
      width: 220,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF22313A),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: panelMaxHeight),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _autocompleteEntries.length,
            itemBuilder: (_, index) {
              final entry = _autocompleteEntries[index];
              final isSelected = index == _autocompleteSelectedIndex;
              return InkWell(
                onHover: (hovering) {
                  if (hovering && _autocompleteSelectedIndex != index) {
                    setState(() {
                      _autocompleteSelectedIndex = index;
                    });
                  }
                },
                onTap: () => _insertAutocompleteTemplate(entry.value),
                child: Container(
                  height: itemHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? const Color(0xFF094771)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        entry.value.contains('\n')
                            ? Icons.segment
                            : Icons.functions,
                        size: 14,
                        color: isSelected ? Colors.white : Colors.blue.shade200,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value.replaceAll('\n', ' ↵ '),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.blueGrey.shade50,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              isSelected
                                  ? Colors.white70
                                  : Colors.blueGrey.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLineNumbers() {
    final count = _lineCount;

    return SizedBox(
      width: _lineNumberGutterWidth,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          controller: _lineNumberScrollController,
          itemCount: count,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12),
          itemBuilder: (_, index) {
            return SizedBox(
              height: 20,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.54,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Focus(
      onKeyEvent: _handleEditorKey,
      child: TextField(
        controller: _controller,
        focusNode: _editorFocusNode,
        scrollController: _editorScrollController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.54,
          color: _BdfdSyntaxColors.text,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          hintText: AppStrings.t('cmd_bdfd_script_hint'),
          hintStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        cursorColor: Colors.white,
        onChanged: (_) => setState(_recompile),
      ),
    );
  }

  Widget _buildDiagnosticsBar() {
    final diagnostics = _diagnostics;
    final isEmpty = _controller.text.trim().isEmpty;

    if (isEmpty || diagnostics.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade900.withValues(alpha: 0.5),
          border: Border(top: BorderSide(color: Colors.green.shade700)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Colors.green.shade300,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEmpty
                    ? AppStrings.t('bdfd_editor_empty')
                    : AppStrings.t('cmd_bdfd_diagnostics_clean'),
                style: TextStyle(fontSize: 12, color: Colors.green.shade200),
              ),
            ),
          ],
        ),
      );
    }

    final bgColor =
        _hasErrors
            ? Colors.red.shade900.withValues(alpha: 0.5)
            : Colors.orange.shade900.withValues(alpha: 0.5);
    final borderColor =
        _hasErrors ? Colors.red.shade700 : Colors.orange.shade700;

    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: ListView(
        shrinkWrap: true,
        children:
            diagnostics.map((d) {
              final isError = d.severity == BdfdCompileDiagnosticSeverity.error;
              final icon =
                  isError ? Icons.error_outline : Icons.warning_amber_rounded;
              final color =
                  isError ? Colors.red.shade200 : Colors.orange.shade200;
              final loc =
                  (d.line != null && d.column != null)
                      ? 'L${d.line}:C${d.column} '
                      : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$loc${d.message}',
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}
