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
  static const int TAB_COUNT = 4;
  static const List<String> TAB_TITLES = ["Followers", "Following", "Online", "Near"];

  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, initialIndex: 0, length: TAB_COUNT);
    _currentUserId = _auth.currentUser!.uid;
  }

  void _showUserProfile(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.8,
        maxChildSize: 1.0,
        expand: false,
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
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildUserList(context, 'followers'),
          _buildUserList(context, 'following'),
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
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Theme.of(context).colorScheme.secondary,
        labelColor: Theme.of(context).colorScheme.secondary,
        unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
        isScrollable: false,
        tabs: TAB_TITLES.map((title) => Tab(text: title)).toList(),
      ),
    );
  }

  Widget _buildUserList(BuildContext context, String listType) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUserStream(listType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator(context);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No $listType found.'));
        }

        List<Future<DocumentSnapshot>> userFutures = snapshot.data!.docs.map((doc) {
          return FirebaseFirestore.instance.collection('users').doc(doc.id).get();
        }).toList();

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(userFutures),
          builder: (context, userSnapshots) {
            if (!userSnapshots.hasData) {
              return Center(child: CircularProgressIndicator());
            }
            return _buildUserListView(userSnapshots.data!);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getUserStream(String listType) {
    if (listType == 'followers') {
      return FirebaseFirestore.instance
          .collection('followers')
          .doc(_currentUserId)
          .collection('userFollowers')
          .snapshots();
    } else if (listType == 'following') {
      return FirebaseFirestore.instance
          .collection('following')
          .doc(_currentUserId)
          .collection('userFollowing')
          .snapshots();
    } else {
      throw ArgumentError('Invalid listType: $listType');
    }
  }

  Widget _buildOnlineList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('online', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator(context);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No online users found.'));
        }

        return _buildUserListView(snapshot.data!.docs);
      },
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
        size: 50,
      ),
    );
  }

  Widget _buildUserListView(List<DocumentSnapshot> users) {
    return ListView.separated(
      padding: EdgeInsets.all(10),
      separatorBuilder: (context, index) => Divider(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        var user = users[index].data() as Map<String, dynamic>;
        return _buildUserListTile(user, users[index].id);
      },
    );
  }

  Widget _buildUserListTile(Map<String, dynamic> user, String userId) {
    return ListTile(
      leading: _buildUserAvatar(user),
      title: Text(user['name'] ?? 'Unknown'),
      subtitle: Text(user['status'] ?? ''),
      onTap: () => _showUserProfile(userId),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> user) {
    return CircleAvatar(
      backgroundColor: Colors.white,
      backgroundImage: _getUserProfileImage(user),
      radius: 25,
      child: _getUserProfileImage(user) == null
          ? Icon(Icons.person, size: 30.0, color: Colors.grey)
          : null,
    );
  }

  ImageProvider? _getUserProfileImage(Map<String, dynamic> user) {
    return user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty
        ? CachedNetworkImageProvider(user['profileImageUrl'])
        : null;
  }

  @override
  bool get wantKeepAlive => true;
}