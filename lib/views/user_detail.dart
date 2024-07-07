import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:HolaTalk/widgets/animations/animated_button.dart';
import 'package:HolaTalk/views/chat/chat_screen.dart';
import 'package:HolaTalk/views/posts/post_detail.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  final ScrollController scrollController;

  const ProfilePage({Key? key, required this.userId, required this.scrollController}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Constants
  static const double _avatarRadius = 50.0;
  static const double _spacing = 10.0;
  static const int _gridCrossAxisCount = 3;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User data
  String? _profileImageUrl;
  String? _userName;
  String? _currentUserId;
  int _postCount = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadProfileData();
  }

  // Load all profile data
  Future<void> _loadProfileData() async {
    await Future.wait([
      _loadProfileImage(),
      _loadUserName(),
      _loadPostCount(),
      _loadFollowCounts(),
      _checkIfFollowing(),
    ]);
  }

  // Load profile image
  Future<void> _loadProfileImage() async {
    try {
      final ref = _storage.ref().child('user_profile/${widget.userId}.heic');
      final url = await ref.getDownloadURL();
      setState(() => _profileImageUrl = url);
    } catch (e) {
      print('Failed to load user profile image: $e');
    }
  }

  // Load user name
  Future<void> _loadUserName() async {
    try {
      final userDoc = await _firestore.collection('users').doc(widget.userId).get();
      setState(() => _userName = userDoc.data()?['name']);
    } catch (e) {
      print('Failed to load user name: $e');
    }
  }

  // Load post count
  Future<void> _loadPostCount() async {
    try {
      final postQuery = await _firestore
          .collection('moments')
          .where('userId', isEqualTo: widget.userId)
          .get();
      setState(() => _postCount = postQuery.size);
    } catch (e) {
      print('Failed to load post count: $e');
    }
  }

  // Load follower and following counts
  Future<void> _loadFollowCounts() async {
    try {
      final followerQuery = await _firestore.collection('followers').doc(widget.userId).collection('userFollowers').get();
      final followingQuery = await _firestore.collection('following').doc(widget.userId).collection('userFollowing').get();
      setState(() {
        _followerCount = followerQuery.size;
        _followingCount = followingQuery.size;
      });
    } catch (e) {
      print('Failed to load follow counts: $e');
    }
  }

  // Check if current user is following the profile user
  Future<void> _checkIfFollowing() async {
    try {
      final doc = await _firestore
          .collection('followers')
          .doc(widget.userId)
          .collection('userFollowers')
          .doc(_currentUserId)
          .get();
      setState(() => _isFollowing = doc.exists);
    } catch (e) {
      print('Failed to check following status: $e');
    }
  }

  // Follow user
  Future<void> _followUser() async {
    try {
      await _firestore.collection('followers').doc(widget.userId).collection('userFollowers').doc(_currentUserId).set({});
      await _firestore.collection('following').doc(_currentUserId).collection('userFollowing').doc(widget.userId).set({});
      setState(() {
        _isFollowing = true;
        _followerCount += 1;
      });
    } catch (e) {
      print('Failed to follow user: $e');
    }
  }

  // Unfollow user
  Future<void> _unfollowUser() async {
    try {
      await _firestore.collection('followers').doc(widget.userId).collection('userFollowers').doc(_currentUserId).delete();
      await _firestore.collection('following').doc(_currentUserId).collection('userFollowing').doc(widget.userId).delete();
      setState(() {
        _isFollowing = false;
        _followerCount -= 1;
      });
    } catch (e) {
      print('Failed to unfollow user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Container(
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 60),
              _buildProfileAvatar(),
              const SizedBox(height: _spacing),
              _buildUserName(),
              const SizedBox(height: _spacing),
              const Text("Status should be here"),
              if (widget.userId != _currentUserId) ...[
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
              const SizedBox(height: 40),
              _buildStatistics(),
              const SizedBox(height: 20),
              _buildPostGrid(),
            ],
          ),
        ),
      ),
    );
  }

  // Build profile avatar
  Widget _buildProfileAvatar() {
    return CircleAvatar(
      radius: _avatarRadius,
      backgroundColor: Colors.grey[200],
      child: _profileImageUrl == null
          ? const Icon(Icons.person, size: 50, color: Colors.grey)
          : CachedNetworkImage(
              imageUrl: _profileImageUrl!,
              imageBuilder: (context, imageProvider) => CircleAvatar(
                radius: _avatarRadius,
                backgroundImage: imageProvider,
              ),
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.person, size: 50, color: Colors.grey),
            ),
    );
  }

  // Build user name
  Widget _buildUserName() {
    return Text(
      _userName ?? "Unknown User",
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
    );
  }

  // Build action buttons (Message and Follow/Unfollow)
  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedButton(
          label: "Message",
          color: Colors.grey,
          textColor: Colors.white,
          onPressed: _navigateToChatScreen,
        ),
        const SizedBox(width: _spacing),
        AnimatedButton(
          label: _isFollowing ? "Unfollow" : "Follow",
          color: Theme.of(context).colorScheme.secondary,
          textColor: Colors.white,
          onPressed: _isFollowing ? _unfollowUser : _followUser,
        ),
      ],
    );
  }

  // Navigate to chat screen
  void _navigateToChatScreen() {
    List<String> ids = [_currentUserId!, widget.userId];
    ids.sort();
    String chatId = ids.join("_");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chatId: chatId,
          recipientId: widget.userId,
        ),
      ),
    );
  }

  // Build statistics (Posts, Followers, Following)
  Widget _buildStatistics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildCategory("Posts", _postCount),
          _buildCategory("Followers", _followerCount),
          _buildCategory("Following", _followingCount),
        ],
      ),
    );
  }

  // Build category (for statistics)
  Widget _buildCategory(String title, int count) {
    return Column(
      children: <Widget>[
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(title),
      ],
    );
  }

  // Build post grid
  Widget _buildPostGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('moments')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Center(child: Text('No posts yet.'));
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(5),
          itemCount: posts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridCrossAxisCount,
            childAspectRatio: 1,
          ),
          itemBuilder: (BuildContext context, int index) => _buildPostTile(posts[index]),
        );
      },
    );
  }

  // Build individual post tile
  Widget _buildPostTile(QueryDocumentSnapshot post) {
    var imageUrl = post['imageUrl'] as String? ?? '';
    var content = post['content'] as String? ?? '';

    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : const Color(0xFFEEF7FF),
          ),
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                  fit: BoxFit.cover,
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      content.length > 50 ? '${content.substring(0, 50)}...' : content,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // Navigate to post detail
  void _navigateToPostDetail(QueryDocumentSnapshot post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          postId: post.id,
          userId: widget.userId,
          name: _userName ?? 'Unknown User',
          time: (post['createdAt'] as Timestamp).toDate(),
          img: post['imageUrl'] as String? ?? '',
          content: post['content'] as String? ?? '',
        ),
      ),
    );
  }
}