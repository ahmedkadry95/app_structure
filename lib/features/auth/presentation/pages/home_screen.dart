import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/failure_l10n.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/language_button.dart';
import '../../domain/entities/session.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<AuthCubit>();
    if (cubit.state is AuthInitial) {
      cubit.loadSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.homeTitle),
        actions: [
          const LanguageButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: context.l10n.homeLogout,
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => switch (state) {
          AuthSuccess(:final session) => _SessionDetails(session: session),
          AuthError(:final failure) => _CenteredMessage(
            message: failure.localize(context),
            onRetry: () => context.read<AuthCubit>().loadSession(),
          ),
          AuthInitial() ||
          AuthLoading() => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _SessionDetails extends StatelessWidget {
  final Session session;

  const _SessionDetails({required this.session});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        const SizedBox(height: AppTheme.spacingMd),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  child: Text(
                    session.employeeName.isEmpty
                        ? '?'
                        : session.employeeName.characters.first,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(context.l10n.test), Text(session.username)],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _InfoTile(
          label: context.l10n.homeCompany,
          value: session.subsidiaryName,
        ),
        _InfoTile(label: context.l10n.homeBranch, value: session.storeName),
        _InfoTile(label: context.l10n.homeCurrency, value: session.currency),
        _InfoTile(label: context.l10n.homeSessionId, value: session.sid),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Text(
      value.isEmpty ? '—' : value,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}

class _CenteredMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CenteredMessage({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacingLg),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    ),
  );
}
