import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_info.dart';
import 'debug_log_screen.dart';
import 'developer_mode.dart';
import 'ssi_payload_inspect_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// What the app is, who it isn't, and what it does with your data.
///
/// Also the door to the diagnostic tools - three taps on the version.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final developerMode = context.watch<DeveloperMode>();

    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          const _VersionCard(),

          const SectionHeader(title: 'Was die App tut'),
          _TextCard(
            children: [
              Text(
                'SSI Connect liest die Tauchgänge, die deine Garmin-Uhr '
                'ohnehin aufzeichnet, und macht daraus einen QR-Code, den '
                'die SSI-App einlesen kann. Der Code wird auf diesem Gerät '
                'angezeigt und von einem zweiten Gerät abgescannt.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),

          const SectionHeader(title: 'Deine Daten'),
          _TextCard(
            children: [
              _Bullet(
                'Zugangsdaten, SSI-Nummern, Buddies und die zuletzt '
                'geladenen Tauchgänge liegen verschlüsselt im '
                'Schlüsselspeicher dieses Geräts.',
              ),
              _Bullet(
                'Es werden keine Daten an Dritte übertragen. Die einzige '
                'Verbindung nach außen geht zu Garmin, um deine eigenen '
                'Tauchgänge abzurufen.',
              ),
              _Bullet(
                'Es gibt keinen Server und kein Konto bei uns. Die App '
                'entfernen löscht alles.',
              ),
              _Bullet(
                'Gespeicherte Tauchgänge lassen sich jederzeit pro Account '
                'löschen; sie verschwinden auch, wenn du den Account '
                'entfernst.',
              ),
            ],
          ),

          const SectionHeader(title: 'Rechtliches'),
          _TextCard(
            children: [
              _Bullet(
                'Diese App steht in keiner Verbindung zu Garmin Ltd. oder '
                'zu Scuba Schools International (SSI). Beide Namen und '
                'Logos gehören ihren jeweiligen Inhabern und werden hier '
                'nur zur Beschreibung verwendet.',
              ),
              _Bullet(
                'Der Zugriff auf Garmin Connect nutzt eine nicht offiziell '
                'dokumentierte Schnittstelle. Sie kann jederzeit ohne '
                'Vorankündigung brechen.',
              ),
              _Bullet(
                'Die Nutzung erfolgt auf eigene Verantwortung, ohne Gewähr '
                'für Richtigkeit oder Vollständigkeit der übertragenen '
                'Werte. Prüfe jeden Tauchgang, bevor du ihn übernimmst.',
              ),
              _Bullet(
                'Die App ist kein Tauchcomputer, kein Ersatz für einen und '
                'kein Ersatz für eine Tauchausbildung. Sie zeigt nur '
                'Werte, die bereits aufgezeichnet wurden, und berechnet '
                'nichts.',
              ),
            ],
          ),

          const SectionHeader(title: 'Quelltext & Lizenzen'),
          const _RepositoryCard(),
          const SizedBox(height: AppSpacing.md),
          _ActionCard(
            icon: Icons.description_outlined,
            title: 'Open-Source-Lizenzen',
            subtitle: 'Die Lizenzen der verwendeten Pakete',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'SSI Connect',
              applicationVersion: AppInfo.version,
            ),
          ),

          if (developerMode.enabled) ...[
            const SectionHeader(title: 'Diagnose'),
            _ActionCard(
              icon: Icons.bug_report_outlined,
              title: 'API-Protokoll',
              subtitle: 'Aufgezeichnete Garmin-Aufrufe ansehen',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const DebugLogScreen())),
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionCard(
              icon: Icons.qr_code_scanner,
              title: 'SSI-Code analysieren',
              subtitle: 'Felder eines echten SSI-QR-Codes im Klartext',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SsiPayloadInspectScreen(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The version, and the way in to the diagnostic tools.
class _VersionCard extends StatelessWidget {
  const _VersionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final developerMode = context.watch<DeveloperMode>();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: () {
        final unlocked = context.read<DeveloperMode>().registerVersionTap();
        if (!unlocked) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diagnose-Werkzeuge sichtbar')),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SSI Connect', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text('Version ${AppInfo.version}', style: theme.textTheme.bodyMedium),
          if (developerMode.tapsRemaining > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Noch ${developerMode.tapsRemaining}× tippen',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The repository address. Shown as text with a copy button rather than as
/// a link: opening a browser would mean another platform plugin, and this
/// app has been bitten by one of those before.
class _RepositoryCard extends StatelessWidget {
  const _RepositoryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quelltext', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                SelectableText(
                  AppInfo.repositoryUrl,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Adresse kopieren',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(
                const ClipboardData(text: AppInfo.repositoryUrl),
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Adresse kopiert')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: AppSpacing.sm),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: palette.inkMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.accentContainer,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: palette.inkMuted),
        ],
      ),
    );
  }
}
