import 'package:flutter/material.dart';

import '../models/dive.dart';
import '../ssi/ssi_buddy_code.dart';
import '../ssi/ssi_qr_payload_builder.dart';
import 'format.dart';
import 'qr_display_screen.dart';
import 'theme/app_theme.dart';

/// Several dives as QR codes in a row, one screen each.
///
/// A dive day is two or three dives, and exporting them one at a time means
/// walking back out of the code and into the next dive every time. Here the
/// phone with the SSI app can stay where it is: scan, tap "Weiter", scan.
///
/// Every dive handed in must be exportable - the selection screen is what
/// decides that, so this screen never has to show an error in place of a
/// code and the counter can't skip a number.
class DiveQrBatchScreen extends StatefulWidget {
  const DiveQrBatchScreen({super.key, required this.dives, this.diver});

  final List<Dive> dives;

  /// SSI member the dives belong to; see [SsiQrPayloadBuilder.build].
  final SsiBuddyCode? diver;

  @override
  State<DiveQrBatchScreen> createState() => _DiveQrBatchScreenState();
}

/// The app's filled buttons are full-width by default (`Size.fromHeight`,
/// i.e. an infinite minimum width). That is right in a column and
/// impossible in a row, where a child is offered unbounded width - so the
/// buttons beside the counter size to their label instead.
final _inRow = FilledButton.styleFrom(minimumSize: const Size(0, 48));

class _DiveQrBatchScreenState extends State<DiveQrBatchScreen> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) => _pages.animateToPage(
    index,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final total = widget.dives.length;
    final isLast = _index == total - 1;

    return Theme(
      data: AppTheme.light(),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: const Text('Mit SSI-App scannen'),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: total,
                      onPageChanged: (index) => setState(() => _index = index),
                      itemBuilder: (context, index) {
                        final dive = widget.dives[index];
                        return QrScanSurface(
                          payload: SsiQrPayloadBuilder.build(
                            dive,
                            diver: widget.diver,
                          ),
                          caption:
                              '${Fmt.weekday(dive.dateTime)}, '
                              '${Fmt.date(dive.dateTime)} · '
                              '${dive.diveNumberOfDay}. TG · '
                              '${Fmt.meters(dive.maxDepthMeters)} m · '
                              '${Fmt.minutes(dive.duration)} min',
                          hint:
                              'In der SSI-App einen Tauchgang hinzufügen und '
                              '„QR-Code scannen" wählen, danach hier weiter.',
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _index == 0
                              ? null
                              : () => _goTo(_index - 1),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Zurück'),
                        ),
                        Expanded(
                          child: Text(
                            '${_index + 1} von $total',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        // The last page ends the run rather than dead-ending
                        // on a disabled button.
                        isLast
                            ? FilledButton(
                                style: _inRow,
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Fertig'),
                              )
                            : FilledButton.icon(
                                style: _inRow,
                                onPressed: () => _goTo(_index + 1),
                                icon: const Icon(Icons.chevron_right),
                                label: const Text('Weiter'),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
