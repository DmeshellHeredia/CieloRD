import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../ui_kit/ui_kit.dart';
import '../application/app_lock_controller.dart';
import '../domain/local_auth_service.dart';
import 'auth_messages.dart';

/// Cubre la app mientras está bloqueada. No muestra ningún dato del diario.
class LockScreen extends StatelessWidget {
  const LockScreen({super.key, required this.controller});

  final AppLockController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final CieloColors c = CieloColors.of(context);
        final TextTheme text = Theme.of(context).textTheme;
        final AuthOutcome? outcome = controller.lastOutcome;
        final bool missing = controller.credentialsMissing;
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(CieloSpace.xl),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - CieloSpace.xl * 2,
                        minWidth: double.infinity,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const CieloBrandMark(size: 88),
                          const SizedBox(height: CieloSpace.xl),
                          Semantics(
                            header: true,
                            child: Text(
                              CieloStrings.lockTitle,
                              textAlign: TextAlign.center,
                              style: text.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: CieloSpace.sm),
                          Text(
                            missing
                                ? CieloStrings.lockCredentialsMissing
                                : CieloStrings.lockMessage,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: CieloSpace.xl),
                          if (!missing &&
                              outcome != null &&
                              outcome != AuthOutcome.success) ...<Widget>[
                            CieloBanner(
                              tone: CieloTone.warning,
                              message: AuthMessages.of(outcome),
                            ),
                            const SizedBox(height: CieloSpace.xl),
                          ],
                          FilledButton.icon(
                            onPressed: controller.isAuthenticating
                                ? null
                                : missing
                                ? controller.openWithoutCredentials
                                : controller.unlock,
                            icon: Icon(
                              missing
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded,
                            ),
                            label: Text(
                              controller.isAuthenticating
                                  ? CieloStrings.lockUnlocking
                                  : missing
                                  ? CieloStrings.lockOpenWithout
                                  : CieloStrings.lockUnlock,
                            ),
                          ),
                          if (missing) ...<Widget>[
                            const SizedBox(height: CieloSpace.sm),
                            TextButton(
                              onPressed: controller.unlock,
                              child: const Text(CieloStrings.retry),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
            ),
          ),
        );
      },
    );
  }
}
