import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:HolaTalk/views/screens/feeds/write_post.dart'; // WritePostPage를 임포트합니다.
import 'package:HolaTalk/views/widgets/post_item.dart'; // PostItem을 임포트합니다.
import 'package:loading_animation_widget/loading_animation_widget.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('moments').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: isDarkMode ? Colors.white : Colors.blue,
                size: 50,
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (BuildContext context, int index) {
              var post = snapshot.data!.docs[index];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(post['userId']).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return SizedBox.shrink();
                  }

                  var userProfileUrl = userSnapshot.data!['profileImageUrl'] ?? '';

                  return PostItem(
                    postId: post.id,
                    userId: post['userId'],
                    name: post['userName'],
                    time: (post['createdAt'] as Timestamp).toDate(),
                    img: post['imageUrl'] ?? '',
                    content: post['content'],
                    userProfileUrl: userProfileUrl,
                    maxLines: 5, // maxLines를 5로 설정
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
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
      ),
    );
  }
}
