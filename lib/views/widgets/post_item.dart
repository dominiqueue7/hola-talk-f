import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:HolaTalk/views/screens/feeds/post_detail.dart'; // PostDetailPage를 임포트합니다.

class PostItem extends StatefulWidget {
  final String postId;
  final String userId;
  final String name;
  final DateTime time;
  final String img;
  final String content;
  final int? maxLines; // maxLines 추가

  PostItem({
    super.key,
    required this.postId,
    required this.userId,
    required this.name,
    required this.time,
    required this.img,
    required this.content,
    this.maxLines, // maxLines 추가
  });

  @override
  _PostItemState createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  String? userProfileUrl;

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(
                postId: widget.postId,
                userId: widget.userId,
                name: widget.name,
                time: widget.time,
                img: widget.img,
                content: widget.content,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: userProfileUrl != null
                    ? null
                    : Icon(Icons.person, size: 30.0),
                backgroundImage: userProfileUrl != null
                    ? CachedNetworkImageProvider(userProfileUrl!)
                    : null,
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
                height: 170,
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                widget.content,
                maxLines: widget.maxLines, // maxLines 설정
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
