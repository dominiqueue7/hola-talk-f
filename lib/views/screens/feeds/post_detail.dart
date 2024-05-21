import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:HolaTalk/views/screens/user_detail.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserProfileImage();
  }

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

  Future<void> _postComment() async {
    if (_commentController.text.isNotEmpty) {
      await FirebaseFirestore.instance.collection('comments').add({
        'postId': widget.postId,
        'userId': widget.userId,
        'userName': widget.name,
        'comment': _commentController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _commentController.clear();
    }
  }

  Future<String?> _getUserProfileImage(String userId) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('user_profile/$userId.heic');
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Failed to load user profile image for $userId: $e');
      return null;
    }
  }

  void _showUserProfile(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.9,
        maxChildSize: 1.0,
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
    return Scaffold(
      appBar: AppBar(
        title: Text("Post Detail"),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              leading: GestureDetector(
                onTap: () => _showUserProfile(widget.userId),
                child: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: userProfileUrl != null
                      ? null
                      : Icon(Icons.person, size: 30.0),
                  backgroundImage: userProfileUrl != null
                      ? CachedNetworkImageProvider(userProfileUrl!)
                      : null,
                ),
              ),
              contentPadding: EdgeInsets.all(0),
              title: Text(
                widget.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              trailing: Text(
                formatTime(widget.time),
                style: TextStyle(
                  fontWeight: FontWeight.w300,
                  fontSize: 11,
                ),
              ),
            ),
            if (widget.img.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.img,
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(widget.content),
            ),
            SizedBox(height: 20),
            TextField(
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
            ),
            SizedBox(height: 20),
            Text(
              "Comments",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot>(
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
                                  : Icon(Icons.person, size: 30.0),
                              backgroundImage: imageUrl != null
                                  ? CachedNetworkImageProvider(imageUrl)
                                  : null,
                            ),
                          ),
                          title: Text(
                            comment['userName'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          subtitle: Text(comment['comment']),
                          trailing: Text(
                            formatTime((comment['createdAt'] as Timestamp).toDate()),
                            style: TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
