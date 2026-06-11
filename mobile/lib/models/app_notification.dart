/// Client-side models for the notification bell and admin verification screens.
///
/// These mirror the backend GraphQL types in `main/graphql/notifications.py`.
/// Bodies arrive already-aggregated and already-localized from the server (e.g.
/// "Ali added 3 people: …"), so the UI just renders [AppNotification.body].
library;

/// What a notification is about. Drives the icon shown in the list and where a
/// tap navigates. Unknown future kinds degrade to [AppNotificationKind.unknown].
enum AppNotificationKind {
  pendingAddition,
  changeVerified,
  nodeChanged,
  broadcast,
  unknown;

  static AppNotificationKind parse(String? raw) {
    switch (raw) {
      case 'pending_addition':
        return AppNotificationKind.pendingAddition;
      case 'change_verified':
        return AppNotificationKind.changeVerified;
      case 'node_changed':
        return AppNotificationKind.nodeChanged;
      case 'broadcast':
        return AppNotificationKind.broadcast;
      default:
        return AppNotificationKind.unknown;
    }
  }
}

/// One entry in the notification bell. Aggregated entries carry [count] > 1 and
/// a [body] that already summarises the folded-in events.
class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.count,
    required this.isRead,
    required this.createdAt,
    this.actorName,
    this.personId,
    this.personIds = const [],
    this.personName,
    this.names = const [],
    this.fieldKeys = const [],
  });

  final int id;
  final AppNotificationKind kind;

  /// Server-stored title/body. Used as a fallback (and for admin broadcasts);
  /// for the system kinds the UI renders localized text from the fields below.
  final String title;
  final String body;
  final int count;
  final bool isRead;
  final DateTime createdAt;
  final String? actorName;

  /// Primary person to navigate to on tap, if any.
  final int? personId;

  /// All related person ids (for aggregated entries).
  final List<int> personIds;

  /// Display name of the primary related person (for node_changed).
  final String? personName;

  /// Names of the related persons (for aggregated pending/verified entries).
  final List<String> names;

  /// Changed field keys for node_changed: name|designation|history|parent.
  final List<String> fieldKeys;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    List<String> strList(String key) =>
        ((json[key] as List?) ?? const []).map((e) => e as String).toList();
    return AppNotification(
      id: json['id'] as int,
      kind: AppNotificationKind.parse(json['kind'] as String?),
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      count: (json['count'] as int?) ?? 1,
      isRead: (json['isRead'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      actorName: json['actorName'] as String?,
      personId: json['personId'] as int?,
      personIds:
          ((json['personIds'] as List?) ?? const []).map((e) => e as int).toList(),
      personName: json['personName'] as String?,
      names: strList('names'),
      fieldKeys: strList('fieldKeys'),
    );
  }
}

/// A page of notifications plus the live unread count.
class NotificationPage {
  NotificationPage({
    required this.notifications,
    required this.unreadCount,
    required this.total,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final int total;
}

/// A contributor attached to a pending addition (verification screen).
class PendingEditor {
  PendingEditor({
    required this.id,
    required this.name,
    this.email,
    required this.userType,
  });

  final int id;
  final String name;
  final String? email;
  final String userType; // 'Staff' or 'normal'

  bool get isStaff => userType == 'Staff';
}

/// A private (unpublished) person awaiting admin verification.
class PendingAddition {
  PendingAddition({
    required this.id,
    required this.name,
    required this.creationTime,
    required this.lastModified,
    required this.editors,
  });

  final int id;
  final String name;
  final DateTime creationTime;
  final DateTime lastModified;
  final List<PendingEditor> editors;

  /// The non-staff contributors — who the admin actually filters by.
  List<PendingEditor> get contributors =>
      editors.where((e) => !e.isStaff).toList();

  factory PendingAddition.fromJson(Map<String, dynamic> json) {
    final editors = ((json['editors'] as List?) ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .map((e) => PendingEditor(
              id: e['id'] as int,
              name: (e['name'] as String?) ?? '',
              email: e['email'] as String?,
              userType: (e['userType'] as String?) ?? 'normal',
            ))
        .toList();
    return PendingAddition(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      creationTime:
          DateTime.tryParse(json['creationTime'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      lastModified:
          DateTime.tryParse(json['lastModified'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      editors: editors,
    );
  }
}
