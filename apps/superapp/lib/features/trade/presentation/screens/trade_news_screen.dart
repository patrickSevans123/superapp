import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/models.dart';
import '../providers/trade_providers.dart';
import '../widgets/news_card.dart';
import '../widgets/news_freshness_banner.dart';

/// News screen for the trade feature.
///
/// TabController for Bloomberg EN / Bloomberg Technoz tabs. Each tab caches
/// its own `NewsResult` so swapping tabs is instant and re-selecting a tab
/// shows the cached list (pull-to-refresh re-fetches).
class TradeNewsScreen extends ConsumerStatefulWidget {
  const TradeNewsScreen({super.key});

  @override
  ConsumerState<TradeNewsScreen> createState() => _TradeNewsScreenState();
}

class _TradeNewsScreenState extends ConsumerState<TradeNewsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final Map<String, NewsResult> _bySource = {};
  final Map<String, bool> _loading = {};
  final Map<String, String?> _errors = {};

  // Source tabs in display order
  static const _tabs = <_SourceTab>[
    _SourceTab(key: 'bloomberg_english', label: 'Bloomberg EN'),
    _SourceTab(key: 'bloomberg_technoz', label: 'Bloomberg Technoz'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    // Pre-load first tab eagerly
    _load(_tabs.first.key);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load(String source) async {
    setState(() {
      _loading[source] = true;
      _errors[source] = null;
    });
    try {
      final repo = ref.read(tradeRepositoryProvider);
      final result = await repo.getNews(source: source, limit: 30);
      if (!mounted) return;
      setState(() {
        _bySource[source] = result;
        _loading[source] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errors[source] = e.toString();
        _loading[source] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Market News',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.trade),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Stale-data banner sits above tabs so it's always visible.
        const NewsFreshnessBanner(),
        TabBar(
          controller: _tab,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.hint,
          indicatorColor: AppColors.accent,
          onTap: (i) {
            // Kick off a background load if we don't have data yet
            if (!_bySource.containsKey(_tabs[i].key) &&
                _loading[_tabs[i].key] != true) {
              _load(_tabs[i].key);
            }
          },
          tabs: [for (final t in _tabs) Tab(text: t.label)],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [for (final t in _tabs) _buildTab(t.key)],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String source) {
    final loading = _loading[source] == true;
    final err = _errors[source];
    final result = _bySource[source];

    if (loading && result == null) {
      return const _NewsShimmerList();
    }
    if (err != null && result == null) {
      return _ErrorView(
        message: err,
        onRetry: () => _load(source),
      );
    }
    if (result == null || result.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(source),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'No news',
                style: TextStyle(color: AppColors.hint),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(source),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: result.items.length,
        itemBuilder: (_, i) => NewsCard(item: result.items[i]),
      ),
    );
  }
}

class _SourceTab {
  final String key;
  final String label;
  const _SourceTab({required this.key, required this.label});
}

class _NewsShimmerList extends StatelessWidget {
  const _NewsShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: 6,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ShimmerPlaceholder(
          height: 84,
          borderRadius: 12,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Could not load news',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: 'Retry',
              onPressed: onRetry,
              icon: Icons.refresh,
              small: true,
            ),
          ],
        ),
      ),
    );
  }
}
