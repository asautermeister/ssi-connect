import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ssi/ssi_buddies_controller.dart';
import '../ssi/ssi_buddy_code.dart';
import 'qr_display_screen.dart';
import 'ssi_scan_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// The saved SSI buddies: divers who have no Garmin account on this device.
///
/// Their member codes are kept so they can be handed on - tapping one shows
/// it as a QR code for someone else's app to scan. They do not travel with
/// an exported dive: SSI's import format has no buddy field, so the picker
/// that used to sit under the dive QR code was removed rather than left
/// looking functional.
///
/// Deliberately its own list rather than a second kind of account - these
/// people can't be logged in and have no dives to fetch here.
class SsiBuddiesScreen extends StatelessWidget {
  const SsiBuddiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSI-Buddies')),
      body: Consumer<SsiBuddiesController>(
        builder: (context, controller, _) {
          if (!controller.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.buddies.isEmpty) {
            return const _EmptyBuddies();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            itemCount: controller.buddies.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) =>
                _BuddyCard(buddy: controller.buddies[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scan(context),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Buddy scannen'),
      ),
    );
  }
}

class _EmptyBuddies extends StatelessWidget {
  const _EmptyBuddies();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 44, color: palette.inkMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Noch keine Buddies gespeichert',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lass dir den QR-Code deines Buddys in der SSI-App unter '
              '„Dein QR-Code" zeigen und scanne ihn hier.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: const Text('Von Hand eintragen'),
              onPressed: () => enterBuddyManually(context),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BuddyAction { showQr, edit, remove }

class _BuddyCard extends StatelessWidget {
  const _BuddyCard({required this.buddy});

  final SsiBuddyCode buddy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    // A buddy without a name is already titled by their number, so only
    // repeat it here when the title is an actual name.
    final subtitle = [
      buddy.memberIdLine,
      buddy.email,
    ].whereType<String>().join(' · ');

    return AppCard(
      // Tapping shows the code, which is the thing you do with a buddy
      // when someone else wants to save them.
      onTap: () => _showQr(context, buddy),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.accentContainer,
            child: Icon(
              Icons.person_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buddy.displayName,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<_BuddyAction>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Optionen',
            onSelected: (action) => switch (action) {
              _BuddyAction.showQr => _showQr(context, buddy),
              _BuddyAction.edit => enterBuddyManually(context, existing: buddy),
              _BuddyAction.remove =>
                context.read<SsiBuddiesController>().remove(buddy.memberId),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _BuddyAction.showQr,
                child: Text('Als QR-Code zeigen'),
              ),
              PopupMenuItem(
                value: _BuddyAction.edit,
                child: Text('Bearbeiten'),
              ),
              PopupMenuItem(
                value: _BuddyAction.remove,
                child: Text('Entfernen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the member as the same kind of code the SSI app shows under
/// "Dein QR-Code", so another device can scan them straight into its own
/// buddy list - including this app's scanner.
void _showQr(BuildContext context, SsiBuddyCode buddy) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QrDisplayScreen(
        title: buddy.displayName,
        payload: buddy.toPayload(),
        caption: 'SSI-Nr. ${buddy.memberId}',
        hint:
            'Mit der Kamera eines anderen Geräts scannen, um diesen Buddy '
            'dort zu speichern.',
      ),
    ),
  );
}

Future<void> _scan(BuildContext context) async {
  final controller = context.read<SsiBuddiesController>();
  final code = await Navigator.of(context).push<SsiBuddyCode>(
    MaterialPageRoute(builder: (_) => const SsiScanScreen()),
  );
  if (code == null) return;
  await controller.save(code);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('${code.displayName} gespeichert')));
}

/// Manual fallback, for a tablet without a working camera or a buddy who
/// only knows their number.
Future<void> enterBuddyManually(
  BuildContext context, {
  SsiBuddyCode? existing,
}) async {
  final controller = context.read<SsiBuddiesController>();
  final buddy = await showDialog<SsiBuddyCode>(
    context: context,
    builder: (_) => _BuddyDialog(existing: existing),
  );
  if (buddy == null) return;
  // Editing the number means a different member - drop the old entry so it
  // doesn't linger as a duplicate of the same person.
  if (existing != null && existing.memberId != buddy.memberId) {
    await controller.remove(existing.memberId);
  }
  await controller.save(buddy);
}

class _BuddyDialog extends StatefulWidget {
  const _BuddyDialog({this.existing});

  final SsiBuddyCode? existing;

  @override
  State<_BuddyDialog> createState() => _BuddyDialogState();
}

class _BuddyDialogState extends State<_BuddyDialog> {
  late final _memberId = TextEditingController(
    text: widget.existing?.memberId ?? '',
  );
  late final _firstName = TextEditingController(
    text: widget.existing?.firstName ?? '',
  );
  late final _lastName = TextEditingController(
    text: widget.existing?.lastName ?? '',
  );

  @override
  void dispose() {
    _memberId.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _submit() {
    final memberId = _memberId.text.trim();
    if (memberId.isEmpty) return;

    String? trimmed(TextEditingController c) {
      final value = c.text.trim();
      return value.isEmpty ? null : value;
    }

    Navigator.of(context).pop(
      SsiBuddyCode(
        memberId: memberId,
        firstName: trimmed(_firstName),
        lastName: trimmed(_lastName),
        // Not asked for: the mail address only arrives via a scan, and
        // typing someone else's in by hand serves no purpose here.
        email: widget.existing?.email,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Buddy anlegen' : 'Buddy bearbeiten',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _memberId,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'SSI-Mitgliedsnummer'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _firstName,
            decoration: const InputDecoration(labelText: 'Vorname'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _lastName,
            decoration: const InputDecoration(labelText: 'Nachname'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(onPressed: _submit, child: const Text('Speichern')),
      ],
    );
  }
}
