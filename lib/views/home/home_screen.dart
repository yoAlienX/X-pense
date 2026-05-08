// views/home/home_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../liquid_glass/liquid_glass_navbar.dart';
import '../../services/csv_service.dart';
import '../../utils/constants.dart';
import '../../viewmodels/app_lock_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../../views/analytics/analytics_screen.dart';
import '../../views/home/widgets/balance_card.dart';
import '../../views/home/widgets/filter_bar.dart';
import '../../views/lock/security_settings_screen.dart';
import '../../views/home/widgets/transaction_card.dart';
import '../../views/transaction/add_transaction_screen.dart';
import '../../views/transaction/transaction_detail_screen.dart';
import '../../views/widgets/theme_switcher.dart';
import '../../views/widgets/liquid_glass_snackbar.dart';

// ─── Tab indices ──────────────────────────────────────────────────────────────
const int _kTabTransactions = 0;
const int _kTabAnalytics = 1;
const int _kTabSettings = 2;
const double _kSearchFilterRowHeight = 48;
const double _kFilterOverlayHeightRegular = 160;
const double _kFilterOverlayHeightCompact = 220;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── state ──────────────────────────────────────────────────────────────────
  int _currentTab = _kTabTransactions;
  final List<int> _tabHistory = <int>[];
  bool _isProgrammaticPageChange = false;
  bool _isTabTransitioning = false;
  bool _showFilters = false;
  bool _showCreateButton = true;
  bool _showScrollToTopButton = false;
  bool _isTxScrolled = false;
  late final PageController _pageController;
  ScrollController? _transactionsScrollController;
  final GlobalKey _balanceSectionKey = GlobalKey();

  ScrollController get _txScrollController =>
      _transactionsScrollController ??= ScrollController();

  Timer? _searchDebounceTimer;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _menuIconKey = GlobalKey(); // For theme animation origin

  // ── lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _kTabTransactions);
    _transactionsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transactionsScrollController?.dispose();
    _transactionsScrollController = null;
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(TransactionViewModel vm, String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      vm.setSearchQuery(query);
    });
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final themeVm = context.watch<ThemeViewModel>();
    final selectionMode = context.select<TransactionViewModel, bool>(
      (vm) => vm.selectionState.selectionMode,
    );
    final searchQuery = context.select<TransactionViewModel, String>(
      (vm) => vm.filterState.searchQuery,
    );
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Keep search controller in sync
    if (_searchController.text != searchQuery) {
      _searchController.value = TextEditingValue(
        text: searchQuery,
        selection: TextSelection.collapsed(offset: searchQuery.length),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (selectionMode) {
          context.read<TransactionViewModel>().clearSelection();
          return;
        }

        // If on home screen with no history, show exit confirmation
        if (_currentTab == _kTabTransactions && _tabHistory.isEmpty) {
          _handleExitPress(context);
          return;
        }

        _handleTabBackNavigation();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          // ── AppBar ─────────────────────────────────────────────────────────
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Consumer<TransactionViewModel>(
              builder: (context, vm, _) {
                return _buildAppBar(context, vm, themeVm, selectionMode);
              },
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────────
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                onPageChanged: (index) {
                  if (_currentTab != index) {
                    // Always update _currentTab after page settles.
                    // This prevents navbar animation repetition by ensuring it plays only once.
                    setState(() => _currentTab = index);

                    // Only track history for gesture-based (non-programmatic) changes
                    if (!_isProgrammaticPageChange) {
                      _pushTabHistory(_currentTab);
                    }
                  }
                },
                children: [
                  Consumer<TransactionViewModel>(
                    builder: (context, vm, _) {
                      return _buildTransactionsBody(
                        context,
                        vm,
                        isKeyboardOpen,
                      );
                    },
                  ),
                  const AnalyticsScreen(embedInHome: true),
                  const SecuritySettingsScreen(embedInHome: true),
                ],
              ),
              // ── Floating Bottom Navigation Bar Overlay ──────────────────
              if (!selectionMode && !isKeyboardOpen)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomNavBar(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _pushTabHistory(int tab) {
    if (_tabHistory.isEmpty || _tabHistory.last != tab) {
      _tabHistory.add(tab);
    }
  }

  void _handleTabBackNavigation() {
    if (_tabHistory.isNotEmpty) {
      final previousTab = _tabHistory.removeLast();
      _animateToTab(previousTab, pushToHistory: false);
      return;
    }

    if (_currentTab != _kTabTransactions) {
      _animateToTab(_kTabTransactions, pushToHistory: false);
    }
  }

  Future<void> _animateToTab(int index, {required bool pushToHistory}) async {
    if (_isTabTransitioning || _currentTab == index) {
      return;
    }

    final fromIndex = _currentTab;

    if (pushToHistory) {
      _pushTabHistory(fromIndex);
    }

    _isProgrammaticPageChange = true;
    _isTabTransitioning = true;

    try {
      final isNonAdjacentHop = (fromIndex - index).abs() > 1;
      if (isNonAdjacentHop) {
        _pageController.jumpToPage(index);
        // Keep nav transition state briefly so the bottom bar animation
        // does not feel snappy when page hop itself is instantaneous.
        await Future<void>.delayed(const Duration(milliseconds: 260));
      } else {
        await _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeInOutCubicEmphasized,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProgrammaticPageChange = false;
          _isTabTransitioning = false;
        });
      } else {
        _isProgrammaticPageChange = false;
        _isTabTransitioning = false;
      }
    }
  }

  // ── Bottom Navigation Bar ──────────────────────────────────────────────────

  Widget _buildBottomNavBar(BuildContext context) {
    final showInlineAction =
        !_isTabTransitioning &&
        _currentTab == _kTabTransactions &&
        (_showCreateButton || _showScrollToTopButton);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: LiquidGlassNavBar(
          currentIndex: _currentTab,
          onTap: _onTabTapped,
          actionButton: LiquidGlassActionButton(
            icon: _showScrollToTopButton
                ? Icons.keyboard_double_arrow_up_rounded
                : Icons.add_circle_outline,
            onTap: _showScrollToTopButton
                ? _scrollToTop
                : () => _navigateToNewTransaction(context),
          ),
          showActionButton: showInlineAction,
          reserveActionSlot: false,
          theme: const LiquidGlassTheme(
            blurSigma: 7,
            tintOpacity: 0.18,
            specularity: 0.58,
            height: 60,
            horizontalPadding: 16,
            bottomPadding: 6,
            borderRadius: 36,
            actionButtonRadius: 30,
            animationDuration: Duration(milliseconds: 460),
            animationCurve: Curves.easeInOutCubic,
          ),
          items: const [
            LiquidGlassNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              label: 'History',
            ),
            LiquidGlassNavItem(
              icon: Icons.analytics_outlined,
              activeIcon: Icons.analytics,
              label: 'Analytics',
            ),
            LiquidGlassNavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    _animateToTab(index, pushToHistory: true);
  }

  void _navigateToNewTransaction(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
  }

  void _scrollToTop() {
    if (!_txScrollController.hasClients) return;

    _txScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
    );
  }

  // ── Transactions body ──────────────────────────────────────────────────────

  Widget _buildSearchFilterRow(
    BuildContext context,
    TransactionViewModel vm, {
    required bool glassMode,
    required bool isPinned,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          const compactButtonWidth = 50.0;
          final availableWidth = constraints.maxWidth;

          final searchWidth = _showFilters
              ? compactButtonWidth
              : availableWidth - compactButtonWidth - gap;
          final filterWidth = _showFilters
              ? availableWidth - compactButtonWidth - gap
              : compactButtonWidth;

          final glassFill = Theme.of(
            context,
          ).colorScheme.surface.withAlpha(AppConstants.glassContainerAlpha);
          final borderColor = Colors.white.withAlpha(
            AppConstants.glassBorderAlpha,
          );

          BoxDecoration _buttonDecoration({required bool expandedShadow}) {
            return BoxDecoration(
              color: glassMode ? glassFill : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: glassMode
                  ? Border.all(color: borderColor, width: 0.8)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(expandedShadow ? 24 : 16),
                  blurRadius: expandedShadow ? 14 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            );
          }

          Widget wrapWithGlass(Widget child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: child,
              ),
            );
          }

          return Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                width: searchWidth,
                height: _kSearchFilterRowHeight,
                decoration: _buttonDecoration(expandedShadow: false),
                child: wrapWithGlass(
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _showFilters
                          ? Center(
                              key: const ValueKey('search-icon-button'),
                              child: IconButton(
                                tooltip: 'Show search',
                                icon: const Icon(Icons.search),
                                color: AppConstants.primaryPurple,
                                onPressed: () {
                                  setState(() => _showFilters = false);
                                  Future<void>.delayed(
                                    const Duration(milliseconds: 60),
                                    () {
                                      if (!mounted) return;
                                      _searchFocusNode.requestFocus();
                                    },
                                  );
                                },
                              ),
                            )
                          : TextField(
                              key: const ValueKey('search-text-field'),
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onTap: () => _searchFocusNode.requestFocus(),
                              onChanged: (value) => _onSearchChanged(vm, value),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                prefixIcon: const Icon(Icons.search),
                                hintText: 'Search transactions',
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () {
                                          _searchController.clear();
                                          vm.setSearchQuery('');
                                          setState(() {});
                                        },
                                      ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: gap),

              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                width: filterWidth,
                height: _kSearchFilterRowHeight,
                decoration: _buttonDecoration(expandedShadow: _showFilters),
                child: wrapWithGlass(
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: LayoutBuilder(
                      builder: (context, buttonConstraints) {
                        final canShowExpanded = _showFilters;

                        return TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: canShowExpanded ? 12 : 0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            setState(() => _showFilters = !_showFilters);
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 800),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: canShowExpanded
                                ? const FittedBox(
                                    key: ValueKey('filter-expanded'),
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.tune_rounded,
                                          size: 18,
                                          color: AppConstants.primaryPurple,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Filters',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppConstants.primaryPurple,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(
                                          Icons.keyboard_arrow_up_rounded,
                                          color: AppConstants.primaryPurple,
                                        ),
                                      ],
                                    ),
                                  )
                                : const Icon(
                                    key: ValueKey('filter-compact'),
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: AppConstants.primaryPurple,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionsBody(
    BuildContext context,
    TransactionViewModel vm,
    bool isKeyboardOpen,
  ) {
    final filteredTransactions = vm.filteredTransactions;
    final compactFilterLayout = MediaQuery.of(context).size.width - 32 < 430;
    final filterOverlayHeight = compactFilterLayout
        ? _kFilterOverlayHeightCompact
        : _kFilterOverlayHeightRegular;
    final rowTopSpacing = _isTxScrolled ? 7.0 : 0.0;
    final rowHeaderHeight = _kSearchFilterRowHeight + rowTopSpacing;

    return RefreshIndicator(
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      edgeOffset: 0,
      displacement: 28,
      onRefresh: () => vm.initialize(),
      color: AppConstants.primaryPurple,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: CustomScrollView(
          controller: _txScrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          cacheExtent: 900,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (!isKeyboardOpen)
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  key: _balanceSectionKey,
                  child: BalanceCard(
                    onSummaryTap: (isIncome) =>
                        _showTypeDialog(context, vm, isIncome),
                  ),
                ),
              ),
            if (!isKeyboardOpen)
              const SliverToBoxAdapter(child: SizedBox(height: 6)),

            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedWidgetHeaderDelegate(
                height: rowHeaderHeight,
                child: Padding(
                  padding: EdgeInsets.only(top: rowTopSpacing),
                  child: _buildSearchFilterRow(
                    context,
                    vm,
                    glassMode: true,
                    isPinned: true,
                  ),
                ),
              ),
            ),

            if (!isKeyboardOpen && _showFilters)
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedWidgetHeaderDelegate(
                  height: filterOverlayHeight,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: FilterBar(overlay: true),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            if (filteredTransactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.42,
                    child: _emptyState(),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final t = filteredTransactions[i];
                      return RepaintBoundary(
                        child: TransactionCard(
                          transaction: t,
                          selected: vm.selectionState.isSelected(t.id),
                          selectionMode: vm.selectionState.selectionMode,
                          onTap: () {
                            if (vm.selectionState.selectionMode) {
                              vm.toggleSelection(t.id);
                            } else {
                              showTransactionDetail(context, t);
                            }
                          },
                          onLongPress: () => vm.toggleSelection(t.id),
                          onAction: (action) {
                            if (action == 'delete') {
                              _confirmDelete(context, vm, {t.id});
                            } else if (action == 'edit') {
                              // Fade out FAB before navigating
                              setState(() => _showCreateButton = false);

                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => AddTransactionScreen(existing: t),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) => FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                  transitionDuration: const Duration(
                                    milliseconds: 260,
                                  ),
                                ),
                              ).then((_) {
                                // Fade in FAB when returning
                                setState(() => _showCreateButton = true);
                              });
                            }
                          },
                        ),
                      );
                    },
                    childCount: filteredTransactions.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(
    BuildContext context,
    TransactionViewModel vm,
    ThemeViewModel themeVm,
    bool selectionMode,
  ) {
    final shouldShowLockIcon = context.select<AppLockViewModel, bool>(
      (vm) => vm.shouldRequireLock,
    );
    final lockVm = context.read<AppLockViewModel>();

    // Selection mode AppBar
    if (selectionMode && _currentTab == _kTabTransactions) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => vm.clearSelection(),
        ),
        title: Text('${vm.selectionState.selectedCount} selected'),
        actions: [
          Checkbox(
            value:
                vm.selectionState.selectedCount ==
                    vm.filteredTransactions.length &&
                vm.filteredTransactions.isNotEmpty,
            onChanged: (checked) {
              if (checked == true) {
                vm.selectAll();
              } else {
                vm.clearSelection();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete selected',
            onPressed: () =>
                _confirmDelete(context, vm, vm.selectionState.selectedIds),
          ),
        ],
      );
    }

    final title = _currentTab == _kTabAnalytics
        ? 'Analytics'
        : _currentTab == _kTabSettings
        ? 'Security'
        : 'X-pense';

    // Normal AppBar — title left, lock + menu right
    return AppBar(
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _scrollToTop,
        child: SizedBox(
          height: kToolbarHeight,
          child: Align(alignment: Alignment.centerLeft, child: Text(title)),
        ),
      ),
      actions: [
        // Lock button
        if (shouldShowLockIcon)
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock App Now',
            onPressed: () {
              vm.forceMaskBalance();
              lockVm.lockApp();
            },
          ),

        // Three-dot menu
        IconButton(
          key: _menuIconKey,
          icon: const Icon(Icons.more_vert),
          tooltip: 'More actions',
          onPressed: () => _showMoreMenu(context, vm, themeVm),
        ),
      ],
    );
  }

  // ── More actions menu ─────────────────────────────────────────────────────

  Future<void> _showMoreMenu(
    BuildContext context,
    TransactionViewModel vm,
    ThemeViewModel themeVm,
  ) async {
    final buttonContext = _menuIconKey.currentContext;
    if (buttonContext == null) return;

    final button = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final buttonRect = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    final menuCenter = button.localToGlobal(button.size.center(Offset.zero));

    final isDark = themeVm.isDarkMode;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(buttonRect, Offset.zero & overlay.size),
      popUpAnimationStyle: const AnimationStyle(
        duration: Duration.zero,
        reverseDuration: Duration.zero,
      ),
      items: [
        // Theme toggle — Day Mode / Night Mode
        PopupMenuItem<String>(
          value: 'theme',
          child: Row(
            children: [
              Icon(
                isDark ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                isDark ? 'Day Mode' : 'Night Mode',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // Import CSV
        PopupMenuItem<String>(
          value: 'import',
          child: const Row(
            children: [
              Icon(Icons.download_outlined, size: 20),
              SizedBox(width: 12),
              Text('Import CSV', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        // Export CSV
        PopupMenuItem<String>(
          value: 'export',
          child: const Row(
            children: [
              Icon(Icons.upload_outlined, size: 20),
              SizedBox(width: 12),
              Text('Export CSV', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );

    if (selected == null || !context.mounted) return;

    switch (selected) {
      case 'theme':
        // Menu is already closed by showMenu, just delay briefly for smooth transition
        await Future.delayed(const Duration(milliseconds: 50));
        if (!context.mounted) return;

        // Trigger animation from menu position
        // Animation reads Controller state (which is always in sync with MaterialApp)
        await ThemeSwitcherWrapper.toggleThemeWithAnimation(
          context,
          menuCenter,
        );

        // Persist the change to storage
        await themeVm.toggleTheme();
        break;

      case 'import':
        await _handleImport(context, vm);
        break;

      case 'export':
        if (context.mounted) {
          await _showExportDialog(context, vm);
        }
        break;
    }
  }

  // ── Handle exit button press ───────────────────────────────────────────────

  void _handleExitPress(BuildContext context) {
    // Fire the async dialog without blocking
    _showExitConfirmationDialog(context);
  }

  // ── Exit confirmation dialog ───────────────────────────────────────────────

  Future<void> _showExitConfirmationDialog(BuildContext context) async {
    final panelColor = Theme.of(
      context,
    ).colorScheme.surface.withAlpha(AppConstants.glassPanelAlpha);
    final borderColor = Colors.white.withAlpha(AppConstants.glassBorderAlpha);

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
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
                  color: panelColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryPurple.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.exit_to_app_outlined,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Exit App',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Are you sure you want to exit the app?'),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.expenseRed,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Exit'),
                          ),
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

    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  // ── Export choice dialog ───────────────────────────────────────────────────

  Future<void> _showExportDialog(
    BuildContext context,
    TransactionViewModel vm,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final panelColor = Theme.of(
          ctx,
        ).colorScheme.surface.withAlpha(AppConstants.glassPanelAlpha);
        final borderColor = Colors.white.withAlpha(
          AppConstants.glassBorderAlpha,
        );
        final exportFilteredColor = isDark
            ? Colors.white
            : Theme.of(ctx).colorScheme.primary;

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
                  color: panelColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryPurple.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.table_chart_outlined,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Export CSV',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Choose which transactions to export:'),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: exportFilteredColor,
                            ),
                            icon: const Icon(
                              Icons.filter_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('Export Filtered'),
                            onPressed: () => Navigator.pop(ctx, 'filtered'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.backup_outlined, size: 18),
                            label: const Text('Export All'),
                            onPressed: () => Navigator.pop(ctx, 'all'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.expenseRed,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (choice == null || !context.mounted) return;
    await _handleExport(context, vm, choice);
  }

  // ── Scroll handler ─────────────────────────────────────────────────────────

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_currentTab != _kTabTransactions || notification.depth != 0) {
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      final threshold = metrics.maxScrollExtent * 0.05;
      final inTopZone = metrics.pixels <= threshold;
      final delta = notification.scrollDelta ?? 0.0;
      final nextOffset = metrics.pixels < 0 ? 0.0 : metrics.pixels;
      final nextIsTxScrolled = nextOffset > 0.5;
      final shouldRetractFilters = _showFilters && delta.abs() > 0.5;

      var nextShowCreateButton = _showCreateButton;
      var nextShowScrollToTopButton = _showScrollToTopButton;

      if (inTopZone) {
        nextShowCreateButton = true;
        nextShowScrollToTopButton = false;
      } else if (delta > 0.5) {
        // On downward scroll, replace add action with jump-to-top action.
        nextShowCreateButton = false;
        nextShowScrollToTopButton = true;
      } else if (delta < -0.5) {
        nextShowCreateButton = true;
        nextShowScrollToTopButton = false;
      }

      if (_isTxScrolled != nextIsTxScrolled ||
          _showCreateButton != nextShowCreateButton ||
          _showScrollToTopButton != nextShowScrollToTopButton ||
          shouldRetractFilters) {
        setState(() {
          _isTxScrolled = nextIsTxScrolled;
          _showCreateButton = nextShowCreateButton;
          _showScrollToTopButton = nextShowScrollToTopButton;
          if (shouldRetractFilters) {
            _showFilters = false;
          }
        });
      }
    }

    if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      final threshold = metrics.maxScrollExtent * 0.05;
      final inTopZone = metrics.pixels <= threshold;
      final nextOffset = metrics.pixels < 0 ? 0.0 : metrics.pixels;
      final nextIsTxScrolled = nextOffset > 0.5;

      if (inTopZone && (!_showCreateButton || _showScrollToTopButton)) {
        setState(() {
          _isTxScrolled = nextIsTxScrolled;
          _showCreateButton = true;
          _showScrollToTopButton = false;
        });
      } else if (_isTxScrolled != nextIsTxScrolled) {
        setState(() => _isTxScrolled = nextIsTxScrolled);
      }
    }

    return false;
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No transactions yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import a CSV or tap + to add one',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Type summary dialog ────────────────────────────────────────────────────

  void _showTypeDialog(
    BuildContext context,
    TransactionViewModel vm,
    bool isIncome,
  ) {
    final txs =
        vm.filteredTransactions
            .where((t) => isIncome ? t.credit > 0 : t.debit > 0)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final totalAmount = txs.fold<double>(
      0.0,
      (sum, t) => sum + (isIncome ? t.credit : t.debit),
    );

    final accent = isIncome
        ? AppConstants.incomeGreen
        : AppConstants.expenseRed;
    final title = isIncome ? 'All Income' : 'All Expenses';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top -
            8,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(120),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent.withAlpha(48), accent.withAlpha(20)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isIncome
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${txs.length} transaction(s)',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: accent,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: txs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'No ${isIncome ? 'income' : 'expense'} transactions in current filter',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: txs.length,
                        itemBuilder: (_, i) {
                          final t = txs[i];
                          final amount = isIncome ? t.credit : t.debit;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              title: Text(
                                t.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${t.formattedDate} • ${t.category}',
                              ),
                              trailing: Text(
                                '₹${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                showTransactionDetail(context, t);
                              },
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Confirm delete dialog ──────────────────────────────────────────────────

  void _confirmDelete(
    BuildContext context,
    TransactionViewModel vm,
    Set<String> ids,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                color: Theme.of(
                  ctx,
                ).colorScheme.surface.withAlpha(AppConstants.glassPanelAlpha),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
                  width: 0.8,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete transactions?',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will permanently delete ${ids.length} transaction(s).',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.expenseRed,
                        ),
                        onPressed: () async {
                          await vm.deleteMultipleTransactions(ids);
                          Navigator.pop(ctx);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              LiquidGlassSnackBar(
                                context: context,
                                message: '${ids.length} transaction(s) deleted',
                                type: SnackBarType.success,
                              ),
                            );
                          }
                        },
                        child: const Text('Delete'),
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
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> _handleImport(
    BuildContext context,
    TransactionViewModel vm,
  ) async {
    try {
      final csvService = CsvService();
      final parsed = await csvService.importFromFile();
      if (parsed == null) return;
      await vm.addMultipleTransactions(parsed);
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          LiquidGlassSnackBar(
            context: context,
            message: 'Imported ${parsed.length} transactions',
            type: SnackBarType.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          LiquidGlassSnackBar(
            context: context,
            message: 'Import failed: $e',
            type: SnackBarType.error,
          ),
        );
      }
    }
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  Future<void> _handleExport(
    BuildContext context,
    TransactionViewModel vm,
    String type,
  ) async {
    final txs = type == 'all'
        ? vm.allTransactions.toList()
        : vm.filteredTransactions.toList();

    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'No transactions to export',
          type: SnackBarType.warning,
        ),
      );
      return;
    }

    try {
      final csvService = CsvService();
      await csvService.exportAndShare(
        txs,
        isBackup: type == 'all',
        subject: type == 'all'
            ? 'Expense Tracker Full Backup'
            : 'Expense Tracker Export',
        text: type == 'all'
            ? 'Complete backup of ${txs.length} transactions.'
            : 'Exported ${txs.length} transactions',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          LiquidGlassSnackBar(
            context: context,
            message: 'Export failed: $e',
            type: SnackBarType.error,
          ),
        );
      }
    }
  }
}

class _PinnedWidgetHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedWidgetHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedWidgetHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
