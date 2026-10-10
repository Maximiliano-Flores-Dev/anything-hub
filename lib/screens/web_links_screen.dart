import 'dart:convert';
import 'dart:math' as math;
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/hub_colors.dart';
import '../core/logger.dart';
import '../ui/widgets/gradient_pill_button.dart';

class WebLinkItem {
  const WebLinkItem({
    required this.id,
    required this.title,
    required this.url,
    this.imagePath,
  });

  final String id;
  final String title;
  final String url;
  final String? imagePath;

  String get host => Uri.tryParse(url)?.host ?? '';

  /// Endpoint ligero de favicons. sz=128 se reduce en memoria al tamaño del avatar.
  String get faviconUrl => 'https://www.google.com/s2/favicons?domain=$host&sz=128';

  WebLinkItem copyWith({String? title, String? url}) => WebLinkItem(
        id: id,
        title: title ?? this.title,
        url: url ?? this.url,
        imagePath: imagePath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        if (imagePath != null) 'imagePath': imagePath,
      };

  /// Tolerante a datos corruptos: devuelve null en vez de lanzar.
  static WebLinkItem? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final url = raw['url'];
    if (id is! String || title is! String || url is! String) return null;
    final img = raw['imagePath'];
    return WebLinkItem(
      id: id,
      title: title,
      url: url,
      imagePath: img is String ? img : null,
    );
  }

  /// UUID v4 sin dependencias externas.
  static String newId() {
    final r = math.Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0F) | 0x40; // versión 4
    b[8] = (b[8] & 0x3F) | 0x80; // variante RFC 4122
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}

/// Extrae título y URL de lo que el usuario pegue: "[Título](URL)", una URL
/// completa o un dominio suelto.
abstract final class WebLinkParser {
  static final RegExp _markdown = RegExp(r'^\s*\[([^\]]*)\]\(\s*([^)\s]+)\s*\)\s*$');
  static final RegExp _hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');

  static ({String? title, String raw}) parse(String input) {
    final m = _markdown.firstMatch(input);
    if (m == null) return (title: null, raw: input.trim());
    final t = m.group(1)!.trim();
    return (title: t.isEmpty ? null : t, raw: m.group(2)!.trim());
  }

  /// Devuelve una URL http(s) válida o null. Solo se aceptan http/https, así
  /// que esquemas como javascript: o file: quedan descartados.
  static String? normalizeUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty || s.contains(RegExp(r'\s'))) return null;
    if (!_hasScheme.hasMatch(s)) s = 'https://$s';
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    final okScheme = uri.scheme == 'http' || uri.scheme == 'https';
    final okHost = uri.host == 'localhost' || uri.host.contains('.');
    if (!okScheme || !okHost) return null;
    return uri.toString();
  }

  /// "https://www.youtube.com/..." → "Youtube"
  static String titleFromUrl(String url) {
    var host = Uri.tryParse(url)?.host ?? url;
    if (host.startsWith('www.')) host = host.substring(4);
    final label = host.split('.').first;
    if (label.isEmpty) return host;
    return label[0].toUpperCase() + label.substring(1);
  }
}

/// CRUD + orden persistente. Usa shared_preferences (ya declarado en pubspec)
/// en una clave propia, sin tocar el estado existente de grupos y permisos.
class WebLinkRepository extends ChangeNotifier {
  static const String _key = 'web_links_v1';

  final List<WebLinkItem> _items = [];
  bool _loaded = false;

  List<WebLinkItem> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(list.map(WebLinkItem.tryFromJson).whereType<WebLinkItem>());
      }
    } catch (e) {
      SystemLogger.log('Webs Rápidas ilegibles, se ignoran: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (e) {
      SystemLogger.log('No se pudo guardar Webs Rápidas: $e');
    }
  }

  Future<void> add(WebLinkItem item) async {
    _items.add(item);
    notifyListeners();
    await _persist();
  }

  Future<void> update(WebLinkItem item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i < 0) return;
    _items[i] = item;
    notifyListeners();
    await _persist();
  }

  /// Devuelve la posición que ocupaba, para poder deshacer.
  Future<int> remove(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return -1;
    _items.removeAt(i);
    notifyListeners();
    await _persist();
    return i;
  }

  Future<void> restore(WebLinkItem item, int index) async {
    _items.insert(math.max(0, math.min(index, _items.length)), item);
    notifyListeners();
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1; // convención de ReorderableListView
    if (oldIndex == newIndex) return;
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    notifyListeners();
    await _persist();
  }
}

