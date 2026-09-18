import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';
import 'notification_dropdown.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(notificationServiceProvider.select((s) => s.unreadCount));

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (BuildContext context) {
          return Stack(
            children: [
              // Tap outside to close
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _overlayController.hide,
                  child: Container(color: Colors.transparent),
                ),
              ),
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(10, 0),
                child: NotificationDropdown(
                  onClose: _overlayController.hide,
                ),
              ),
            ],
          );
        },
        child: IconButton(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: _overlayController.toggle,
        ),
      ),
    );
  }
}
