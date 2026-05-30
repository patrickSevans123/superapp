import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/models.dart';
import '../providers/trade_providers.dart';
import '../widgets/news_card.dart';

/// News screen for the trade feature.
///
/// TabController for Bloomberg EN / Bloomberg Technoz tabs.
/// Supports pull-to-refresh and tap to open URLs.
class TradeNewsScreen extends ConsumerStatefulWidget {
  const TradeNewsScreen({super.key});

  @override
  ConsumerState<TradeNewsScreen> createState() => _TradeNewsScreenState();
}

class _TradeNewsScreenState extends ConsumerState<TradeNewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _isLoading = true;
  String? _error;
  List<NewsItem> _news = [];
  String _currentSource = 'bloomberg_english';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadNews();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadNews({String? source}) async {
    final src = source ?? _currentSource;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(tradeRepositoryProvider);
      final news = await repo.getNews(source: src, limit: 20);
      setState(() {
        _news = news;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
                _error!,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GlassButton(
                label: 'Retry',
                onPressed: () => _loadNews(),
                icon: Icons.refresh,
                small: true,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tab,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.hint,
          indicatorColor: AppColors.accent,
          onTap: (i) {
            final source =
                i == 0 ? 'bloomberg_english' : 'bloomberg_technoz';
            setState(() => _currentSource = source);
            _loadNews(source: source);
          },
          tabs: const [
            Tab(text: 'Bloomberg EN'),
            Tab(text: 'Bloomberg Technoz'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildNewsList(),
              _buildNewsList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewsList() {
    if (_news.isEmpty) {
      return const Center(
        child: Text(
          'No news',
          style: TextStyle(color: AppColors.hint),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadNews(source: _currentSource),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _news.length,
        itemBuilder: (_, i) => NewsCard(item: _news[i]),
      ),
    );
  }
}
