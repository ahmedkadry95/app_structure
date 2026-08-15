import 'package:flutter/material.dart';

import '../di/injection.dart';
import '../network/network_info.dart';

/// شريط بيظهر فوق أي شاشة لما الشبكة تقع.
///
/// مكمّل للـ ConnectivityInterceptor: هو بيمنع الريكوست، وده بيقول
/// للمستخدم ليه مفيش حاجة بتتحمّل.
class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: sl<NetworkInfo>().onStatusChange,
      builder: (context, snapshot) {
        final isOffline = snapshot.data == false;
        final theme = Theme.of(context);

        return Column(
          children: [
            Expanded(child: child),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isOffline
                  ? Material(
                      color: theme.colorScheme.errorContainer,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_off,
                                size: 18,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'مفيش اتصال بالإنترنت',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}
