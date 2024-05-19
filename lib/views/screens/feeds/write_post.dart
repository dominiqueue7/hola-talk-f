import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:HolaTalk/views/widgets/custom_button.dart';
import 'package:HolaTalk/views/widgets/custom_text_field.dart';
import 'package:HolaTalk/util/validations.dart';

class WritePostPage extends StatefulWidget {
  @override
  _WritePostPageState createState() => _WritePostPageState();
}

class _WritePostPageState extends State<WritePostPage> {
  bool loading = false;
  bool validate = false;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String content = '';
  FocusNode contentFN = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
          await _firestore.collection('moments').add({
            'content': content,
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

          showInSnackBar('Moment posted successfully');
          formKey.currentState?.reset();
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
