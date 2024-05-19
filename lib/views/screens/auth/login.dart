import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:HolaTalk/util/animations.dart';
import 'package:HolaTalk/util/const.dart';
import 'package:HolaTalk/util/enum.dart';
import 'package:HolaTalk/util/router.dart';
import 'package:HolaTalk/util/validations.dart';
import 'package:HolaTalk/views/screens/main_screen.dart';
import 'package:HolaTalk/views/widgets/custom_button.dart';
import 'package:HolaTalk/views/widgets/custom_text_field.dart';
import 'package:HolaTalk/util/extensions.dart';
import 'package:HolaTalk/util/country_data.dart';

class Login extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool loading = false;
  bool validate = false;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String email = '', password = '', name = '', country = '';
  FocusNode nameFN = FocusNode();
  FocusNode emailFN = FocusNode();
  FocusNode passFN = FocusNode();
  FormMode formMode = FormMode.LOGIN;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  login() async {
    FormState form = formKey.currentState!;
    if (form.validate()) {
      form.save();
      setState(() {
        loading = true;
      });
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // 이메일 인증 확인
        if (userCredential.user?.emailVerified ?? false) {
          // Firestore에 마지막 로그인 날짜 기록
          await _firestore.collection('users').doc(userCredential.user?.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });

          Navigate.pushPageReplacement(context, MainScreen());
        } else {
          // 이메일 인증이 안 되어 있는 경우
          _showVerificationDialog(userCredential.user);
        }
      } on FirebaseAuthException catch (e) {
        showInSnackBar(e.message ?? 'Login failed');
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

  signUp() async {
    FormState form = formKey.currentState!;
    if (form.validate()) {
      form.save();
      setState(() {
        loading = true;
      });

      String? emailCheck = await Validations.checkEmailInUse(email);
      if (emailCheck != null) {
        showInSnackBar(emailCheck);
        setState(() {
          loading = false;
        });
        return;
      }

      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Firestore에 사용자 정보 저장
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'name': name,
          'email': email,
          'country': country,
          'signUpDate': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        // 이메일 인증 메일 보내기
        await userCredential.user?.sendEmailVerification();

        // 사용자에게 이메일 인증을 확인하라는 메시지를 표시하고 로그인 화면으로 이동
        showInSnackBar('Verification email has been sent. Please check your email.');

        // 잠시 대기 후 로그인 화면으로 돌아가기
        await Future.delayed(Duration(seconds: 3));
        setState(() {
          formMode = FormMode.LOGIN;
        });
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          showInSnackBar('This email is already in use.');
        } else {
          showInSnackBar(e.message ?? 'Registration failed');
        }
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

  void _showVerificationDialog(User? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Email not verified'),
        content: Text('Your email is not verified. Would you like to resend the verification email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await user?.sendEmailVerification();
              await _auth.signOut();
              showInSnackBar('Verification email has been resent. Please check your email.');
            },
            child: Text('Resend'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: GestureDetector( // GestureDetector 추가
        onTap: () {
          FocusScope.of(context).unfocus(); // 화면 바깥을 터치하면 키보드 내리기
        },
        child: Container(
          child: Row(
            children: [
              buildLottieContainer(),
              Expanded(
                child: SingleChildScrollView( // 스크롤 가능하게 만드는 위젯 추가
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                        child: buildFormContainer(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  buildLottieContainer() {
    final screenWidth = MediaQuery.of(context).size.width;
    return AnimatedContainer(
      width: screenWidth < 700 ? 0 : screenWidth * 0.5,
      duration: Duration(milliseconds: 500),
      color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
      child: Center(
        child: Lottie.asset(
          AppAnimations.chatAnimation,
          height: 400,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  buildFormContainer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          '${Constants.appName}',
          style: TextStyle(
            fontSize: 40.0,
            fontWeight: FontWeight.bold,
          ),
        ).fadeInList(0, false),
        SizedBox(height: 70.0),
        Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          key: formKey,
          child: buildForm(),
        ),
        Visibility(
          visible: formMode == FormMode.LOGIN,
          child: Column(
            children: [
              SizedBox(height: 10.0),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    formMode = FormMode.FORGOT_PASSWORD;
                    setState(() {});
                  },
                  child: Text('Forgot Password?'),
                ),
              ),
            ],
          ),
        ).fadeInList(3, false),
        SizedBox(height: 20.0),
        buildButton(),
        Visibility(
          visible: formMode == FormMode.LOGIN,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Don\'t have an account?'),
              TextButton(
                onPressed: () {
                  formMode = FormMode.REGISTER;
                  setState(() {});
                },
                child: Text('Register'),
              ),
            ],
          ),
        ).fadeInList(5, false),
        Visibility(
          visible: formMode != FormMode.LOGIN,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account?'),
              TextButton(
                onPressed: () {
                  formMode = FormMode.LOGIN;
                  setState(() {});
                },
                child: Text('Login'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Visibility(
          visible: formMode == FormMode.REGISTER,
          child: Column(
            children: [
              CustomTextField(
                enabled: !loading,
                hintText: "Name",
                textInputAction: TextInputAction.next,
                validateFunction: Validations.validateName,
                onSaved: (String? val) {
                  name = val ?? '';
                },
                focusNode: nameFN,
                nextFocusNode: emailFN,
              ),
              SizedBox(height: 20.0),
              TypeAheadFormField(
                textFieldConfiguration: TextFieldConfiguration(
                  controller: TextEditingController(text: country),
                  decoration: InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(),
                    ),
                  ),
                ),
                suggestionsCallback: (pattern) {
                  return countries.where((country) =>
                      country.name.toLowerCase().contains(pattern.toLowerCase()));
                },
                itemBuilder: (context, Country suggestion) {
                  return ListTile(
                    leading: Text(
                      suggestion.flag,
                      style: TextStyle(fontSize: 24), // Adjust font size as needed
                    ),
                    title: Text(suggestion.name),
                  );
                },
                onSuggestionSelected: (Country suggestion) {
                  setState(() {
                    country = suggestion.name;
                  });
                },
                validator: (value) =>
                    value!.isEmpty ? 'Please select a country' : null,
                onSaved: (value) {
                  country = value ?? '';
                },
              ),
              SizedBox(height: 20.0),
            ],
          ),
        ),
        CustomTextField(
          enabled: !loading,
          hintText: "Email",
          textInputAction: TextInputAction.next,
          validateFunction: Validations.validateEmail,
          onSaved: (String? val) {
            email = val ?? '';
          },
          focusNode: emailFN,
          nextFocusNode: passFN,
        ).fadeInList(1, false),
        Visibility(
          visible: formMode != FormMode.FORGOT_PASSWORD,
          child: Column(
            children: [
              SizedBox(height: 20.0),
              CustomTextField(
                enabled: !loading,
                hintText: "Password",
                textInputAction: TextInputAction.done,
                validateFunction: Validations.validatePassword,
                submitAction: formMode == FormMode.LOGIN ? login : signUp,
                obscureText: true,
                onSaved: (String? val) {
                  password = val ?? '';
                },
                focusNode: passFN,
              ),
            ],
          ),
        ).fadeInList(2, false),
      ],
    );
  }

  buildButton() {
    return loading
        ? Center(child: CircularProgressIndicator())
        : CustomButton(
            label: formMode == FormMode.LOGIN ? "Login" : "Register",
            onPressed: formMode == FormMode.LOGIN ? login : signUp,
          ).fadeInList(4, false);
  }
}
