import 'package:firebase_database/firebase_database.dart';
import 'chat_message.dart';

class ChatService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Send a message between customer and driver
  Future<void> sendMessage({
    required String orderId,
    required String senderId,
    required String senderName,
    required String senderType, // 'customer' or 'driver'
    required String receiverId,
    required String message,
  }) async {
    try {
      // Path is chat_management/customer_driver/orderId
      final newMessageRef =
          _database.child('chat_management/customer_driver/$orderId').push();

      final messageData = {
        'message': message,
        'senderId': senderId,
        'senderName': senderName,
        'senderType': senderType,
        'timestamp': ServerValue.timestamp,
        'isRead': false,
      };

      // Add receiverId only when sender is driver, to follow firebase structure
      if (senderType == 'driver') {
        messageData['receiverId'] = receiverId;
      }

      await newMessageRef.set(messageData);
    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }

  // Send a message from driver to admin
  Future<void> sendAdminMessage({
    required String driverId,
    required String senderName,
    required String message,
  }) async {
    try {
      // Path is chat_management/driver_admin/driverId
      final newMessageRef =
          _database.child('chat_management/driver_admin/$driverId').push();

      await newMessageRef.set({
        'message': message,
        'senderId': driverId,
        'senderName': senderName,
        'senderType': 'driver',
        'timestamp': ServerValue.timestamp,
        'read': false,
        'messageId': newMessageRef.key,
      });
    } catch (e) {
      print('Error sending admin message: $e');
      throw e;
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead({
    required String orderId,
    required String messageId,
  }) async {
    try {
      await _database
          .child('chat_management/customer_driver/$orderId/$messageId')
          .update({'isRead': true});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Get messages for a specific order
  Stream<List<ChatMessage>> getMessagesForOrder(String orderId) {
    return _database
        .child('chat_management/customer_driver/$orderId')
        .onValue
        .map((event) {
      final messagesData = event.snapshot.value;
      if (messagesData == null) return [];

      List<ChatMessage> messages = [];
      if (messagesData is Map) {
        (messagesData).forEach((key, value) {
          if (value is Map) {
            messages
                .add(ChatMessage.fromExistingStructure(key.toString(), value));
          }
        });
      }

      // Sort by timestamp (newest last)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  // Get driver to admin messages
  Stream<List<ChatMessage>> getDriverAdminMessages(String driverId) {
    return _database
        .child('chat_management/driver_admin/$driverId')
        .onValue
        .map((event) {
      final messagesData = event.snapshot.value;
      if (messagesData == null) return [];

      List<ChatMessage> messages = [];
      if (messagesData is Map) {
        (messagesData).forEach((key, value) {
          if (value is Map) {
            messages
                .add(ChatMessage.fromExistingStructure(key.toString(), value));
          }
        });
      }

      // Sort by timestamp (newest last)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  // Check for unread messages
  Future<int> getUnreadMessageCount({
    required String orderId,
    required String userId,
    required String userType, // 'customer' or 'driver'
  }) async {
    try {
      final messagesSnapshot = await _database
          .child('chat_management/customer_driver/$orderId')
          .get();

      if (!messagesSnapshot.exists) return 0;

      final messages = messagesSnapshot.value as Map<dynamic, dynamic>;
      int unreadCount = 0;

      messages.forEach((key, value) {
        if (value is Map) {
          // For customer, count unread messages from drivers
          if (userType == 'customer' &&
              value['senderType'] == 'driver' &&
              value['isRead'] == false) {
            unreadCount++;
          }
          // For driver, count unread messages from customers
          else if (userType == 'driver' &&
              value['senderType'] == 'customer' &&
              value['isRead'] == false) {
            unreadCount++;
          }
        }
      });

      return unreadCount;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }
}
