import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ssi/ssi_buddies_controller.dart';
import '../ssi/ssi_buddy_code.dart';
import 'ssi_scan_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// The saved SSI buddies: divers who have no Garmin account on this device
/// but who show up as buddies when a dive is exported.
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

enum _BuddyAction { edit, remove }

class _BuddyCard extends StatelessWidget {
  const _BuddyCard({required this.buddy});

  final SsiBuddyCode buddy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return AppCard(
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
                const SizedBox(height: 2),
                Text(
                  'SSI-Nr. ${buddy.memberId}'
                  '${buddy.email != null ? ' · ${buddy.email}' : ''}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<_BuddyAction>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Optionen',
            onSelected: (action) => switch (action) {
              _BuddyAction.edit => enterBuddyManually(context, existing: buddy),
              _BuddyAction.remove =>
                context.read<SsiBuddiesController>().remove(buddy.memberId),
            },
            itemBuilder: (context) => const [
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
