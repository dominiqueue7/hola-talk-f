import 'package:HolaTalk/views/widgets/delete_post.dart';
import 'package:HolaTalk/views/widgets/format_time.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:HolaTalk/views/screens/user_detail.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  final String userId;
  final String name;
  final DateTime time;
  final String img;
  final String content;

  PostDetailPage({
    required this.postId,
    required this.userId,
    required this.name,
    required this.time,
    required this.img,
    required this.content,
  });

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  String? userProfileUrl;
  final TextEditingController _commentController = TextEditingController();
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfileImage();
  }

  // 사용자 프로필 이미지 로드
  Future<void> _loadUserProfileImage() async {
    try {
      final ref = FirebaseStorage.instance.ref().child('user_profile/${widget.userId}.heic');
      final url = await ref.getDownloadURL();
      setState(() {
        userProfileUrl = url;
      });
    } catch (e) {
      print('Failed to load user profile image: $e');
    }
  }

  // 댓글 작성 함수
  Future<void> _postComment() async {
    if (_commentController.text.isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Firestore에서 현재 사용자의 이름을 가져옵니다
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        final userName = userDoc.data()?['name'] ?? 'Anonymous';
        
        await FirebaseFirestore.instance.collection('comments').add({
          'postId': widget.postId,
          'userId': currentUser.uid,
          'userName': userName,
          'comment': _commentController.text,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _commentController.clear();
        FocusScope.of(context).unfocus(); // 댓글 작성 후 키보드 숨기기
      }
    }
  }

  // 사용자 프로필 이미지 가져오기
  Future<String?> _getUserProfileImage(String userId) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('user_profile/$userId.heic');
      return await ref.getDownloadURL();
    } catch (e) {
      print('Failed to load profile image for user $userId: $e');
      return null;
    }
  }

  // 사용자 프로필 모달 표시
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

  // 게시물 삭제 함수
  Future<void> _deletePost() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      // 트랜잭션을 사용하여 게시물과 관련 댓글을 동시에 삭제합니다
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 게시물 삭제
        transaction.delete(FirebaseFirestore.instance.collection('moments').doc(widget.postId));

        // 관련 댓글 삭제
        final commentSnapshots = await FirebaseFirestore.instance
            .collection('comments')
            .where('postId', isEqualTo: widget.postId)
            .get();
        
        for (var doc in commentSnapshots.docs) {
          transaction.delete(doc.reference);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post deleted successfully.')));
      Navigator.pop(context, 'deleted'); // '삭제됨' 상태와 함께 이전 화면으로 돌아갑니다
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete post: $e')));
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Post Detail"),
        actions: [
          if (currentUser != null && currentUser.uid == widget.userId && !_isDeleting)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () async {
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete Post'),
                    content: Text('Are you sure you want to delete this post?'),
                    actions: [
                      TextButton(
                        child: Text('Cancel'),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      TextButton(
                        child: Text('Delete'),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                );
                if (shouldDelete == true) {
                  setState(() {
                    _isDeleting = true;
                  });
                  
                  bool deleted = await DeletePost.deletePost(context, widget.postId);
                  
                  if (deleted) {
                    Navigator.pop(context, 'deleted'); // Return to previous screen with 'deleted' status
                  } else {
                    setState(() {
                      _isDeleting = false;
                    });
                  }
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 게시물 작성자 정보
                  _buildAuthorInfo(),
                  // 게시물 이미지 (있는 경우)
                  if (widget.img.isNotEmpty) _buildPostImage(),
                  // 게시물 내용
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(widget.content),
                  ),
                  SizedBox(height: 20),
                  // 댓글 입력 필드
                  _buildCommentInputField(),
                  SizedBox(height: 20),
                  Text(
                    "Comments",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // 댓글 목록
                  _buildCommentsList(),
                ],
              ),
            ),
          ),
          // 삭제 중 표시기
          if (_isDeleting) _buildDeletingIndicator(),
        ],
      ),
    );
  }

  // 게시물 작성자 정보 위젯 구축
  Widget _buildAuthorInfo() {
    return ListTile(
      leading: GestureDetector(
        onTap: () => _showUserProfile(widget.userId),
        child: CircleAvatar(
          backgroundColor: Colors.grey[200],
          child: userProfileUrl != null
              ? null
              : Icon(Icons.person, size: 30.0, color: Colors.grey),
          backgroundImage: userProfileUrl != null
              ? CachedNetworkImageProvider(userProfileUrl!)
              : null,
        ),
      ),
      contentPadding: EdgeInsets.all(0),
      title: Text(
        widget.name,
        style: TextStyle(fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Text(
        FormatTime.formatTime(widget.time),
        style: TextStyle(fontWeight: FontWeight.w300, fontSize: 11),
      ),
    );
  }

  // 게시물 이미지 위젯 구축
  Widget _buildPostImage() {
    return CachedNetworkImage(
      imageUrl: widget.img,
      width: MediaQuery.of(context).size.width,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => Icon(Icons.error),
    );
  }

  // 댓글 입력 필드 위젯 구축
  Widget _buildCommentInputField() {
    return TextField(
      controller: _commentController,
      decoration: InputDecoration(
        labelText: "Write a comment...",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(),
        ),
        suffixIcon: IconButton(
          icon: Icon(Icons.send),
          onPressed: _postComment,
        ),
      ),
    );
  }

  // 댓글 목록 위젯 구축
  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('comments')
          .where('postId', isEqualTo: widget.postId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No comments yet."));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var comment = snapshot.data!.docs[index];
            var commentUserId = comment['userId'];
            return FutureBuilder<String?>(
              future: _getUserProfileImage(commentUserId),
              builder: (context, snapshot) {
                String? imageUrl = snapshot.data;
                return ListTile(
                  leading: GestureDetector(
                    onTap: () => _showUserProfile(commentUserId),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: imageUrl != null
                          ? null
                          : Icon(Icons.person, size: 30.0, color: Colors.grey),
                      backgroundImage: imageUrl != null
                          ? CachedNetworkImageProvider(imageUrl)
                          : null,
                    ),
                  ),
                  title: Text(
                    comment['userName'] ?? 'Anonymous',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: Text(comment['comment'] ?? ''),
                  trailing: Text(
                    FormatTime.formatCommentTime(comment['createdAt']),
                    style: TextStyle(fontSize: 11),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 삭제 중 표시기 위젯 구축
  Widget _buildDeletingIndicator() {
    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
        size: 50,
      ),
    );
  }
}