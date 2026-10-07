import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/hub_colors.dart';
import '../services/puerto_pipe_service.dart';
import 'puerto_limbo_screen.dart';

enum PuertoTrust {
  official,
  fdroid,
  github,
  trustedCatalog,
  gray,
}

class PuertoEntry {
  const PuertoEntry({
    required this.name,
    required this.summary,
    required this.url,
    required this.trust,
    required this.publisher,
    this.packageName,
    this.sha256,
    this.apkUrl,
    this.githubRepo,
  });

  final String name;
  final String summary;
  final String url;
  final PuertoTrust trust;
  final String publisher;
  final String? packageName;
  final String? sha256;
  final String? apkUrl;
  final String? githubRepo;
}

/// Catálogo curado. No hospedamos APK: solo enlaces a origen oficial,
/// F-Droid, GitHub Releases o catálogos conocidos. Zona gris exige aviso.
const kPuertoCatalog = <PuertoEntry>[
  PuertoEntry(
    name: 'Tor Browser',
    summary: 'Navegador con Tor, build oficial del Tor Project.',
    url: 'https://www.torproject.org/download/',
    trust: PuertoTrust.official,
    publisher: 'The Tor Project',
    packageName: 'org.torproject.torbrowser',
  ),
  PuertoEntry(
    name: 'Firefox',
    summary: 'Navegador de Mozilla. APK firmado por Mozilla.',
    url: 'https://www.mozilla.org/firefox/android/',
    trust: PuertoTrust.official,
    publisher: 'Mozilla',
    packageName: 'org.mozilla.firefox',
  ),
  PuertoEntry(
    name: 'Signal',
    summary: 'Mensajería. El APK oficial está en signal.org, no en mirrors.',
    url: 'https://signal.org/download/',
    trust: PuertoTrust.official,
    publisher: 'Signal Messenger',
    packageName: 'org.thoughtcrime.securesms',
  ),
  PuertoEntry(
    name: 'VLC',
    summary: 'Reproductor de VideoLAN. Descarga desde videolan.org.',
    url: 'https://www.videolan.org/vlc/download-android.html',
    trust: PuertoTrust.official,
    publisher: 'VideoLAN',
    packageName: 'org.videolan.vlc',
  ),
  PuertoEntry(
    name: 'LibreOffice',
    summary: 'Visor/editor de documentos. Página oficial Android.',
    url: 'https://www.libreoffice.org/download/android-and-ios/',
    trust: PuertoTrust.official,
    publisher: 'The Document Foundation',
  ),
  PuertoEntry(
    name: 'Thunderbird',
    summary: 'Correo de Mozilla para Android.',
    url: 'https://www.thunderbird.net/mobile/',
    trust: PuertoTrust.official,
    publisher: 'Mozilla',
    packageName: 'net.thunderbird.android',
  ),
  PuertoEntry(
    name: 'Organic Maps',
    summary: 'Mapas offline. Releases firmados en GitHub / web oficial.',
    url: 'https://organicmaps.app/',
    trust: PuertoTrust.official,
    publisher: 'Organic Maps',
    packageName: 'app.organicmaps',
  ),
  PuertoEntry(
    name: 'F-Droid',
    summary: 'Cliente del catálogo de software libre. APK firmado por F-Droid.',
    url: 'https://f-droid.org/',
    trust: PuertoTrust.fdroid,
    publisher: 'F-Droid',
    packageName: 'org.fdroid.fdroid',
    apkUrl: 'https://f-droid.org/F-Droid.apk',
  ),
  PuertoEntry(
    name: 'NewPipe',
    summary: 'Cliente de YouTube sin cuenta. Solo el repo oficial o F-Droid.',
    url: 'https://newpipe.net/',
    trust: PuertoTrust.fdroid,
    publisher: 'Team NewPipe',
    packageName: 'org.schabi.newpipe',
    githubRepo: 'TeamNewPipe/NewPipe',
  ),
  PuertoEntry(
    name: 'AntennaPod',
    summary: 'Podcasts libres. F-Droid o GitHub del proyecto.',
    url: 'https://antennapod.org/',
    trust: PuertoTrust.fdroid,
    publisher: 'AntennaPod',
    packageName: 'de.danoeh.antennapod',
  ),
  PuertoEntry(
    name: 'Aegis',
    summary: 'Autenticador 2FA de código abierto.',
    url: 'https://github.com/beemdevelopment/Aegis/releases',
    trust: PuertoTrust.github,
    publisher: 'beemdevelopment',
    packageName: 'com.beemdevelopment.aegis',
    githubRepo: 'beemdevelopment/Aegis',
  ),
  PuertoEntry(
    name: 'KeePassDX',
    summary: 'Gestor de contraseñas KeePass. Releases del repo oficial.',
    url: 'https://github.com/Kunzisoft/KeePassDX/releases',
    trust: PuertoTrust.github,
    publisher: 'Kunzisoft',
    packageName: 'com.kunzisoft.keepass.free',
    githubRepo: 'Kunzisoft/KeePassDX',
  ),
  PuertoEntry(
    name: 'Obtainium',
    summary: 'Sigue releases oficiales de GitHub/GitLab/F-Droid y avisa de updates.',
    url: 'https://github.com/ImranR98/Obtainium/releases',
    trust: PuertoTrust.trustedCatalog,
    publisher: 'ImranR98',
    packageName: 'dev.imranr.obtainium.fdroid',
    githubRepo: 'ImranR98/Obtainium',
  ),
  PuertoEntry(
    name: 'HappyMod',
    summary:
        'Catálogo de terceros. No podemos garantizar que el APK haga lo que dice. Zona gris.',
    url: 'https://www.happymod.com/',
    trust: PuertoTrust.gray,
    publisher: 'HappyMod',
  ),
];

