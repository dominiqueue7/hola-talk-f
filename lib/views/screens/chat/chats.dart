import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:HolaTalk/views/widgets/chat_item.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class Chats extends StatefulWidget {
  @override
  _ChatsState createState() => _ChatsState();
}

class _ChatsState extends State<Chats>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (BuildContext context, int index) {
            var chat = snapshot.data!.docs[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(chat['participants'].firstWhere((id) => id != _auth.currentUser!.uid)).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return SizedBox.shrink();
                }

                var user = userSnapshot.data!;
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('chats').doc(chat.id).collection('messages').orderBy('createdAt', descending: true).limit(1).get(),
                  builder: (context, messageSnapshot) {
                    if (!messageSnapshot.hasData) {
                      return SizedBox.shrink();
                    }

                    var lastMessage = messageSnapshot.data!.docs.first;

                    // unreadCount 계산을 위해 모든 메시지를 다시 쿼리
                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('chats').doc(chat.id).collection('messages').where('status', isNotEqualTo: 'seen').get(),
                      builder: (context, unreadSnapshot) {
                        if (!unreadSnapshot.hasData) {
                          return SizedBox.shrink();
                        }

                        var unreadCount = unreadSnapshot.data!.docs.length;

                        // 여기서 createdAt 필드를 적절하게 처리합니다.
                        DateTime createdAt;
                        if (lastMessage['createdAt'] is Timestamp) {
                          createdAt = (lastMessage['createdAt'] as Timestamp).toDate();
                        } else if (lastMessage['createdAt'] is int) {
                          createdAt = DateTime.fromMillisecondsSinceEpoch(lastMessage['createdAt']);
                        } else {
                          createdAt = DateTime.now(); // 기본값, 예외 발생 시 현재 시간
                        }

                        return ChatItem(
                          chatId: chat.id,
                          dp: user['profileImageUrl'],
                          name: user['name'],
                          time: createdAt.toString(),
                          msg: lastMessage['text'],
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
