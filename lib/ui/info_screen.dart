import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
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
    final s = AppStrings.of(context);
    final developerMode = context.watch<DeveloperMode>();

    return Scaffold(
      appBar: AppBar(title: Text(s.quickInfoTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          const _VersionCard(),

          SectionHeader(title: s.whatTheAppDoes),
          _TextCard(
            children: [
              Text(s.whatTheAppDoesBody, style: theme.textTheme.bodyMedium),
            ],
          ),

          SectionHeader(title: s.yourData),
          _TextCard(
            children: [
              _Bullet(s.yourDataStorage),
              _Bullet(s.yourDataNoThirdParty),
              _Bullet(s.yourDataNoServer),
              _Bullet(s.yourDataDeletable),
            ],
          ),

          SectionHeader(title: s.legal),
          _TextCard(
            children: [
              _Bullet(s.legalNoAffiliation),
              _Bullet(s.legalUnofficialApi),
              _Bullet(s.legalNoWarranty),
              _Bullet(s.legalNotADiveComputer),
            ],
          ),

          SectionHeader(title: s.sourceAndLicences),
          const _RepositoryCard(),
          const SizedBox(height: AppSpacing.md),
          _ActionCard(
            icon: Icons.description_outlined,
            title: s.openSourceLicences,
            subtitle: s.licencesSubtitle,
            onTap: () => showLicensePage(
              context: context,
              applicationName: s.appName,
              applicationVersion: AppInfo.version,
            ),
          ),

          if (developerMode.enabled) ...[
            SectionHeader(title: s.diagnostics),
            _ActionCard(
              icon: Icons.bug_report_outlined,
              title: s.apiLog,
              subtitle: s.apiLogSubtitle,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const DebugLogScreen())),
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionCard(
              icon: Icons.qr_code_scanner,
              title: s.inspectSsiCode,
              subtitle: s.inspectSsiCodeSubtitle,
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
    final s = AppStrings.of(context);
    final developerMode = context.watch<DeveloperMode>();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: () {
        final unlocked = context.read<DeveloperMode>().registerVersionTap();
        if (!unlocked) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).diagnosticsUnlocked)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.appName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(s.version(AppInfo.version), style: theme.textTheme.bodyMedium),
          if (developerMode.tapsRemaining > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.tapsRemaining(developerMode.tapsRemaining),
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
    final s = AppStrings.of(context);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.sourceCode, style: theme.textTheme.titleMedium),
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
            tooltip: s.copyAddress,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(
                const ClipboardData(text: AppInfo.repositoryUrl),
              );
              messenger.showSnackBar(SnackBar(content: Text(s.addressCopied)));
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