class PuertoSoftwareScreen extends StatefulWidget {
  const PuertoSoftwareScreen({super.key});

  @override
  State<PuertoSoftwareScreen> createState() => _PuertoSoftwareScreenState();
}

class _PuertoSoftwareScreenState extends State<PuertoSoftwareScreen> {
  PuertoTrust? _filter;

  List<PuertoEntry> get _visible {
    final f = _filter;
    if (f == null) return kPuertoCatalog;
    return kPuertoCatalog.where((e) => e.trust == f).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: HubColors.textoPrincipal),
        title: const Text(
          'Puerto de Software',
          style: TextStyle(
            color: HubColors.textoPrincipal,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Clave VirusTotal',
            icon: const Icon(Icons.key, color: HubColors.textoSecundario),
            onPressed: _askVirusTotalKey,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'El APK entra por un tubo (chunks de 8 KB) a un limbo en caché. Ahí se calcula SHA-256, se lee el manifiesto y, si hay clave, se consulta VirusTotal. Tú decides si instalas.',
              style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('Todos', null),
                _chip('Oficial', PuertoTrust.official),
                _chip('F-Droid', PuertoTrust.fdroid),
                _chip('GitHub', PuertoTrust.github),
                _chip('Confianza', PuertoTrust.trustedCatalog),
                _chip('Zona gris', PuertoTrust.gray),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _card(_visible[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, PuertoTrust? trust) {
    final selected = _filter == trust;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = trust),
        selectedColor: HubColors.pomelo.withOpacity(0.22),
        labelStyle: TextStyle(
          color: selected ? HubColors.pomelo : HubColors.textoSecundario,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: selected ? HubColors.pomelo : HubColors.linea),
        backgroundColor: HubColors.panel,
        checkmarkColor: HubColors.pomelo,
      ),
    );
  }

  Widget _card(PuertoEntry e) {
    final gray = e.trust == PuertoTrust.gray;
    return Material(
      color: HubColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(e),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.name,
                      style: const TextStyle(
                        color: HubColors.textoPrincipal,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _badge(e.trust),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                e.publisher,
                style: const TextStyle(color: HubColors.textoAcento, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                e.summary,
                style: const TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
              if (e.packageName != null) ...[
                const SizedBox(height: 6),
                Text(
                  e.packageName!,
                  style: const TextStyle(
                    color: HubColors.textoSecundario,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                e.sha256 == null
                    ? 'SHA-256 no fijado aquí. Compara el hash con la web del proyecto antes de instalar.'
                    : 'SHA-256 esperado: ${e.sha256}',
                style: TextStyle(
                  color: gray ? const Color(0xFFE53935) : HubColors.textoSecundario,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(PuertoTrust trust) {
    final (label, color) = switch (trust) {
      PuertoTrust.official => ('Oficial', const Color(0xFF3DDC84)),
      PuertoTrust.fdroid => ('F-Droid', const Color(0xFF1976D2)),
      PuertoTrust.github => ('GitHub', HubColors.textoAcento),
      PuertoTrust.trustedCatalog => ('Catálogo', const Color(0xFFFFB300)),
      PuertoTrust.gray => ('Zona gris', const Color(0xFFE53935)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _askVirusTotalKey() async {
    final current = await PuertoPipeService.virusTotalKey();
    if (!mounted) return;
    final ctrl = TextEditingController(text: current ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        title: const Text('VirusTotal', style: TextStyle(color: HubColors.textoPrincipal)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          style: const TextStyle(color: HubColors.textoPrincipal),
          decoration: const InputDecoration(
            hintText: 'API key (solo en el dispositivo)',
            hintStyle: TextStyle(color: HubColors.textoSecundario),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (saved != null) await PuertoPipeService.saveVirusTotalKey(saved);
  }

  Future<void> _open(PuertoEntry e) async {
    if (e.trust == PuertoTrust.gray || (e.apkUrl == null && e.githubRepo == null)) {
      final canPipe = e.apkUrl != null || e.githubRepo != null;
      if (!canPipe) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: HubColors.panel,
            title: const Text('Sin artefacto directo', style: TextStyle(color: HubColors.textoPrincipal)),
            content: Text(
              e.trust == PuertoTrust.gray
                  ? 'No canalizamos este catálogo: no hay un APK firmado único que podamos hashear. Si descargas fuera, ábrelo con el Hub para el análisis.'
                  : 'Esta ficha aún no tiene URL directa de APK. Abre la página oficial y, si bajas el archivo, compártelo con el Hub.',
              style: const TextStyle(color: HubColors.textoSecundario),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cerrar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir página')),
            ],
          ),
        );
        if (ok == true) {
          await launchUrl(Uri.parse(e.url), mode: LaunchMode.externalApplication);
        }
        return;
      }
    }

    if (e.trust == PuertoTrust.gray) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: HubColors.panel,
          title: const Text('Zona gris', style: TextStyle(color: HubColors.textoPrincipal)),
          content: const Text(
            'El tubo igual va a hashear y analizar, pero el origen no es el autor. El resultado es una recomendación, no una autorización.',
            style: TextStyle(color: HubColors.textoSecundario),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Seguir')),
          ],
        ),
      );
      if (ok != true) return;
    }

    var apkUrl = e.apkUrl;
    if (apkUrl == null && e.githubRepo != null) {
      apkUrl = await PuertoPipeService.latestGithubApk(e.githubRepo!);
    }
    if (!mounted) return;
    if (apkUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró un APK https en el release.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuertoLimboScreen(
          name: e.name,
          apkUrl: apkUrl!,
          gray: e.trust == PuertoTrust.gray,
        ),
      ),
    );
  }
}
