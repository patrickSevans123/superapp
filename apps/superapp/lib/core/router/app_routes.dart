/// Centralised list of route paths used by the app.
///
/// **Why this exists:** the app had 40+ `context.go('/hardcoded/path')` calls
/// scattered across screens, which is brittle (typos only fail at runtime)
/// and makes renames painful. With this class every URL is declared once
/// and screens can build paths through it.
///
/// All public members are `static const` so they can be inlined at the
/// call site and remain zero-cost.
class AppRoutes {
  AppRoutes._();

  // ── Tab shell roots (must match app_router.dart paths) ──────────────
  static const String scholarship = '/scholarship';
  static const String fashion = '/fashion';
  static const String trade = '/trade';
  static const String profile = '/profile';

  // ── Trade sub-routes ────────────────────────────────────────────────
  static const String tradePlans = '$trade/plans';
  static const String tradeNews = '$trade/news';
  static const String tradePlanDetail = '$trade/plan/:id';
  static String tradePlanDetailFor(String id) => '$trade/plan/$id';

  // ── Scholarship sub-routes ─────────────────────────────────────────
  static const String scholarshipSaved = '$scholarship/saved';
  static const String scholarshipStats = '$scholarship/stats';
  static const String scholarshipDetail = '$scholarship/:id';
  static String scholarshipDetailFor(String id) => '$scholarship/$id';

  /// Builds a scholarship browse URL pre-filtered by deadline window.
  ///
  /// Used by the stats dashboard to deep-link into the browse screen
  /// with a `deadline_days` query param the screen reads via
  /// `GoRouterState.uri.queryParameters`.
  static String scholarshipDeadlineDays(int days) =>
      '$scholarship?deadline_days=$days';

  // ── Profile sub-routes ─────────────────────────────────────────────
  static const String profileEdit = '$profile/edit';
  static const String profileSettings = '$profile/settings';
  static const String profileNotifications =
      '$profile/settings/notifications';

  // ── LPDP (mounted outside the tab shell) ───────────────────────────
  static const String lpdp = '/lpdp';
  static const String lpdpUniversities = '$lpdp/universities';
  static const String lpdpUniversity = '$lpdp/university/:name';
  static String lpdpUniversityFor(String name) =>
      '$lpdp/university/${Uri.encodeComponent(name)}';
  static const String lpdpBidang = '$lpdp/bidang/:bidang';
  static String lpdpBidangFor(String bidang) =>
      '$lpdp/bidang/${Uri.encodeComponent(bidang)}';

  // ── Fashion (mounted outside the tab shell) ────────────────────────
  static const String fashionAdd = '$fashion/add';
  static const String fashionInsights = '$fashion/insights';
  static const String fashionDetail = '$fashion/:id';
  static String fashionDetailFor(String id) => '$fashion/$id';

  // ── Auth (lives in authRouter) ─────────────────────────────────────
  static const String login = '/login';
  static const String register = '/register';
}
