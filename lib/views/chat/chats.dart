import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:HolaTalk/views/chat/chat_item.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:intl/intl.dart';

/// 채팅 목록(메시지 및 그룹)을 표시하는 Chats 위젯
class Chats extends StatefulWidget {
  @override
  _ChatsState createState() => _ChatsState();
}

class _ChatsState extends State<Chats> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, initialIndex: 0, length: 2);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildChatsList(isGroup: false),
          _buildChatsList(isGroup: true),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// 검색 필드와 필터 버튼이 있는 앱바 구축
  AppBar _buildAppBar() {
    return AppBar(
      title: TextField(
        decoration: InputDecoration.collapsed(hintText: 'Search'),
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.filter_list),
          onPressed: () {},
        ),
      ],
      bottom: _buildTabBar(),
    );
  }

  /// 메시지와 그룹 간 전환을 위한 탭바 구축
  TabBar _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: Theme.of(context).colorScheme.secondary,
      labelColor: Theme.of(context).colorScheme.secondary,
      unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
      isScrollable: false,
      tabs: <Widget>[
        Tab(text: "Message"),
        Tab(text: "Groups"),
      ],
    );
  }

  /// 새 채팅 생성을 위한 플로팅 액션 버튼 구축
  FloatingActionButton _buildFloatingActionButton() {
    return FloatingActionButton(
      child: Icon(Icons.add, color: Colors.white),
      onPressed: () {},
    );
  }

  /// 채팅 목록(메시지 또는 그룹) 구축
  Widget _buildChatsList({required bool isGroup}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getChatStream(isGroup),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyListIndicator(isGroup);
        }
        return _buildChatListView(snapshot.data!.docs);
      },
    );
  }

  /// 현재 사용자의 채팅(메시지 또는 그룹) 스트림 반환
  Stream<QuerySnapshot> _getChatStream(bool isGroup) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: _auth.currentUser?.uid)
        .where('isGroup', isEqualTo: isGroup)
        .snapshots();
  }

  /// 로딩 인디케이터 위젯 구축
  Widget _buildLoadingIndicator() {
    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
        size: 50,
      ),
    );
  }

  /// 채팅 목록이 비어있을 때 표시할 위젯 구축
  Widget _buildEmptyListIndicator(bool isGroup) {
    return Center(child: Text('No ${isGroup ? 'groups' : 'messages'} found.'));
  }

  /// 채팅 항목 리스트뷰 구축
  Widget _buildChatListView(List<QueryDocumentSnapshot> chatDocs) {
    return ListView.separated(
      padding: EdgeInsets.all(10),
      itemCount: chatDocs.length,
      separatorBuilder: _buildSeparator,
      itemBuilder: (context, index) => _buildChatItem(chatDocs[index]),
    );
  }

  /// 채팅 항목 사이의 구분자 위젯 구축
  Widget _buildSeparator(BuildContext context, int index) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        height: 0.5,
        width: MediaQuery.of(context).size.width / 1.3,
        child: Divider(),
      ),
    );
  }

  /// 단일 채팅 항목 위젯 구축
  Widget _buildChatItem(QueryDocumentSnapshot chat) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getLastMessageStream(chat.id),
      builder: (context, lastMessageSnapshot) {
        if (!lastMessageSnapshot.hasData) {
          return SizedBox.shrink();
        }
        var lastMessage = _getLastMessageData(lastMessageSnapshot);
        return _buildUserInfo(chat, lastMessage);
      },
    );
  }

  /// 주어진 채팅의 마지막 메시지 스트림 반환
  Stream<QuerySnapshot> _getLastMessageStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  /// 스냅샷에서 마지막 메시지 데이터 추출
  Map<String, dynamic>? _getLastMessageData(AsyncSnapshot<QuerySnapshot> snapshot) {
    return snapshot.data!.docs.isNotEmpty ? snapshot.data!.docs.first.data() as Map<String, dynamic> : null;
  }

  /// 채팅 항목의 사용자 정보 위젯 구축
  Widget _buildUserInfo(QueryDocumentSnapshot chat, Map<String, dynamic>? lastMessage) {
    return FutureBuilder<DocumentSnapshot>(
      future: _getUserDocument(chat),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return SizedBox.shrink();
        }
        var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        return _buildUnreadMessageCounter(chat, userData, lastMessage);
      },
    );
  }

  /// 주어진 채팅의 사용자 문서 검색
  Future<DocumentSnapshot> _getUserDocument(QueryDocumentSnapshot chat) {
    String userId = chat['participants'].firstWhere((id) => id != _auth.currentUser!.uid);
    return _firestore.collection('users').doc(userId).get();
  }

  /// 채팅 항목의 읽지 않은 메시지 카운터 구축
  Widget _buildUnreadMessageCounter(QueryDocumentSnapshot chat, Map<String, dynamic>? userData, Map<String, dynamic>? lastMessage) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUnreadMessagesStream(chat.id),
      builder: (context, unreadSnapshot) {
        if (!unreadSnapshot.hasData) {
          return SizedBox.shrink();
        }
        int unreadCount = _getUnreadCount(unreadSnapshot);
        return _buildChatItemWidget(chat, userData, lastMessage, unreadCount);
      },
    );
  }

  /// 주어진 채팅의 읽지 않은 메시지 스트림 반환
  Stream<QuerySnapshot> _getUnreadMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('status', isNotEqualTo: 'seen')
        .snapshots();
  }

  /// 읽지 않은 메시지 수 계산
  int _getUnreadCount(AsyncSnapshot<QuerySnapshot> snapshot) {
    return snapshot.data!.docs.where((msg) => msg['author.id'] != _auth.currentUser!.uid).length;
  }

  /// 최종 ChatItem 위젯 구축
  Widget _buildChatItemWidget(QueryDocumentSnapshot chat, Map<String, dynamic>? userData, Map<String, dynamic>? lastMessage, int unreadCount) {
    return ChatItem(
      chatId: chat.id,
      dp: userData?['profileImageUrl'] ?? '',
      name: userData?['name'] ?? 'Unknown',
      time: _formatTime(_getMessageTimestamp(lastMessage)),
      msg: lastMessage?['text'] ?? '',
      isOnline: userData?['online'] ?? false,
      counter: unreadCount,
      recipientId: userData?['uid'] ?? '',
    );
  }

  /// 메시지의 타임스탬프 검색
  DateTime _getMessageTimestamp(Map<String, dynamic>? message) {
    if (message == null || !message.containsKey('createdAt')) {
      return DateTime.now();
    }
    var createdAt = message['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    } else if (createdAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(createdAt);
    }
    return DateTime.now();
  }

  /// 채팅 항목에 표시할 시간 형식 지정
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 1) {
      return dateTime.year == now.year
          ? DateFormat('MM/dd HH:mm').format(dateTime)
          : DateFormat('yyyy/MM/dd').format(dateTime);
    } else {
      return difference.inHours >= 1
          ? '${difference.inHours} hours ago'
          : '${difference.inMinutes} minutes ago';
    }
  }

  @override
  bool get wantKeepAlive => true;
}