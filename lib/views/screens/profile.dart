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

class Profile extends StatefulWidget {
  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  static Random random = Random();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    User? user = _auth.currentUser;
    if (user != null) {
      String? imageUrl = await _getProfileImageUrl(user.uid);
      setState(() {
        _profileImageUrl = imageUrl;
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
          await _uploadImage(compressedImage, user?.uid);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile image updated successfully.')));
          _loadProfileImage();  // 프로필 이미지 URL을 다시 불러옵니다.
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

  Future<void> _uploadImage(File file, String? uid) async {
    if (uid != null) {
      final storageRef = _storage.ref().child('user_profile').child('$uid.heic');
      await storageRef.putFile(file);
    }
  }

  Future<String?> _getProfileImageUrl(String uid) async {
    try {
      final storageRef = _storage.ref().child('user_profile').child('$uid.heic');
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Failed to get profile image URL: $e');
      return null;
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
                MaterialPageRoute(builder: (context) => AppSettings()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
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
                              placeholder: (context, url) => CircularProgressIndicator(),
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
                      return CircularProgressIndicator();
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
                      _buildCategory("Posts"),
                      _buildCategory("Friends"),
                      _buildCategory("Groups"),
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
      ),
    );
  }

  Widget _buildCategory(String title) {
    return Column(
      children: <Widget>[
        Text(
          random.nextInt(10000).toString(),
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
