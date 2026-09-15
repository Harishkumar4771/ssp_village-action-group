import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../core/database/local_db.dart';
import '../../core/auth/user_role.dart';

part 'cached_user_model.g.dart';

@collection
class CachedUserModel {
  Id isarId = 1;
  late String userId;
  late String username;
  late String fullName;
  late String initials;
  late String roleStr;
  String? villageId;
  String? villageName;
  String? district;
  String? state;
  DateTime? lastAuthenticated;
  bool? isActive;
}

class CachedUserStore {
  CachedUserStore._();
  static final CachedUserStore instance = CachedUserStore._();

  Isar get _db {
    return LocalDb.instance!;
  }

  Future<void> save(AppUser user) async {
    if (!LocalDb.isAvailable) return;
    final model = CachedUserModel()
      ..isarId = 1
      ..userId = user.id
      ..username = user.username
      ..fullName = user.name
      ..initials = user.initials
      ..roleStr = user.role == UserRole.admin ? 'admin' : 'leader'
      ..villageId = user.villageId
      ..villageName = user.villageName
      ..district = user.district
      ..state = user.state
      ..lastAuthenticated = DateTime.now()
      ..isActive = user.active;

    await _db.writeTxn(() async {
      await _db.cachedUserModels.put(model);
    });
  }

  Future<AppUser?> load() async {
    if (!LocalDb.isAvailable) return null;
    final model = await _db.cachedUserModels.get(1);
    if (model == null) return null;
    
    // Check 30-day expiration (default to valid if missing during migration)
    final lastAuth = model.lastAuthenticated ?? DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(lastAuth);
    if (difference.inDays > 30) {
      debugPrint('[Auth] Cached user expired (last authenticated ${difference.inDays} days ago).');
      return null;
    }

    // Default to active if missing
    if (!(model.isActive ?? true)) {
      debugPrint('[Auth] Cached user is inactive.');
      return null;
    }

    final role = model.roleStr == 'admin' ? UserRole.admin : UserRole.leader;
    return AppUser(
      id: model.userId,
      username: model.username,
      name: model.fullName,
      initials: model.initials,
      role: role,
      villageId: model.villageId,
      villageName: model.villageName,
      district: model.district,
      state: model.state,
      active: model.isActive ?? true,
    );
  }

  Future<void> clear() async {
    if (!LocalDb.isAvailable) return;
    await _db.writeTxn(() async {
      await _db.cachedUserModels.clear();
    });
  }
}
