import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostItem extends StatefulWidget {
  final String userId;
  final String name;
  final String time;
  final String img;
  final String content;

  PostItem({
    super.key,
    required this.userId,
    required this.name,
    required this.time,
    required this.img,
    required this.content,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
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
                widget.time,
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
              child: Text(widget.content),
            ),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
