class ChatMessage {
  final String id;
  final String message;
  final String senderId;
  final String senderName;
  final String senderType;
  final String? receiverId;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    this.receiverId,
    required this.timestamp,
    required this.isRead,
  });

  factory ChatMessage.fromExistingStructure(String id, Map<dynamic, dynamic> data) {
    return ChatMessage(
      id: id,
      message: data['message'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['orderId'] ?? '',
      senderType: data['orderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'])
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  // Convert to map for Firebase
  Map<String, dynamic> toMap() {
    final result = {
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
    };

    if (receiverId != null) {
      result['receiverId'] = receiverId as Object;
    }
    return result;
  }
}
