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
import 'package:HolaTalk/views/settings/settings.dart';
import 'package:HolaTalk/views/posts/post_detail.dart';

// 프로필 위젯 클래스
class Profile extends StatefulWidget {
  final Function(ThemeMode) updateThemeMode;

  const Profile({Key? key, required this.updateThemeMode}) : super(key: key);

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // 상수 정의
  static const double _avatarRadius = 50.0;
  static const double _editIconSize = 30.0;
  
  // Firebase 인스턴스 초기화
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 상태 변수들
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

  // 프로필 데이터 로드 메서드
  Future<void> _loadProfileData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final imageUrl = await _getProfileImageUrl(user.uid);
      final postCount = await _getPostCount(user.uid);
      final followerCount = await _getFollowerCount(user.uid);
      final followingCount = await _getFollowingCount(user.uid);
      
      setState(() {
        _profileImageUrl = imageUrl;
        _postCount = postCount;
        _followerCount = followerCount;
        _followingCount = followingCount;
        _isLoading = false;
      });
    }
  }

  // 이미지 선택 및 업로드 메서드
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile image updated successfully.')),
            );
            _loadProfileData();
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $e')),
          );
        }
      }
    }
  }

  // 이미지 압축 메서드
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

  // 이미지 업로드 메서드
  Future<String?> _uploadImage(File file, String? uid) async {
    if (uid != null) {
      final storageRef = _storage.ref().child('user_profile').child('$uid.heic');
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL();
    }
    return null;
  }

  // 프로필 이미지 URL 업데이트 메서드
  Future<void> _updateProfileImageUrl(String? uid, String downloadUrl) async {
    if (uid != null) {
      await _firestore.collection('users').doc(uid).update({'profileImageUrl': downloadUrl});
    }
  }

  // 프로필 이미지 URL 가져오기 메서드
  Future<String?> _getProfileImageUrl(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.data()?['profileImageUrl'];
    } catch (e) {
      print('Failed to get profile image URL: $e');
      return null;
    }
  }

  // 게시물 수 가져오기 메서드
  Future<int> _getPostCount(String uid) async {
    try {
      final postQuery = await _firestore.collection('moments').where('userId', isEqualTo: uid).get();
      return postQuery.size;
    } catch (e) {
      print('Failed to get post count: $e');
      return 0;
    }
  }

  // 팔로워 수 가져오기 메서드
  Future<int> _getFollowerCount(String uid) async {
    try {
      final followerQuery = await _firestore.collection('followers').doc(uid).collection('userFollowers').get();
      return followerQuery.size;
    } catch (e) {
      print('Failed to get follower count: $e');
      return 0;
    }
  }

  // 팔로잉 수 가져오기 메서드
  Future<int> _getFollowingCount(String uid) async {
    try {
      final followingQuery = await _firestore.collection('following').doc(uid).collection('userFollowing').get();
      return followingQuery.size;
    } catch (e) {
      print('Failed to get following count: $e');
      return 0;
    }
  }

  // 사용자 이름 가져오기 메서드
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
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingIndicator() : _buildProfileBody(),
    );
  }

  // 앱바 빌드 메서드
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text("Profile"),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _navigateToSettings(),
        ),
      ],
    );
  }

  // 설정 페이지로 이동하는 메서드
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppSettings(updateThemeMode: widget.updateThemeMode),
      ),
    );
  }

  // 로딩 인디케이터 위젯
  Widget _buildLoadingIndicator() {
    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
        size: 50,
      ),
    );
  }

  // 프로필 본문 빌드 메서드
  Widget _buildProfileBody() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 60),
              _buildProfileImage(),
              const SizedBox(height: 10),
              _buildUserName(),
              const SizedBox(height: 10),
              const Text("Status should be here"),
              const SizedBox(height: 40),
              _buildProfileStats(),
              const SizedBox(height: 20),
              _buildPostsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  // 프로필 이미지 빌드 메서드
  Widget _buildProfileImage() {
    return Stack(
      children: [
        CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: Colors.grey[200],
          child: _profileImageUrl == null
              ? const Icon(Icons.person, size: 50, color: Colors.grey)
              : _buildCachedProfileImage(),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadImage,
            child: Container(
              height: _editIconSize,
              width: _editIconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: const Icon(Icons.edit, color: Colors.black, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  // 캐시된 프로필 이미지 빌드 메서드
  Widget _buildCachedProfileImage() {
    return CachedNetworkImage(
      imageUrl: _profileImageUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: _avatarRadius,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => _buildLoadingIndicator(),
      errorWidget: (context, url, error) => const Icon(
        Icons.person,
        size: 50,
        color: Colors.grey,
      ),
    );
  }

  // 사용자 이름 빌드 메서드
  Widget _buildUserName() {
    return FutureBuilder<String?>(
      future: _getUserName(_auth.currentUser?.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        } else if (snapshot.hasError || !snapshot.hasData) {
          return const Text(
            "Unknown User",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          );
        } else {
          return Text(
            snapshot.data!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          );
        }
      },
    );
  }

  // 프로필 통계 빌드 메서드
  Widget _buildProfileStats() {
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

  // 카테고리 빌드 메서드
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

  // 게시물 그리드 빌드 메서드
  Widget _buildPostsGrid() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('moments')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }
        if (!snapshot.hasData) {
          return const Center(child: Text("No posts available."));
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(5),
          itemCount: snapshot.data!.docs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
          ),
          itemBuilder: (BuildContext context, int index) {
            return _buildPostItem(snapshot.data!.docs[index]);
          },
        );
      },
    );
  }

  // 게시물 아이템 빌드 메서드
  Widget _buildPostItem(QueryDocumentSnapshot post) {
    String imageUrl = post['imageUrl'] ?? '';
    String content = post['content'] ?? '';

    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : const Color(0xFFEEF7FF),
          ),
          child: imageUrl.isNotEmpty
              ? _buildPostImage(imageUrl)
              : _buildPostContent(content),
        ),
      ),
    );
  }

  // 이 메서드는 게시물의 이미지를 표시하는 위젯을 생성합니다.
  Widget _buildPostImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      placeholder: (context, url) => _buildLoadingIndicator(),
      errorWidget: (context, url, error) => const Icon(Icons.error),
      fit: BoxFit.cover,
    );
  }

  // 이 메서드는 게시물의 텍스트 내용을 표시하는 위젯을 생성합니다.
  Widget _buildPostContent(String content) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          content.length > 50 ? '${content.substring(0, 50)}...' : content,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
  
  // 게시물 상세 페이지로 이동
  void _navigateToPostDetail(QueryDocumentSnapshot post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          postId: post.id,
          userId: post['userId'],
          name: post['userName'],
          time: (post['createdAt'] as Timestamp).toDate(),
          img: post['imageUrl'] ?? '',
          content: post['content'] ?? '',
        ),
      ),
    );
  }
}