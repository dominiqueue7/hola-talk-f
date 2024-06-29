import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:HolaTalk/views/widgets/chat_item.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:intl/intl.dart';

class Chats extends StatefulWidget {
  @override
  _ChatsState createState() => _ChatsState();
}

class _ChatsState extends State<Chats> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 1) {
      if (dateTime.year == now.year) {
        return DateFormat('MM/dd HH:mm').format(dateTime); // 올해의 경우 월/일 시:분
      } else {
        return DateFormat('yyyy/MM/dd').format(dateTime); // 올해가 아닌 경우 년/월/일
      }
    } else {
      if (difference.inHours >= 1) {
        return '${difference.inHours} hours ago'; // 1시간 이상
      } else {
        return '${difference.inMinutes} minutes ago'; // 1시간 미만
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, initialIndex: 0, length: 2);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration.collapsed(
            hintText: 'Search',
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          labelColor: Theme.of(context).colorScheme.secondary,
          unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
          isScrollable: false,
          tabs: <Widget>[
            Tab(
              text: "Message",
            ),
            Tab(
              text: "Groups",
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildChatsList(context, false),
          _buildChatsList(context, true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(
          Icons.add,
          color: Colors.white,
        ),
        onPressed: () {},
      ),
    );
  }

  Widget _buildChatsList(BuildContext context, bool isGroup) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _auth.currentUser?.uid)
          .where('isGroup', isEqualTo: isGroup)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: LoadingAnimationWidget.staggeredDotsWave(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
              size: 50,
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No ${isGroup ? 'groups' : 'messages'} found.'));
        }

        var chatDocs = snapshot.data!.docs;
        var chatDataFutures = chatDocs.map((chat) async {
          var lastMessageSnapshot = await FirebaseFirestore.instance.collection('chats').doc(chat.id).collection('messages').orderBy('createdAt', descending: true).limit(1).get();
          if (lastMessageSnapshot.docs.isNotEmpty) {
            var lastMessage = lastMessageSnapshot.docs.first;
            DateTime createdAt;
            if (lastMessage['createdAt'] is Timestamp) {
              createdAt = (lastMessage['createdAt'] as Timestamp).toDate();
            } else if (lastMessage['createdAt'] is int) {
              createdAt = DateTime.fromMillisecondsSinceEpoch(lastMessage['createdAt']);
            } else {
              createdAt = DateTime.fromMillisecondsSinceEpoch(0); // 기본값, 예외 발생 시
            }
            return {
              'chat': chat,
              'lastMessage': lastMessage,
              'createdAt': createdAt,
            };
          } else {
            return {
              'chat': chat,
              'lastMessage': null,
              'createdAt': DateTime.fromMillisecondsSinceEpoch(0),
            };
          }
        }).toList();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait(chatDataFutures),
          builder: (context, chatDataSnapshot) {
            if (!chatDataSnapshot.hasData) {
              return Center(
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
                  size: 50,
                ),
              );
            }

            var chatDataList = chatDataSnapshot.data!;
            chatDataList.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));

            return ListView.separated(
              padding: EdgeInsets.all(10),
              separatorBuilder: (BuildContext context, int index) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    height: 0.5,
                    width: MediaQuery.of(context).size.width / 1.3,
                    child: Divider(),
                  ),
                );
              },
              itemCount: chatDataList.length,
              itemBuilder: (BuildContext context, int index) {
                var chatData = chatDataList[index];
                var chat = chatData['chat'];
                var lastMessage = chatData['lastMessage'];

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(chat['participants'].firstWhere((id) => id != _auth.currentUser!.uid)).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return SizedBox.shrink();
                    }

                    var user = userSnapshot.data!;
                    var userProfileUrl = '';
                    var userData = user.data() as Map<String, dynamic>?;
                    if (userData != null && userData.containsKey('profileImageUrl')) {
                      userProfileUrl = userData['profileImageUrl'] ?? '';
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('chats').doc(chat.id).collection('messages').where('status', isNotEqualTo: 'seen').snapshots(),
                      builder: (context, unreadSnapshot) {
                        if (!unreadSnapshot.hasData) {
                          return SizedBox.shrink();
                        }

                        var unreadMessages = unreadSnapshot.data!.docs;
                        var unreadCount = unreadMessages.where((msg) => msg['author.id'] != _auth.currentUser!.uid).length;

                        return ChatItem(
                          chatId: chat.id,
                          dp: userProfileUrl,
                          name: user['name'],
                          time: formatTime(chatData['createdAt']),
                          msg: lastMessage != null ? lastMessage['text'] : '',
                          isOnline: user['online'],
                          counter: unreadCount,
                          recipientId: user.id,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
