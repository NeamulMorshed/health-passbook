import 'package:flutter/material.dart';

// Global navigator key shared by the GoRouter and the NotificationService.
// Kept in its own file to break the circular import that would arise if
// notification_service.dart imported router.dart (which imports auth_provider,
// which imports notification_service).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
