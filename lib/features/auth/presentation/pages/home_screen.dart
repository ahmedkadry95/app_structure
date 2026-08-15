import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
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
    // فتحنا التطبيق وفيه توكن محفوظ بس مفيش بيانات جلسة في الذاكرة —
    // نتأكد إن التوكن لسه صالح. لو مات، الـ interceptor بيمسحه
    // والـ router بيرجّعنا للوجين تلقائي.
    final cubit = context.read<AuthCubit>();
    if (cubit.state is AuthInitial) {
      cubit.loadSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'خروج',
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => switch (state) {
          AuthSuccess(:final session) => _SessionDetails(session: session),
          AuthError(:final failure) => _CenteredMessage(
            icon: Icons.error_outline,
            message: failure.message,
            onRetry: () => context.read<AuthCubit>().loadSession(),
          ),
          _ => const Center(child: CircularProgressIndicator()),
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
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
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
                    children: [
                      Text(
                        session.employeeName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        session.username,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _InfoTile(label: 'الشركة', value: session.subsidiaryName),
        _InfoTile(label: 'الفرع', value: session.storeName),
        _InfoTile(label: 'العملة', value: session.currency),
        _InfoTile(label: 'رقم الجلسة', value: session.sid),
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
  final IconData icon;
  final String message;
  final VoidCallback onRetry;
  const _CenteredMessage({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: AppTheme.spacingMd),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacingLg),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('حاول تاني'),
          ),
        ],
      ),
    ),
  );
}
