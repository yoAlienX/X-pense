import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../viewmodels/app_lock_viewmodel.dart';

Future<bool> showLockOverlayDialog(BuildContext context) async {
  final vm = context.read<AppLockViewModel>();
  if (!vm.passcodeEnabled) return true;

  final success = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final passcodeController = TextEditingController();
      String? error;

      return StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface.withAlpha(AppConstants.glassPanelAlpha),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 40, color: AppConstants.primaryPurple),
                      const SizedBox(height: 16),
                      Text(
                        'Authenticate',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your passcode to view balances',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: passcodeController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Passcode',
                          errorText: error,
                        ),
                        onSubmitted: (value) async {
                          if (await vm.unlockWithPasscode(value.trim())) {
                            Navigator.pop(ctx, true);
                          } else {
                            setState(() => error = 'Incorrect passcode');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (await vm.unlockWithPasscode(passcodeController.text.trim())) {
                                Navigator.pop(ctx, true);
                              } else {
                                setState(() => error = 'Incorrect passcode');
                              }
                            },
                            child: const Text('Unlock'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  return success ?? false;
}
