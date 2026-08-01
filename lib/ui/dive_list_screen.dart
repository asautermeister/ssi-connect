import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/models/account_color.dart';
import '../accounts/models/garmin_account.dart';
import '../dives/dive_loader.dart';
import '../dives/recent_dives_controller.dart';
import '../garmin/garmin_auth_exceptions.dart';
import '../models/dive.dart';
import '../ssi/ssi_buddy_code.dart';
import 'debug_log_screen.dart';
import 'dive_list_tile.dart';
import 'fit_import_flow.dart';
import 'theme/app_theme.dart';
import 'widgets/error_state.dart';
import 'widgets/offline_banner.dart';

/// One account's dives.
///
/// Reads from the same [RecentDivesController] the start screen uses, so
/// both show the same data from the same cache. Opening this screen after
/// the start screen has loaded is therefore instant, and works offline.
class DiveListScreen extends StatefulWidget {
  const DiveListScreen({super.key, required this.account});

  final GarminAccount account;

  @override
  State<DiveListScreen> createState() => _DiveListScreenState();
}

class _DiveListScreenState extends State<DiveListScreen> {
  void _refresh() {
    context.read<RecentDivesController>().load(
      accounts: [widget.account],
      fetch: context.read<DiveFetcher>(),
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final load = context.watch<RecentDivesController>().forAccount(
      widget.account.id,
    );

    // Normally the start screen has already loaded this account. It hasn't
    // if the cache was just cleared, so fetch on arrival. Keyed on
    // fetchedAt rather than on the dive list being empty, so an account
    // that genuinely has no dives doesn't re-fetch forever.
    if (load.fetchedAt == null && !load.isLoading && !load.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'API-Protokoll',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DebugLogScreen())),
          ),
        ],
      ),
      body: _body(load),
    );
  }

  Widget _body(AccountDives load) {
    if (load.dives.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: DiveList(
          dives: load.dives,
          diver: widget.account.ssiIdentity,
          accountColor: widget.account.color,
          // Only worth saying when the dives on screen aren't current.
          header: load.isFromCache
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: OfflineBanner(
                    isOffline: load.isOffline,
                    fetchedAt: load.fetchedAt,
                    onRetry: _refresh,
                  ),
                )
              : null,
        ),
      );
    }

    if (load.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = load.error;
    if (error != null) {
      return ErrorState(
        icon: load.isOffline ? Icons.cloud_off_outlined : Icons.error_outline,
        message: error is GarminAuthException
            ? error.message
            : 'Tauchgänge konnten nicht geladen werden.',
        details: error is GarminAuthException ? error.details : null,
        onRetry: _refresh,
        secondaryLabel: 'Stattdessen FIT-Datei importieren',
        onSecondary: () => pickAndImportFitFile(context),
      );
    }

    return const ErrorState(
      icon: Icons.scuba_diving_outlined,
      message: 'Keine Tauchgänge gefunden.',
    );
  }
}

/// Shared list body, so Garmin-loaded and FIT-imported dives render
/// identically. Computes the shared depth scale the cards' meters use.
class DiveList extends StatelessWidget {
  const DiveList({
    super.key,
    required this.dives,
    this.diver,
    this.accountColor,
    this.header,
  });

  final List<Dive> dives;

  /// SSI member these dives belong to, passed down so the generated QR
  /// code can name them. Null for FIT imports, which carry no account.
  final SsiBuddyCode? diver;

  /// Colour marking whose dives these are. Null for FIT imports.
  final AccountColor? accountColor;

  /// Optional notice above the list, e.g. that these dives came from the
  /// cache. Scrolls with the list rather than sticking, so it doesn't eat
  /// screen height on a long list.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final maxDepth = dives
        .map((d) => d.maxDepthMeters ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final header = this.header;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: dives.length + (header == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (header != null) {
          if (index == 0) return header;
          index -= 1;
        }
        return DiveListTile(
          dive: dives[index],
          maxDepthInList: maxDepth,
          diver: diver,
          accountColor: accountColor,
        );
      },
    );
  }
}
