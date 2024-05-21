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
import 'package:HolaTalk/util/data.dart';
import 'package:HolaTalk/views/screens/settings/settings.dart';
import 'package:HolaTalk/views/widgets/animations/animated_button.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  ProfilePage({required this.userId});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static Random random = Random();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _profileImageUrl;
  String? _userName;
  int _postCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    await _loadProfileImage();
    await _loadUserName();
    await _loadPostCount();
  }

  Future<void> _loadProfileImage() async {
    try {
      final ref = _storage.ref().child('user_profile/${widget.userId}.heic');
      final url = await ref.getDownloadURL();
      setState(() {
        _profileImageUrl = url;
      });
    } catch (e) {
      print('Failed to load user profile image: $e');
    }
  }

  Future<void> _loadUserName() async {
    try {
      final userDoc = await _firestore.collection('users').doc(widget.userId).get();
      setState(() {
        _userName = userDoc.data()?['name'];
      });
    } catch (e) {
      print('Failed to load user name: $e');
    }
  }

  Future<void> _loadPostCount() async {
    try {
      final postQuery = await _firestore
          .collection('moments')
          .where('userId', isEqualTo: widget.userId)
          .get();
      setState(() {
        _postCount = postQuery.size;
      });
    } catch (e) {
      print('Failed to load post count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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
                            placeholder: (context, url) => CircularProgressIndicator(),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                _userName ?? "Unknown User",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              SizedBox(height: 3),
              Text(
                "Status should be here",
                style: TextStyle(),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedButton(
                    label: "Message",
                    color: Colors.grey,
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                  SizedBox(width: 10),
                  AnimatedButton(
                    label: "Follow",
                    color: Theme.of(context).colorScheme.secondary,
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ],
              ),
              SizedBox(height: 40),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildCategory("Posts", _postCount),
                    _buildCategory("Followers", random.nextInt(10000)),
                    _buildCategory("Following", random.nextInt(10000)),
                  ],
                ),
              ),
              SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                primary: false,
                padding: EdgeInsets.all(5),
                itemCount: 15,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 200 / 200,
                ),
                itemBuilder: (BuildContext context, int index) {
                  return Padding(
                    padding: EdgeInsets.all(5.0),
                    child: Image.asset(
                      "assets/images/cm${random.nextInt(10)}.jpeg",
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ],
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
