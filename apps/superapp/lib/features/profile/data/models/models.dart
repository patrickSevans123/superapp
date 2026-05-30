// Profile feature doesn't define its own models — it re-exports
// UserModel from shared_models through the repository layer.
// This barrel file exists for consistency with the feature scaffold.
export 'package:shared_models/shared_models.dart';
