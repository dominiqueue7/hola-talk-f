import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:HolaTalk/views/screens/settings/settings.dart';
import 'package:HolaTalk/views/screens/feeds/post_detail.dart'; // PostDetailPage를 임포트합니다

class Profile extends StatefulWidget {
  final Function(ThemeMode) updateThemeMode;

  Profile({required this.updateThemeMode});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  static Random random = Random();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _profileImageUrl;
  int _postCount = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      String? imageUrl = await _getProfileImageUrl(user.uid);
      int postCount = await _getPostCount(user.uid);
      int followerCount = await _getFollowerCount(user.uid);
      int followingCount = await _getFollowingCount(user.uid);
      setState(() {
        _profileImageUrl = imageUrl;
        _postCount = postCount;
        _followerCount = followerCount;
        _followingCount = followingCount;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      File? compressedImage = await _compressImage(imageFile);

      if (compressedImage != null) {
        User? user = _auth.currentUser;
        try {
          String? downloadUrl = await _uploadImage(compressedImage, user?.uid);
          if (downloadUrl != null) {
            await _updateProfileImageUrl(user?.uid, downloadUrl);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile image updated successfully.')));
            _loadProfileData(); // 프로필 이미지 URL을 다시 불러옵니다.
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
        }
      }
    }
  }

  Future<File?> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(dir.absolute.path, "${path.basenameWithoutExtension(file.path)}.heic");

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      format: CompressFormat.heic,
    );

    return result != null ? File(result.path) : null;
  }

  Future<String?> _uploadImage(File file, String? uid) async {
    if (uid != null) {
      final storageRef = _storage.ref().child('user_profile').child('$uid.heic');
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL();
    }
    return null;
  }

  Future<void> _updateProfileImageUrl(String? uid, String downloadUrl) async {
    if (uid != null) {
      await _firestore.collection('users').doc(uid).update({'profileImageUrl': downloadUrl});
    }
  }

  Future<String?> _getProfileImageUrl(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.data()?['profileImageUrl'];
    } catch (e) {
      print('Failed to get profile image URL: $e');
      return null;
    }
  }

  Future<int> _getPostCount(String uid) async {
    try {
      final postQuery = await _firestore.collection('moments').where('userId', isEqualTo: uid).get();
      return postQuery.size;
    } catch (e) {
      print('Failed to get post count: $e');
      return 0;
    }
  }

  Future<int> _getFollowerCount(String uid) async {
    try {
      final followerQuery = await _firestore.collection('followers').doc(uid).collection('userFollowers').get();
      return followerQuery.size;
    } catch (e) {
      print('Failed to get follower count: $e');
      return 0;
    }
  }

  Future<int> _getFollowingCount(String uid) async {
    try {
      final followingQuery = await _firestore.collection('following').doc(uid).collection('userFollowing').get();
      return followingQuery.size;
    } catch (e) {
      print('Failed to get following count: $e');
      return 0;
    }
  }

  Future<String?> _getUserName(String? uid) async {
    if (uid != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        return userDoc.data()?['name'];
      } catch (e) {
        print('Failed to get user name: $e');
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppSettings(updateThemeMode: widget.updateThemeMode), // updateThemeMode 전달
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
                size: 50,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(height: 60),
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            child: _profileImageUrl == null
                                ? Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.grey,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: _profileImageUrl!,
                                    imageBuilder: (context, imageProvider) => CircleAvatar(
                                      radius: 50,
                                      backgroundImage: imageProvider,
                                    ),
                                    placeholder: (context, url) => LoadingAnimationWidget.waveDots(
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
                                      size: 50,
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                _pickAndUploadImage();
                              },
                              child: Container(
                                height: 30,
                                width: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.black,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      FutureBuilder<String?>(
                        future: _getUserName(user?.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return LoadingAnimationWidget.waveDots(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
                              size: 50,
                            );
                          } else if (snapshot.hasError || !snapshot.hasData) {
                            return Text(
                              "Unknown User",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            );
                          } else {
                            return Text(
                              snapshot.data!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Status should be here",
                        style: TextStyle(),
                      ),
                      SizedBox(height: 40),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 50),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            _buildCategory("Posts", _postCount),
                            _buildCategory("Followers", _followerCount),
                            _buildCategory("Following", _followingCount),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      StreamBuilder(
                        stream: FirebaseFirestore.instance
                            .collection('moments')
                            .where('userId', isEqualTo: user?.uid)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return LoadingAnimationWidget.waveDots(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
                              size: 50,
                            );
                          }
                          if (!snapshot.hasData) {
                            return Center(child: Text("No posts available."));
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.all(5),
                            itemCount: snapshot.data!.docs.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 200 / 200,
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              var post = snapshot.data!.docs[index];
                              String imageUrl = post['imageUrl'] ?? '';
                              String content = post['content'] ?? '';

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostDetailPage(
                                        postId: post.id,
                                        userId: post['userId'],
                                        name: post['userName'],
                                        time: (post['createdAt'] as Timestamp).toDate(),
                                        img: imageUrl,
                                        content: content,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(3.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Color(0xFFEEF7FF),
                                    ),
                                    child: imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            placeholder: (context, url) => LoadingAnimationWidget.waveDots(
                                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
                                              size: 50,
                                            ),
                                            errorWidget: (context, url, error) => Icon(Icons.error),
                                            fit: BoxFit.cover,
                                          )
                                        : Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
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
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(String title, int count) {
    return Column(
      children: <Widget>[
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(),
        ),
      ],
    );
  }
}
