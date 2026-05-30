import 'package:shared_models/shared_models.dart';

/// Holds the state for the profile feature.
class ProfileState {
  final UserModel? user;
  final bool loading;
  final String? error;

  const ProfileState({
    this.user,
    this.loading = false,
    this.error,
  });

  ProfileState copyWith({
    UserModel? user,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return ProfileState(
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
