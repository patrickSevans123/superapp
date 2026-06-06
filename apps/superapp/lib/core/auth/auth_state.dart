/// Re-exports the public surface of `core/auth/` so consumers can
/// `import 'package:superapp/core/auth/auth_state.dart';` and get
/// everything they need.
library;

export 'core_auth_notifier.dart'
    show
        CoreAuthApi,
        CoreAuthSession,
        CoreAuthState,
        CoreAuthNotifier,
        coreAuthNotifierProvider,
        authRefreshListenable,
        kAuthTokenKey,
        kHasSecureTokenKey,
        secureStorageProvider;
