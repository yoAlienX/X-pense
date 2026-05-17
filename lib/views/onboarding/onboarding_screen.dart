import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../viewmodels/app_lock_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../../services/storage_service.dart';
import '../../services/crypto_service.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Account Setup Variables
  final TextEditingController _accountNameController = TextEditingController(text: 'Bank Account');
  final TextEditingController _balanceController = TextEditingController();

  // Security Setup Variables
  final TextEditingController _passcodeController = TextEditingController();
  final TextEditingController _cryptoKeyController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _accountNameController.dispose();
    _balanceController.dispose();
    _passcodeController.dispose();
    _cryptoKeyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    // 1. Setup account and initial balance if provided
    final txVm = context.read<TransactionViewModel>();
    final accountName = _accountNameController.text.trim().isEmpty ? 'Cash' : _accountNameController.text.trim();

    // Check if the account isn't already added (should not happen on first launch)
    if (!txVm.accounts.contains(accountName)) {
      await txVm.addAccount(accountName);
    }

    final balanceText = _balanceController.text.trim();
    final initialBalance = double.tryParse(balanceText) ?? 0.0;

    if (initialBalance != 0.0) {
      await txVm.editAccountBalance(accountName, initialBalance);
    }

    // 2. Setup Security if provided
    final lockVm = context.read<AppLockViewModel>();
    final passcode = _passcodeController.text.trim();
    if (passcode.isNotEmpty && passcode.length >= 4) {
      await lockVm.configurePasscode(
        passcode: passcode,
        questionOne: AppLockViewModel.securityQuestionOptions.first,
        answerOne: 'default',
        questionTwo: AppLockViewModel.securityQuestionOptions[1],
        answerTwo: 'default',
      );
    }

    // 3. Setup Encryption Key if provided
    final cryptoKey = _cryptoKeyController.text.trim();
    if (cryptoKey.isNotEmpty) {
      final cryptoService = CryptoService();
      await cryptoService.setSecretKey(cryptoKey);
    }

    // 4. Save flag
    await StorageService().saveOnboardingComplete();

    // 4. Navigate to Home Screen using blur-in transition
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: FadeTransition(
                opacity: animation,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 10 * (1 - animation.value),
                    sigmaY: 10 * (1 - animation.value),
                  ),
                  child: child,
                ),
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [const Color(0xFF0D0E0F), const Color(0xFF1C1C23)]
                    : [const Color(0xFFF1F1FA), Colors.white],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed: _previousPage,
                        )
                      else
                        const SizedBox(width: 48), // Placeholder to balance

                      Row(
                        children: List.generate(4, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppConstants.primaryPurple
                                  : Colors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      TextButton(
                        onPressed: _finishOnboarding,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),

                // Page Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(), // Only manual nav
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    children: [
                      _buildWelcomeAndThemeStep(),
                      _buildAccountSetupStep(),
                      _buildSecuritySetupStep(),
                      _buildFeaturesShowcaseStep(),
                    ],
                  ),
                ),

                // Bottom Navigation Button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _nextPage,
                    child: Text(
                      _currentPage == 3 ? "Let's Get Started" : "Continue",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withAlpha(isDark ? 100 : 180),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withAlpha(isDark ? 30 : 100),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildWelcomeAndThemeStep() {
    final themeVm = context.watch<ThemeViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppConstants.primaryPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet, size: 80, color: AppConstants.primaryPurple),
          ),
          const SizedBox(height: 40),
          const Text(
            'Welcome to X-pense',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Track your spending, manage accounts, and analyze your financial habits securely.',
            style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodySmall?.color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _buildGlassContainer(
            child: Column(
              children: [
                const Text('Choose your style', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ThemeOption(
                      icon: Icons.light_mode,
                      label: 'Light',
                      isSelected: !themeVm.isDarkMode,
                      onTap: () {
                        if (themeVm.isDarkMode) themeVm.toggleTheme();
                      },
                    ),
                    _ThemeOption(
                      icon: Icons.dark_mode,
                      label: 'Dark',
                      isSelected: themeVm.isDarkMode,
                      onTap: () {
                        if (!themeVm.isDarkMode) themeVm.toggleTheme();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Encryption Key (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _cryptoKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'e.g., from BitWarden',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                  const Text(
                    'Provide a private key to encrypt all your transactions locally and during CSV exports.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSetupStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.account_balance, size: 64, color: AppConstants.incomeGreen),
          const SizedBox(height: 24),
          const Text(
            'Set Up Your Account',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Start by adding your primary account and its current balance.',
            style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodySmall?.color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Name', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _accountNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Canara Bank, Cash',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Initial Balance', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: '0.00',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySetupStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.lock_outline, size: 64, color: AppConstants.primaryPurple),
          const SizedBox(height: 24),
          const Text(
            'Secure Your Data',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Add an optional passcode to protect your balances and transactions.',
            style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodySmall?.color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('App Passcode (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passcodeController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'Enter 4-6 digits',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can configure biometrics and security questions later in Settings.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesShowcaseStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, size: 64, color: Color(0xFFFCAC12)),
          const SizedBox(height: 24),
          const Text(
            'You\'re All Set!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(Icons.pie_chart_outline, 'Interactive Analytics', 'Visualize your spending with Doughnut & Line charts.'),
          const SizedBox(height: 20),
          _buildFeatureRow(Icons.file_download_outlined, 'CSV Import/Export', 'Backup and import your transaction history anytime.'),
          const SizedBox(height: 20),
          _buildFeatureRow(Icons.add_circle_outline, 'Quick Add', 'Use the floating + button to log expenses instantly.'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConstants.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppConstants.primaryPurple),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryPurple.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppConstants.primaryPurple : Colors.grey.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? AppConstants.primaryPurple : Colors.grey),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
