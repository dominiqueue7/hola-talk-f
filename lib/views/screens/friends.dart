import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:HolaTalk/views/screens/user_detail.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Friends extends StatefulWidget {
  @override
  _FriendsState createState() => _FriendsState();
}

class _FriendsState extends State<Friends>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, initialIndex: 0, length: 4);
    _currentUserId = _auth.currentUser!.uid;
  }

  void _showUserProfile(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 1.0, // 모달 열렸을때 얼마나 보여줄지 비율
        minChildSize: 0.8, // 얼마나 내려야 닫히는지 비율
        maxChildSize: 1.0,
        expand: false, // 모달 윗부분 빈공간 제거
        builder: (context, scrollController) {
          return ProfilePage(
            userId: userId,
            scrollController: scrollController,
          );
        },
      ),
    );
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
            Tab(text: "Followers"),
            Tab(text: "Following"),
            Tab(text: "Online"),
            Tab(text: "Near"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildFollowersList(context),
          _buildFollowingList(context),
          _buildOnlineList(context),
          Center(child: Text('Near')), // Placeholder for Near tab
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {},
      ),
    );
  }

  Widget _buildFollowersList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('followers')
          .doc(_currentUserId)
          .collection('userFollowers')
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
          return Center(child: Text('No followers found.'));
        }

        List<Future<DocumentSnapshot>> userFutures = snapshot.data!.docs.map((doc) {
          String followerId = doc.id;
          return FirebaseFirestore.instance.collection('users').doc(followerId).get();
        }).toList();

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(userFutures),
          builder: (context, userSnapshots) {
            if (!userSnapshots.hasData) {
              return Center(child: CircularProgressIndicator());
            }
            var userDocs = userSnapshots.data!;
            return ListView.separated(
              padding: EdgeInsets.all(10),
              separatorBuilder: (context, index) {
                return Divider();
              },
              itemCount: userDocs.length,
              itemBuilder: (context, index) {
                var user = userDocs[index].data() as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty 
                        ? CachedNetworkImageProvider(user['profileImageUrl']) 
                        : null,
                    radius: 25,
                    child: user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty 
                        ? Icon(Icons.person, size: 30.0, color: Colors.grey) 
                        : null,
                  ),
                  title: Text(user['name'] ?? 'Unknown'),
                  subtitle: Text(user['status'] ?? ''),
                  onTap: () => _showUserProfile(userDocs[index].id),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFollowingList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('following')
          .doc(_currentUserId)
          .collection('userFollowing')
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
          return Center(child: Text('No following users found.'));
        }

        List<Future<DocumentSnapshot>> userFutures = snapshot.data!.docs.map((doc) {
          String followingId = doc.id;
          return FirebaseFirestore.instance.collection('users').doc(followingId).get();
        }).toList();

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(userFutures),
          builder: (context, userSnapshots) {
            if (!userSnapshots.hasData) {
              return Center(child: CircularProgressIndicator());
            }
            var userDocs = userSnapshots.data!;
            return ListView.separated(
              padding: EdgeInsets.all(10),
              separatorBuilder: (context, index) {
                return Divider();
              },
              itemCount: userDocs.length,
              itemBuilder: (context, index) {
                var user = userDocs[index].data() as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty 
                        ? CachedNetworkImageProvider(user['profileImageUrl']) 
                        : null,
                    radius: 25,
                    child: user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty 
                        ? Icon(Icons.person, size: 30.0, color: Colors.grey) 
                        : null,
                  ),
                  title: Text(user['name'] ?? 'Unknown'),
                  subtitle: Text(user['status'] ?? ''),
                  onTap: () => _showUserProfile(userDocs[index].id),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOnlineList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('online', isEqualTo: true)
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
          return Center(child: Text('No online users found.'));
        }

        return ListView.separated(
          padding: EdgeInsets.all(10),
          separatorBuilder: (context, index) {
            return Divider();
          },
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var user = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty 
                    ? CachedNetworkImageProvider(user['profileImageUrl']) 
                    : null,
                radius: 25,
                child: user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty 
                    ? Icon(Icons.person, size: 30.0, color: Colors.grey) 
                    : null,
              ),
              title: Text(user['name'] ?? 'Unknown'),
              subtitle: Text(user['status'] ?? ''),
              onTap: () => _showUserProfile(snapshot.data!.docs[index].id),
            );
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
