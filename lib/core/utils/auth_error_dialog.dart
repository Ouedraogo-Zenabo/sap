import 'package:flutter/material.dart';
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';

Future<void> showAuthExpiredDialog(BuildContext context, {String? message}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Session expirée'),
      content: Text(message ?? 'Votre session a expiré ou vous n\'êtes pas authentifié. Voulez-vous vous reconnecter ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Se reconnecter'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await UserLocalService().clearUser();
    } catch (_) {}
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }
}
