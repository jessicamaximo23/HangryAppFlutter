import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'chat_service.dart';
import 'chat_message.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String receiverId;
  final String receiverName;
  final String orderStatus;
  final String userType; // 'customer' or 'driver'

  const ChatScreen({
    Key? key,
    required this.orderId,
    required this.receiverId,
    required this.receiverName,
    required this.orderStatus,
    required this.userType,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  late StreamSubscription<List<ChatMessage>> _messagesSubscription;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messagesSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    if (_currentUser == null) return;

    _messagesSubscription =
        _chatService.getMessagesForOrder(widget.orderId).listen((messages) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Mark incoming messages as read
      _markIncomingMessagesAsRead();

      // Scroll to bottom when new messages come in
      _scrollToBottom();
    });
  }

  void _markIncomingMessagesAsRead() {
    // Mark messages as read if they're for the current user
    for (final message in _messages) {
      if (!message.isRead && message.senderType != widget.userType) {
        _chatService.markMessageAsRead(
          orderId: widget.orderId,
          messageId: message.id,
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUser == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      String userName = _currentUser!.displayName ?? 'User';

      // Get user name from Firebase if not available locally
      if (userName == 'User') {
        final userSnapshot = await FirebaseDatabase.instance
            .ref('users/${_currentUser!.uid}')
            .get();

        if (userSnapshot.exists && userSnapshot.value is Map) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          userName = userData['name'] ?? 'User';
        }
      }

      // Determine the appropriate sender display name based on user type
      String senderName = widget.userType == 'customer' ? 'Cliente' : userName;

      await _chatService.sendMessage(
        orderId: widget.orderId,
        senderId: _currentUser!.uid,
        senderName: senderName,
        senderType: widget.userType,
        receiverId: widget.receiverId,
        message: message,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiverName,
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'RammettoOne-Regular',
              ),
            ),
            Text(
              'Order #${widget.orderId.substring(0, Math.min(8, widget.orderId.length))}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        backgroundColor: hangryYellow,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Order status indicator
          Container(
            color: _getStatusColor(widget.orderStatus).withOpacity(0.1),
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(widget.orderStatus),
                  color: _getStatusColor(widget.orderStatus),
                ),
                SizedBox(width: 8),
                Text(
                  _getStatusText(widget.orderStatus),
                  style: TextStyle(
                    color: _getStatusColor(widget.orderStatus),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: hangryYellow))
                : _messages.isEmpty
                    ? _buildEmptyMessages()
                    : _buildMessagesList(),
          ),

          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Send a message to start the conversation',
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderType == widget.userType;

        // Show date divider
        bool showDateDivider = false;
        if (index == 0) {
          showDateDivider = true;
        } else {
          final previousDate = _messages[index - 1].timestamp.day;
          final currentDate = message.timestamp.day;
          showDateDivider = previousDate != currentDate;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDateDivider) _buildDateDivider(message.timestamp),
            _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              DateFormat('MMMM d, yyyy').format(date),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: hangryBlue,
              radius: 16,
              child: Icon(
                isMe ? Icons.person : Icons.delivery_dining,
                color: Colors.white,
                size: 16,
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? hangryYellow : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 16,
                      color: isMe ? Colors.black : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.black54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            SizedBox(width: 8),
            Icon(
              message.isRead ? Icons.done_all : Icons.done,
              size: 16,
              color: message.isRead ? Colors.blue : Colors.grey,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 5,
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            child: Icon(Icons.send),
            backgroundColor: hangryYellow,
            mini: true,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'preparing':
        return Colors.orange;
      case 'ready_for_pickup':
        return Colors.blue;
      case 'on_the_way':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.receipt;
      case 'preparing':
        return Icons.restaurant;
      case 'ready_for_pickup':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Order Pending';
      case 'preparing':
        return 'Order Being Prepared';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'on_the_way':
        return 'Order On the Way';
      case 'delivered':
        return 'Order Delivered';
      case 'cancelled':
        return 'Order Cancelled';
      default:
        return 'Status Unknown';
    }
  }
}
