import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../accounts/accounts_controller.dart';
import '../models/dive.dart';
import '../ssi/ssi_buddies_controller.dart';
import '../ssi/ssi_buddy_code.dart';
import '../ssi/ssi_buddy_directory.dart';
import '../ssi/ssi_qr_payload_builder.dart';
import 'format.dart';
import 'ssi_buddies_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/error_state.dart';

/// Full-screen, high-contrast QR code for the SSI app's scanner.
///
/// Always light with a white quiet zone regardless of app theme: this is a
/// scan target, and a dark-mode QR code is unreliable for camera scanners.
/// The dive is restated above it so the right one is being exported.
class QrScreen extends StatefulWidget {
  const QrScreen({super.key, required this.dive, this.diver});

  final Dive dive;

  /// SSI member the dive belongs to. When set, the payload attributes the
  /// dive to them; otherwise SSI files it under whoever is logged in.
  final SsiBuddyCode? diver;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  /// Member numbers of the buddies ticked for this dive. Kept per screen:
  /// buddies change from dive to dive, so carrying a selection over would
  /// be the wrong default more often than the right one.
  final _selectedMemberIds = <String>{};

  @override
  Widget build(BuildContext context) {
    String? payload;
    String? error;
    try {
      payload = SsiQrPayloadBuilder.build(widget.dive, diver: widget.diver);
    } on ArgumentError catch (e) {
      error = e.message.toString();
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('QR-Code')),
        body: ErrorState(icon: Icons.error_outline, message: error),
      );
    }

    final candidates = ssiBuddyCandidates(
      accountIdentities: context
          .watch<AccountsController>()
          .accounts
          .map((a) => a.ssiIdentity)
          .whereType<SsiBuddyCode>(),
      savedBuddies: context.watch<SsiBuddiesController>().buddies,
      diver: widget.diver,
    );
    final selected = candidates
        .where((b) => _selectedMemberIds.contains(b.memberId))
        .toList();

    return Theme(
      data: AppTheme.light(),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final palette = theme.extension<AppPalette>()!;

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: const Text('Mit SSI-App scannen'),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                children: [
                  Text(
                    '${Fmt.date(widget.dive.dateTime)} · '
                    '${Fmt.meters(widget.dive.maxDepthMeters)} m · '
                    '${Fmt.minutes(widget.dive.duration)} min',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: QrImageView(
                        data: payload!,
                        size: 380,
                        backgroundColor: Colors.white,
                        // Quiet zone: scanners need clear margin.
                        padding: const EdgeInsets.all(AppSpacing.lg),
                      ),
                    ),
                  ),
                  Text(
                    'In der SSI-App einen Tauchgang hinzufügen und '
                    '„QR-Code scannen" wählen.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.inkMuted,
                    ),
                  ),
                  const SectionHeader(title: 'Buddies'),
                  _BuddyPicker(
                    candidates: candidates,
                    selectedMemberIds: _selectedMemberIds,
                    onToggle: (memberId, isSelected) => setState(() {
                      if (isSelected) {
                        _selectedMemberIds.add(memberId);
                      } else {
                        _selectedMemberIds.remove(memberId);
                      }
                    }),
                  ),
                  if (selected.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SelectedBuddiesNote(selected: selected),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BuddyPicker extends StatelessWidget {
  const _BuddyPicker({
    required this.candidates,
    required this.selectedMemberIds,
    required this.onToggle,
  });

  final List<SsiBuddyCode> candidates;
  final Set<String> selectedMemberIds;
  final void Function(String memberId, bool isSelected) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (candidates.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Niemand mit SSI-Nummer hinterlegt.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Buddies mit eigenem Garmin-Account bekommen ihre SSI-Nummer '
              'auf dem Account-Bildschirm; alle anderen lassen sich als '
              'SSI-Buddy anlegen.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('SSI-Buddy anlegen'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SsiBuddiesScreen()),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final buddy in candidates)
                FilterChip(
                  label: Text(buddy.displayName),
                  selected: selectedMemberIds.contains(buddy.memberId),
                  onSelected: (isSelected) =>
                      onToggle(buddy.memberId, isSelected),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Being straight about this: the selection does not reach the QR
          // code yet. SSI's own exports never carried a buddy, so the field
          // name is unknown - and a made-up one would be silently dropped
          // while looking like it worked.
          Text(
            'Hinweis: Buddies stehen noch nicht im QR-Code – wie SSI sie im '
            'Import benennt, ist noch nicht bekannt. Bis dahin dient die '
            'Auswahl als Merkzettel für den Eintrag in der SSI-App.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The ticked buddies, spelled out with their member numbers so they can be
/// added in the SSI app right after the import without looking them up.
class _SelectedBuddiesNote extends StatelessWidget {
  const _SelectedBuddiesNote({required this.selected});

  final List<SsiBuddyCode> selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('In der SSI-App eintragen', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final buddy in selected)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                [
                  buddy.displayName,
                  buddy.memberIdLine,
                ].whereType<String>().join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
