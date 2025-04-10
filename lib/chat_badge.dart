import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_service.dart';

class ChatBadge extends StatelessWidget {
  final String orderId;
  final Color color;
  final Widget child;
  final String userType; // 'customer' or 'driver'

  const ChatBadge({
    Key? key,
    required this.orderId,
    this.color = Colors.red,
    required this.child,
    required this.userType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ChatService _chatService = ChatService();
    final User? _currentUser = FirebaseAuth.instance.currentUser;

    if (_currentUser == null) return child;

    return StreamBuilder<int>(
      stream: Stream.periodic(Duration(seconds: 5)).asyncMap((_) {
        return _chatService.getUnreadMessageCount(
          orderId: orderId,
          userId: _currentUser.uid,
          userType: userType,
        );
      }),
      initialData: 0,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        if (unreadCount == 0) {
          return child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
