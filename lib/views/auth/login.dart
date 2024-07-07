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
import 'package:HolaTalk/views/main_screen.dart';
import 'package:HolaTalk/widgets/custom_button.dart';
import 'package:HolaTalk/widgets/custom_text_field.dart';
import 'package:HolaTalk/util/extensions.dart';
import 'package:HolaTalk/util/country_data.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:HolaTalk/services/init_fcm.dart';

class Login extends StatefulWidget {
  final Function(ThemeMode) updateThemeMode;

  Login({required this.updateThemeMode});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // 주요 상태 변수 및 서비스 초기화
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FCMService _fcmService = FCMService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _validate = false;
  String _email = '', _password = '', _name = '', _country = '';
  FormMode _formMode = FormMode.LOGIN;

  // 포커스 노드 초기화
  FocusNode _nameFN = FocusNode();
  FocusNode _emailFN = FocusNode();
  FocusNode _passFN = FocusNode();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final loadingColor = isDarkMode ? Colors.white : Colors.blue;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Row(
          children: [
            _buildLottieContainer(screenWidth),
            Expanded(
              child: SingleChildScrollView(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                      child: _buildFormContainer(loadingColor),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Lottie 애니메이션 컨테이너 생성
  Widget _buildLottieContainer(double screenWidth) {
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

  // 메인 폼 컨테이너 생성
  Widget _buildFormContainer(Color loadingColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildAppTitle(),
        SizedBox(height: 70.0),
        _buildForm(),
        if (_formMode == FormMode.LOGIN) _buildForgotPasswordButton(),
        SizedBox(height: 20.0),
        _buildActionButton(loadingColor),
        _buildToggleFormModeButton(),
      ],
    );
  }

  // 앱 제목 위젯
  Widget _buildAppTitle() {
    return Text(
      Constants.appName,
      style: TextStyle(
        fontSize: 40.0,
        fontWeight: FontWeight.bold,
      ),
    ).fadeInList(0, false);
  }

  // 메인 폼 위젯
  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_formMode == FormMode.REGISTER) ...[
            _buildNameField(),
            SizedBox(height: 20.0),
            _buildCountryField(),
            SizedBox(height: 20.0),
          ],
          _buildEmailField(),
          if (_formMode != FormMode.FORGOT_PASSWORD) ...[
            SizedBox(height: 20.0),
            _buildPasswordField(),
          ],
        ],
      ),
    );
  }

  // 이름 입력 필드
  Widget _buildNameField() {
    return CustomTextField(
      enabled: !_isLoading,
      hintText: "Name",
      textInputAction: TextInputAction.next,
      validateFunction: Validations.validateName,
      onSaved: (String? val) => _name = val ?? '',
      focusNode: _nameFN,
      nextFocusNode: _emailFN,
      maxLength: 30,
    );
  }

  // 국가 선택 필드
  Widget _buildCountryField() {
    return TypeAheadFormField(
      textFieldConfiguration: TextFieldConfiguration(
        controller: TextEditingController(text: _country),
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
            style: TextStyle(fontSize: 24),
          ),
          title: Text(suggestion.name),
        );
      },
      onSuggestionSelected: (Country suggestion) {
        setState(() {
          _country = suggestion.name;
        });
      },
      validator: (value) =>
          value!.isEmpty ? 'Please select a country' : null,
      onSaved: (value) => _country = value ?? '',
    );
  }

  // 이메일 입력 필드
  Widget _buildEmailField() {
    return CustomTextField(
      enabled: !_isLoading,
      hintText: "Email",
      textInputAction: TextInputAction.next,
      validateFunction: Validations.validateEmail,
      onSaved: (String? val) => _email = val ?? '',
      focusNode: _emailFN,
      nextFocusNode: _passFN,
    ).fadeInList(1, false);
  }

  // 비밀번호 입력 필드
  Widget _buildPasswordField() {
    return CustomTextField(
      enabled: !_isLoading,
      hintText: "Password",
      textInputAction: TextInputAction.done,
      validateFunction: Validations.validatePassword,
      submitAction: _formMode == FormMode.LOGIN ? _login : _signUp,
      obscureText: true,
      onSaved: (String? val) => _password = val ?? '',
      focusNode: _passFN,
    ).fadeInList(2, false);
  }

  // 비밀번호 찾기 버튼
  Widget _buildForgotPasswordButton() {
    return Column(
      children: [
        SizedBox(height: 10.0),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() => _formMode = FormMode.FORGOT_PASSWORD);
            },
            child: Text('Forgot Password?'),
          ),
        ),
      ],
    ).fadeInList(3, false);
  }

  // 주요 액션 버튼 (로그인/회원가입/비밀번호 재설정)
  Widget _buildActionButton(Color loadingColor) {
    return _isLoading
        ? Center(
            child: LoadingAnimationWidget.staggeredDotsWave(
              color: loadingColor,
              size: 50,
            ),
          )
        : CustomButton(
            label: _getActionButtonLabel(),
            onPressed: _getActionButtonFunction(),
          ).fadeInList(4, false);
  }

  // 액션 버튼 라벨 가져오기
  String _getActionButtonLabel() {
    switch (_formMode) {
      case FormMode.LOGIN:
        return "Login";
      case FormMode.REGISTER:
        return "Register";
      case FormMode.FORGOT_PASSWORD:
        return "Confirm";
    }
  }

  // 액션 버튼 기능 가져오기
  Function() _getActionButtonFunction() {
    switch (_formMode) {
      case FormMode.LOGIN:
        return _login;
      case FormMode.REGISTER:
        return _signUp;
      case FormMode.FORGOT_PASSWORD:
        return _sendPasswordResetEmail;
    }
  }

  // 폼 모드 전환 버튼
  Widget _buildToggleFormModeButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_formMode == FormMode.LOGIN
            ? 'Don\'t have an account?'
            : 'Already have an account?'),
        TextButton(
          onPressed: () {
            setState(() {
              _formMode = _formMode == FormMode.LOGIN
                  ? FormMode.REGISTER
                  : FormMode.LOGIN;
            });
          },
          child: Text(_formMode == FormMode.LOGIN ? 'Register' : 'Login'),
        ),
      ],
    ).fadeInList(5, false);
  }

  // 로그인 기능
  Future<void> _login() async {
    if (_validateAndSaveForm()) {
      setState(() => _isLoading = true);
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        if (userCredential.user?.emailVerified ?? false) {
          // 로그인 성공 처리
          await _firestore.collection('users').doc(userCredential.user?.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
          await _fcmService.initialize();

          Navigate.pushPageReplacement(
            context,
            MainScreen(updateThemeMode: widget.updateThemeMode),
          );
        } else {
          // 이메일 미인증 처리
          _showVerificationDialog(userCredential.user);
        }
      } on FirebaseAuthException catch (e) {
        _showErrorSnackBar(e.message ?? 'Login failed');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // 회원가입 기능
  Future<void> _signUp() async {
    if (_validateAndSaveForm()) {
      setState(() => _isLoading = true);

      String? emailCheck = await Validations.checkEmailInUse(_email);
      if (emailCheck != null) {
        _showErrorSnackBar(emailCheck);
        setState(() => _isLoading = false);
        return;
      }

      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        await _fcmService.initialize();

        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'uid': userCredential.user?.uid,
          'name': _name,
          'email': _email,
          'country': _country,
          'signUpDate': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        await userCredential.user?.sendEmailVerification();

        _showErrorSnackBar('Verification email has been sent. Please check your email.');

        await _auth.signOut();
        
        setState(() => _formMode = FormMode.LOGIN);
      } on FirebaseAuthException catch (e) {
        _showErrorSnackBar(e.code == 'email-already-in-use'
            ? 'This email is already in use.'
            : e.message ?? 'Registration failed');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // 비밀번호 재설정 이메일 전송 기능
  Future<void> _sendPasswordResetEmail() async {
    if (_validateAndSaveForm()) {
      setState(() => _isLoading = true);
      try {
        await _auth.sendPasswordResetEmail(email: _email);
        _showErrorSnackBar('Password reset email sent. Please check your email.');
        setState(() => _formMode = FormMode.LOGIN);
      } on FirebaseAuthException catch (e) {
        _showErrorSnackBar(e.message ?? 'Failed to send password reset email');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // 폼 유효성 검사 및 저장
  bool _validateAndSaveForm() {
    final form = _formKey.currentState!;
    if (form.validate()) {
      form.save();
      return true;
    } else {
      setState(() => _validate = true);
      _showErrorSnackBar('Please fix the errors in red before submitting.');
      return false;
    }
  }

  // 오류 메시지 스낵바 표시
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // 이메일 인증 다이얼로그 표시
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
              _showErrorSnackBar('Verification email has been resent. Please check your email.');
            },
            child: Text('Resend'),
          ),
        ],
      ),
    );
  }
}