// ------------------------------------------------------------------ Pantalla
class WebLinksScreen extends StatefulWidget {
  const WebLinksScreen({super.key, required this.repository});

  final WebLinkRepository repository;

  @override
  State<WebLinksScreen> createState() => _WebLinksScreenState();
}

class _WebLinksScreenState extends State<WebLinksScreen> {
  @override
  void initState() {
    super.initState();
    widget.repository.load();
  }

  void _toast(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HubColors.panel,
          action: action,
          content: Text(message, style: TextStyle(color: HubColors.textoPrincipal)),
        ),
      );
  }

  // Delegamos al sistema: sin WebView embebido.
  Future<void> _open(WebLinkItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null || !uri.hasScheme) {
      _toast('El enlace de "${item.title}" no es válido.');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _toast('No se pudo abrir "${item.title}".');
    } catch (e) {
      SystemLogger.log('launchUrl falló para ${item.url}: $e');
      if (mounted) _toast('No se pudo abrir "${item.title}".');
    }
  }

  Future<void> _addOrEdit([WebLinkItem? existing]) async {
    final result = await showDialog<_LinkEditorResult>(
      context: context,
      builder: (_) => _LinkEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    final repo = widget.repository;

    if (result.delete && existing != null) {
      final index = await repo.remove(existing.id);
      if (!mounted) return;
      _toast(
        '"${existing.title}" eliminada',
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: HubColors.pomelo,
          onPressed: () => repo.restore(existing, index),
        ),
      );
    } else if (existing == null) {
      await repo.add(WebLinkItem(
        id: WebLinkItem.newId(),
        title: result.title!,
        url: result.url!,
      ));
    } else {
      await repo.update(existing.copyWith(title: result.title, url: result.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Webs Rápidas',
                      style: TextStyle(
                        color: HubColors.textoPrincipal,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Volver',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: HubColors.textoSecundario, size: 20),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Añadir web',
                        onPressed: () => _addOrEdit(),
                        icon: Icon(Icons.add_rounded, color: HubColors.pomelo, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: HubColors.linea.withOpacity(0.6)),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.repository,
                builder: (context, _) => _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final repo = widget.repository;
    if (!repo.loaded) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: HubColors.pomelo),
        ),
      );
    }

    final items = repo.items;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 40, color: HubColors.textoSecundario),
              const SizedBox(height: 12),
              Text(
                'Aún no tienes webs guardadas',
                style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pega un enlace o un [Título](URL) y se abrirá en tu navegador.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: GradientPillButton(
                  label: 'Añadir web',
                  icon: Icons.add_rounded,
                  onPressed: () => _addOrEdit(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            itemCount: items.length,
            onReorder: repo.reorder,
            proxyDecorator: (child, index, animation) => Material(
              color: HubColors.panel,
              elevation: 6,
              shadowColor: Colors.black,
              borderRadius: BorderRadius.circular(12),
              child: child,
            ),
            itemBuilder: (context, i) {
              final item = items[i];
              return _WebLinkTile(
                key: ValueKey(item.id),
                item: item,
                onOpen: () => _open(item),
                onEdit: () => _addOrEdit(item),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Text(
            'Toca el título para abrir · el ícono para editar · mantén pulsado para reordenar',
            textAlign: TextAlign.center,
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Fila + avatar
class _WebLinkTile extends StatelessWidget {
  const _WebLinkTile({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onEdit,
  });

  final WebLinkItem item;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkResponse(
          onTap: onEdit,
          radius: 26,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 7, 10, 7),
            child: _LinkAvatar(item: item),
          ),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onOpen,
            splashColor: HubColors.pomelo.withOpacity(0.12),
            highlightColor: HubColors.pomelo.withOpacity(0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar circular estricto. Si la imagen falla (sin red, dominio inválido,
/// archivo borrado) cae a una inicial con la paleta de la app.
class _LinkAvatar extends StatelessWidget {
  const _LinkAvatar({required this.item, this.size = 30});

  final WebLinkItem item;
  final double size;

  Widget _letter() {
    final t = item.title.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HubColors.panel,
        shape: BoxShape.circle,
        border: Border.all(color: HubColors.linea),
      ),
      child: Text(
        t.isEmpty ? '?' : t[0].toUpperCase(),
        style: TextStyle(
          color: HubColors.pomelo,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _letter();
    final custom = item.imagePath;
    final isRemoteCustom = custom != null && custom.startsWith('http');
    final isLocal = custom != null && custom.isNotEmpty && !isRemoteCustom;
    // Decodificar a tamaño real del avatar: memoria mínima aunque el origen sea 128 px.
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();

    Widget image;
    if (isLocal) {
      image = Image.file(
        File(custom!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: px,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else if (isRemoteCustom || item.host.isNotEmpty) {
      image = Image.network(
        isRemoteCustom ? custom! : item.faviconUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: px,
        gaplessPlayback: true,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else {
      image = fallback;
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: image),
    );
  }
}

// ------------------------------------------------------------- Diálogo editor
class _LinkEditorResult {
  const _LinkEditorResult.save(this.title, this.url) : delete = false;
  const _LinkEditorResult.delete()
      : title = null,
        url = null,
        delete = true;

  final String? title;
  final String? url;
  final bool delete;
}

// StatefulWidget propio: los controllers se liberan en su dispose(), después de
// terminar la animación de cierre del diálogo.
class _LinkEditorDialog extends StatefulWidget {
  const _LinkEditorDialog({this.existing});

  final WebLinkItem? existing;

  @override
  State<_LinkEditorDialog> createState() => _LinkEditorDialogState();
}

class _LinkEditorDialogState extends State<_LinkEditorDialog> {
  late final TextEditingController _urlCtl;
  late final TextEditingController _titleCtl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtl = TextEditingController(text: widget.existing?.url ?? '');
    _titleCtl = TextEditingController(text: widget.existing?.title ?? '');
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    _titleCtl.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = WebLinkParser.parse(_urlCtl.text);
    final url = WebLinkParser.normalizeUrl(parsed.raw);
    if (url == null) {
      setState(() => _error = 'Enlace no válido. Ejemplo: youtube.com');
      return;
    }
    final typed = _titleCtl.text.trim();
    final title = typed.isNotEmpty
        ? typed
        : (parsed.title ?? WebLinkParser.titleFromUrl(url));
    Navigator.pop(context, _LinkEditorResult.save(title, url));
  }

  InputDecoration _decoration(String label, String hint, {String? helper, String? error}) {
    final line = UnderlineInputBorder(borderSide: BorderSide(color: HubColors.linea));
    final focus = UnderlineInputBorder(borderSide: BorderSide(color: HubColors.pomelo));
    final warn = UnderlineInputBorder(borderSide: BorderSide(color: HubColors.pomeloSuave));
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      errorText: error,
      labelStyle: TextStyle(color: HubColors.textoSecundario),
      floatingLabelStyle: TextStyle(color: HubColors.pomelo),
      hintStyle: TextStyle(color: HubColors.textoSecundario.withOpacity(0.6), fontSize: 13),
      helperStyle: TextStyle(color: HubColors.textoSecundario, fontSize: 11),
      errorStyle: TextStyle(color: HubColors.pomeloSuave),
      enabledBorder: line,
      focusedBorder: focus,
      errorBorder: warn,
      focusedErrorBorder: warn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      backgroundColor: HubColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        editing ? 'Editar web' : 'Añadir web',
        style: TextStyle(color: HubColors.textoPrincipal),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlCtl,
            autofocus: !editing,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: HubColors.textoPrincipal),
            decoration: _decoration(
              'Enlace',
              'youtube.com',
              helper: 'También acepta [Título](https://…)',
              error: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtl,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: HubColors.textoPrincipal),
            decoration: _decoration('Título (opcional)', 'Se toma del enlace si lo dejas vacío'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () => Navigator.pop(context, const _LinkEditorResult.delete()),
            child: Text('Eliminar', style: TextStyle(color: HubColors.pomeloSuave)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: HubColors.pomelo),
          onPressed: _submit,
          child: const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ============================================================================
// ILUSTRACIONES VECTORIALES DE LAS CARDS
// ============================================================================
