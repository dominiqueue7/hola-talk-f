import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:HolaTalk/views/screens/feeds/write_post.dart';
import 'package:HolaTalk/views/widgets/post_item.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 새로고침 함수
  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });
    await _loadAllData();
    setState(() {
      _isLoading = false;
    });
    _animationController.forward();
  }

  // 모든 데이터를 로드하는 함수
  Future<List<Map<String, dynamic>>> _loadAllData() async {
    // 'moments' 컬렉션의 모든 문서를 가져옵니다.
    QuerySnapshot momentSnapshot = await FirebaseFirestore.instance
        .collection('moments')
        .orderBy('createdAt', descending: true)
        .get();

    List<Map<String, dynamic>> allData = [];

    // 각 moment에 대해 사용자 정보를 가져와 결합합니다.
    for (var doc in momentSnapshot.docs) {
      var postData = doc.data() as Map<String, dynamic>;
      var userId = postData['userId'];

      // 사용자 정보를 가져옵니다.
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      var userData = userSnapshot.data() as Map<String, dynamic>?;
      var userProfileUrl = userData?['profileImageUrl'] ?? '';

      // moment 데이터와 사용자 데이터를 결합합니다.
      allData.add({
        ...postData,
        'id': doc.id,
        'userProfileUrl': userProfileUrl,
      });
    }

    return allData;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Feeds"),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(isDarkMode),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  // 본문 위젯 빌드
  Widget _buildBody(bool isDarkMode) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadAllData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator(isDarkMode);
        } else if (snapshot.hasError) {
          return Center(child: Text("An error occurred: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No data available."));
        } else {
          if (_isLoading) {
            _isLoading = false;
            _animationController.forward();
          }
          return AnimatedBuilder(
            animation: _opacityAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: child,
              );
            },
            child: _buildPostList(snapshot.data!),
          );
        }
      },
    );
  }

  // 로딩 인디케이터 위젯
  Widget _buildLoadingIndicator(bool isDarkMode) {
    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: isDarkMode ? Colors.white : Colors.blue,
        size: 50,
      ),
    );
  }

  // 게시물 목록 위젯
  Widget _buildPostList(List<Map<String, dynamic>> posts) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20),
        itemCount: posts.length,
        itemBuilder: (BuildContext context, int index) {
          var post = posts[index];
          return _buildPostItem(post);
        },
      ),
    );
  }

  // 개별 게시물 위젯
  Widget _buildPostItem(Map<String, dynamic> post) {
    return PostItem(
      postId: post['id'],
      userId: post['userId'],
      name: post['userName'],
      time: (post['createdAt'] as Timestamp).toDate(),
      img: post['imageUrl'] ?? '',
      content: post['content'],
      userProfileUrl: post['userProfileUrl'],
      maxLines: 5, // 최대 5줄로 제한
    );
  }

  // 플로팅 액션 버튼 위젯
  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      child: Icon(
        Icons.add,
        color: Colors.white,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WritePostPage()),
        );
      },
    );
  }
}