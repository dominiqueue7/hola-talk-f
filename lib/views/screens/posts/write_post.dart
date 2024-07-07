import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:HolaTalk/widgets/custom_button.dart';
import 'package:HolaTalk/widgets/custom_text_field.dart';
import 'package:HolaTalk/util/validations.dart';
import 'package:path_provider/path_provider.dart';

class WritePostPage extends StatefulWidget {
  @override
  _WritePostPageState createState() => _WritePostPageState();
}

class _WritePostPageState extends State<WritePostPage> {
  bool loading = false;
  bool validate = false;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String content = '';
  String? userName;
  String? userCountry;
  FocusNode contentFN = FocusNode();
  File? _imageFile;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        userName = userDoc['name'];
        userCountry = userDoc['country'];
      });
    }
  }

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File? compressedFile = await compressImage(File(pickedFile.path));
      setState(() {
        _imageFile = compressedFile;
      });
    }
  }

  Future<File?> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.heic';

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      format: CompressFormat.heic,
      quality: 50,
    );

    return result != null ? File(result.path) : null;
  }

  Future<String?> uploadImage(File file) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final ref = _storage.ref().child('post_image/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.heic');
        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      }
    } catch (e) {
      print('Error uploading image: $e');
    }
    return null;
  }

  postMoment() async {
    FormState form = formKey.currentState!;
    if (form.validate()) {
      form.save();
      setState(() {
        loading = true;
      });

      try {
        User? user = _auth.currentUser;
        if (user != null) {
          String? imageUrl;
          if (_imageFile != null) {
            imageUrl = await uploadImage(_imageFile!);
          }

          await _firestore.collection('moments').add({
            'content': content,
            'imageUrl': imageUrl,
            'userId': user.uid,
            'userName': userName,
            'userCountry': userCountry,
            'createdAt': FieldValue.serverTimestamp(),
          });

          showInSnackBar('Moment posted successfully');
          formKey.currentState?.reset();
          Navigator.pop(context); // 포스트 후 뒤로 가기
        }
      } catch (e) {
        showInSnackBar('Failed to post moment: $e');
      } finally {
        setState(() {
          loading = false;
        });
      }
    } else {
      setState(() {
        validate = true;
      });
      showInSnackBar('Please fix the errors in red before submitting.');
    }
  }

  void showInSnackBar(String value) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post a Moment'),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            key: formKey,
            child: Column(
              children: <Widget>[
                SizedBox(height: 20.0),
                TextFormField(
                  focusNode: contentFN,
                  onSaved: (value) {
                    content = value ?? '';
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Content is required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null, // Allow multiple lines
                  keyboardType: TextInputType.multiline,
                ),
                SizedBox(height: 20.0),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.photo_camera),
                    iconSize: 30.0,
                    onPressed: pickImage,
                  ),
                ),
                if (_imageFile != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Image.file(
                          _imageFile!,
                          width: 150.0,
                          height: 100.0,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _imageFile = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 20.0),
                loading
                    ? Center(child: CircularProgressIndicator())
                    : CustomButton(
                        label: "Post Moment",
                        onPressed: postMoment,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
