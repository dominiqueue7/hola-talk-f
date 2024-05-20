import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:HolaTalk/views/screens/feeds/write_post.dart'; // WritePostPage를 임포트합니다.
import 'package:HolaTalk/views/widgets/post_item.dart'; // PostItem을 임포트합니다. 

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Feeds"),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.filter_list,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('moments').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (BuildContext context, int index) {
              var post = snapshot.data!.docs[index];
              return PostItem(
                postId: post.id,
                userId: post['userId'],
                name: post['userName'],
                time: (post['createdAt'] as Timestamp).toDate(),
                img: post['imageUrl'] ?? '',
                content: post['content'],
                maxLines: 5, // maxLines를 5로 설정
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
