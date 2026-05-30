import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/models.dart';
import '../providers/trade_providers.dart';
import '../widgets/plan_card.dart';

/// Screen listing all trading plans with Active / Closed tabs.
class TradePlansScreen extends ConsumerStatefulWidget {
  const TradePlansScreen({super.key});

  @override
  ConsumerState<TradePlansScreen> createState() => _TradePlansScreenState();
}

class _TradePlansScreenState extends ConsumerState<TradePlansScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _isLoading = true;
  String? _error;
  List<TradingPlan> _activePlans = [];
  List<TradingPlan> _closedPlans = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadPlans();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(tradeRepositoryProvider);
      final active = await repo.getPlans(status: 'ACTIVE');
      final closed = await repo.getPlans(status: 'CLOSED');
      setState(() {
        _activePlans = active;
        _closedPlans = closed;
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
                'Could not load plans',
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
                onPressed: _loadPlans,
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
          tabs: [
            Tab(text: 'Active (${_activePlans.length})'),
            Tab(text: 'Closed (${_closedPlans.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildList(_activePlans),
              _buildList(_closedPlans),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<TradingPlan> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No plans',
          style: TextStyle(color: AppColors.hint),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPlans,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        itemBuilder: (_, i) => PlanCard(plan: list[i]),
      ),
    );
  }
}
