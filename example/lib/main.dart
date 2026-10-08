import 'package:flutter/material.dart';
import 'package:summernote_editor/summernote_editor.dart';

void main() => runApp(const SummernoteEditorExampleApp());

class SummernoteEditorExampleApp extends StatelessWidget {
  const SummernoteEditorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Summernote Editor examples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5b5bd6)),
        useMaterial3: true,
      ),
      home: const EditorExamplesPage(),
    );
  }
}

class EditorExamplesPage extends StatefulWidget {
  const EditorExamplesPage({super.key});

  @override
  State<EditorExamplesPage> createState() => _EditorExamplesPageState();
}

class _EditorExamplesPageState extends State<EditorExamplesPage> {
  final _articleController = SummernoteEditorController();
  final _notesController = SummernoteEditorController();

  bool _articleReady = false;
  bool _notesReady = false;

  Future<void> _showHtml(
    String title,
    SummernoteEditorController controller,
  ) async {
    try {
      final html = await controller.getText();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 420),
            child: SingleChildScrollView(
              child: SelectionArea(
                child: Text(
                  html.isEmpty ? '(empty)' : html,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not read HTML: $error')));
    }
  }

  Future<void> _compareEditors() async {
    try {
      final html = await Future.wait([
        _articleController.getText(),
        _notesController.getText(),
      ]);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Two independent editor values'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 500),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HtmlResult(label: 'Article editor', html: html[0]),
                  const SizedBox(height: 24),
                  _HtmlResult(label: 'Notes editor', html: html[1]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not read editors: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editors = [
      EditorExampleCard(
        key: const ValueKey('article-editor'),
        title: 'Article editor',
        description: 'Seeded text, a link, and an inline image.',
        controller: _articleController,
        initialText: _seededArticle,
        ready: _articleReady,
        onReady: () {
          if (mounted) setState(() => _articleReady = true);
        },
        onShowHtml: () => _showHtml('Article editor HTML', _articleController),
      ),
      EditorExampleCard(
        key: const ValueKey('notes-editor'),
        title: 'Notes editor',
        description: 'A separate controller and independent document.',
        controller: _notesController,
        initialText: _notesArticle,
        ready: _notesReady,
        onReady: () {
          if (mounted) setState(() => _notesReady = true);
        },
        onShowHtml: () => _showHtml('Notes editor HTML', _notesController),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Summernote Editor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multiple editors on one page',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Each editor has its own controller and initial HTML. Use '
                  'the action buttons to enable or disable either editor.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _articleReady && _notesReady
                      ? _compareEditors
                      : null,
                  icon: const Icon(Icons.data_object),
                  label: const Text('Read both editors'),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 1000) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: editors[0]),
                          const SizedBox(width: 20),
                          Expanded(child: editors[1]),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        editors[0],
                        const SizedBox(height: 20),
                        editors[1],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditorExampleCard extends StatefulWidget {
  const EditorExampleCard({
    super.key,
    required this.title,
    required this.description,
    required this.controller,
    required this.initialText,
    required this.ready,
    required this.onReady,
    required this.onShowHtml,
  });

  final String title;
  final String description;
  final SummernoteEditorController controller;
  final String initialText;
  final bool ready;
  final VoidCallback onReady;
  final VoidCallback onShowHtml;

  @override
  State<EditorExampleCard> createState() => _EditorExampleCardState();
}

class _EditorExampleCardState extends State<EditorExampleCard> {
  bool _editorEnabled = true;

  void _toggleEditor() {
    if (_editorEnabled) {
      widget.controller.disable();
    } else {
      widget.controller.enable();
    }

    setState(() {
      _editorEnabled = !_editorEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            Text(widget.description),
            const SizedBox(height: 12),
            SummernoteEditor(
              controller: widget.controller,
              summernoteEditorOptions: SummernoteEditorOptions(
                hint: 'Start writing…',
                initialText: widget.initialText,
                spellCheck: true,
              ),
              otherOptions: const OtherOptions(height: 360),
              callbacks: Callbacks(onInit: widget.onReady),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: widget.ready ? widget.onShowHtml : null,
                  icon: const Icon(Icons.code),
                  label: const Text('Show HTML'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.ready ? _toggleEditor : null,
                  icon: Icon(
                    _editorEnabled
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                  ),
                  label: Text(
                    _editorEnabled ? 'Disable editor' : 'Enable editor',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.ready && _editorEnabled
                      ? () => widget.controller.insertHtml(
                          '<p><strong>Inserted separately</strong> at '
                          '${DateTime.now().toLocal()}.</p>',
                        )
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Insert HTML'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.ready && _editorEnabled
                      ? widget.controller.clear
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HtmlResult extends StatelessWidget {
  const _HtmlResult({required this.label, required this.html});

  final String label;
  final String html;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        SelectionArea(
          child: Text(
            html.isEmpty ? '(empty)' : html,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}

const _seededArticle = '''
<h2>A seeded document</h2>
<p>This content is supplied with <code>SummernoteEditorOptions.initialText</code>.</p>
<p><strong>The image below is embedded in the HTML</strong>, so this example does not depend on a network request.</p>
<p><img alt="Decorative editor banner" style="display:block;max-width:100%;height:auto;border-radius:12px" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0%200%20720%20240'%3E%3Crect width='720' height='240' rx='24' fill='%235b5bd6'/%3E%3Ccircle cx='610' cy='45' r='90' fill='%237f7ff0'/%3E%3Ccircle cx='95' cy='215' r='115' fill='%234545b8'/%3E%3Ctext x='360' y='132' text-anchor='middle' font-family='sans-serif' font-size='38' font-weight='700' fill='white'%3ESummernote%20Editor%3C/text%3E%3C/svg%3E"></p>
<p>Try the toolbar, then select this <a href="https://flutter.dev">link on the final line</a> to open its popover.</p>
''';

const _notesArticle = '''
<h2>Independent notes editor</h2>
<p>This editor has its own controller and document.</p>
<blockquote>Multiple editors can coexist without sharing content, selection, or controller messages.</blockquote>
<ul><li>Edit this list</li><li>Open a toolbar menu</li><li>Read both values together</li></ul>
<p><a href="https://summernote.org">A link on the last line</a></p>
''';
