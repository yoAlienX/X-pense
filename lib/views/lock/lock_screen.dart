import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../viewmodels/app_lock_viewmodel.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({Key? key}) : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passcodeController = TextEditingController();
  final _answerOneController = TextEditingController();
  final _answerTwoController = TextEditingController();
  final _newPasscodeController = TextEditingController();
  final _confirmPasscodeController = TextEditingController();

  String? _error;
  bool _unlockingBiometric = false;

  @override
  void dispose() {
    _passcodeController.dispose();
    _answerOneController.dispose();
    _answerTwoController.dispose();
    _newPasscodeController.dispose();
    _confirmPasscodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppLockViewModel>();
    final viewInsets = MediaQuery.of(context).viewInsets;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + viewInsets.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock,
                      size: 50,
                      color: AppConstants.primaryPurple,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'App Locked',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 80),
                    Text(
                      'Enter your passcode',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        height: 60,
                        child: TextField(
                          controller: _passcodeController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 12,
                          decoration: const InputDecoration(
                            labelText: 'Passcode',
                            counterText: '',
                          ),
                          onSubmitted: (_) => _unlock(vm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _unlock(vm),
                          child: const Text('Unlock'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: AppConstants.expenseRed),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _showResetDialog(context, vm),
                      child: const Text(
                        'Forgot passcode? Reset with security answers',
                      ),
                    ),
                    if (vm.passcodeEnabled && vm.biometricEnabled) ...[
                      const SizedBox(height: 28),
                      Builder(
                        builder: (context) {
                          final biometricsUsable =
                              vm.biometricAvailable && !_unlockingBiometric;

                          return GestureDetector(
                            onTap: !biometricsUsable
                                ? null
                                : () async {
                                    setState(() {
                                      _unlockingBiometric = true;
                                      _error = null;
                                    });
                                    final ok = await vm.unlockWithBiometric();
                                    if (!ok && mounted) {
                                      setState(
                                        () => _error =
                                            vm.lastBiometricError.isEmpty
                                            ? 'Biometric authentication failed'
                                            : vm.lastBiometricError,
                                      );
                                    }
                                    if (mounted) {
                                      setState(
                                        () => _unlockingBiometric = false,
                                      );
                                    }
                                  },
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              opacity: biometricsUsable ? 1.0 : 0.35,
                              child: Column(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface
                                          .withAlpha(
                                            AppConstants.glassFillAlpha,
                                          ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withAlpha(
                                          AppConstants.glassBorderAlpha,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.fingerprint,
                                      size: 44,
                                      color: biometricsUsable
                                          ? null
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withAlpha(120),
                                    ),
                                  ),
                                  if (_unlockingBiometric) ...[
                                    const SizedBox(height: 8),
                                    const Text('Authenticating...'),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _unlock(AppLockViewModel vm) {
    final ok = vm.unlockWithPasscode(_passcodeController.text.trim());
    if (!ok) {
      setState(() => _error = 'Incorrect passcode');
      return;
    }

    setState(() => _error = null);
    _passcodeController.clear();
  }

  Future<void> _showResetDialog(
    BuildContext context,
    AppLockViewModel vm,
  ) async {
    _answerOneController.clear();
    _answerTwoController.clear();
    _newPasscodeController.clear();
    _confirmPasscodeController.clear();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String? localError;
        InputDecoration glassInputDecoration({
          required String label,
          String? hint,
        }) {
          return InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: Theme.of(
              ctx,
            ).colorScheme.surface.withAlpha(AppConstants.glassFillAlpha),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppConstants.primaryPurple.withAlpha(
                  AppConstants.glassFocusAlpha,
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface.withAlpha(
                        AppConstants.glassPanelAlpha,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withAlpha(
                          AppConstants.glassBorderAlpha,
                        ),
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryPurple.withAlpha(
                                    30,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.lock_reset, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Reset Passcode',
                                style: Theme.of(ctx).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            vm.questionOne.isEmpty
                                ? 'Security question 1'
                                : vm.questionOne,
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _answerOneController,
                            decoration: glassInputDecoration(
                              label: 'Answer 1',
                              hint: 'Enter answer',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            vm.questionTwo.isEmpty
                                ? 'Security question 2'
                                : vm.questionTwo,
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _answerTwoController,
                            decoration: glassInputDecoration(
                              label: 'Answer 2',
                              hint: 'Enter answer',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newPasscodeController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: glassInputDecoration(
                              label: 'New passcode',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _confirmPasscodeController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: glassInputDecoration(
                              label: 'Confirm passcode',
                            ),
                          ),
                          if (localError != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              localError!,
                              style: const TextStyle(
                                color: AppConstants.expenseRed,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    FocusScope.of(ctx).unfocus();
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final pass = _newPasscodeController.text
                                        .trim();
                                    final confirm = _confirmPasscodeController
                                        .text
                                        .trim();
                                    if (pass.length < 4) {
                                      setLocalState(
                                        () => localError =
                                            'Passcode must be at least 4 digits',
                                      );
                                      return;
                                    }
                                    if (pass != confirm) {
                                      setLocalState(
                                        () => localError =
                                            'Passcode confirmation does not match',
                                      );
                                      return;
                                    }

                                    final ok = await vm
                                        .resetPasscodeWithSecurityAnswers(
                                          answerOne: _answerOneController.text,
                                          answerTwo: _answerTwoController.text,
                                          newPasscode: pass,
                                        );

                                    if (!ok) {
                                      setLocalState(
                                        () => localError =
                                            'Security answers are incorrect',
                                      );
                                      return;
                                    }

                                    if (ctx.mounted) {
                                      FocusScope.of(ctx).unfocus();
                                      Navigator.pop(ctx);
                                    }
                                  },
                                  child: const Text('Reset'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
