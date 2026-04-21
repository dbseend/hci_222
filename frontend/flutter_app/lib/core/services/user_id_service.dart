// user_id_service.dart
// Purpose: Generates and persists an anonymous UUID for the current device/user.
//          The ID is passed to submitPrice() so crowdsourced price submissions can be
//          de-duplicated server-side without requiring user authentication.
// Storage: SharedPreferences (key: 'anonymous_user_id')
// TODO(next-dev): Replace with a proper auth token once user accounts are introduced.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UserIdService {
  static const _key = 'anonymous_user_id';

  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_key, id);
    return id;
  }
}
