import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../locale/locale_cubit.dart';

/// زرار تبديل اللغة — شغّال من أي شاشة.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) => TextButton.icon(
        onPressed: () => context.read<LocaleCubit>().toggle(),
        icon: const Icon(Icons.language, size: 20),
        // بنعرض اللغة اللي هيروحلها، مش اللي هو فيها
        label: Text(locale.languageCode == 'ar' ? 'English' : 'العربية'),
      ),
    );
  }
}
