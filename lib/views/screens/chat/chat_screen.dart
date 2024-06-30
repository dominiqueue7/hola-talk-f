import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:HolaTalk/util/theme_config.dart'; // ThemeConfig 임포트 추가

class ChatPage extends StatefulWidget {
  final String chatId;
  final String recipientId;

  const ChatPage({
    Key? key, 
    required this.chatId, 
    required this.recipientId,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  late types.User _user;
  late types.User _recipientUser;

  @override
  void initState() {
    super.initState();
    _user = types.User(
      id: _currentUser.uid,
      imageUrl: _currentUser.photoURL,
    );
    _loadRecipientInfo();
  }

  Future<void> _loadRecipientInfo() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.recipientId).get();
      if (mounted) {
        setState(() {
          _recipientUser = types.User(
            id: widget.recipientId,
            firstName: userDoc.data()?['name'] ?? 'Unknown',
            imageUrl: userDoc.data()?['profileImageUrl'],
          );
        });
      }
    } catch (e) {
      print('Failed to load recipient info: $e');
    }
  }

  void _markMessagesAsSeen() async {
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    final messagesQuery = await chatDoc.collection('messages')
        .where('author.id', isNotEqualTo: _currentUser.uid)
        .where('status', isEqualTo: types.Status.sent.name)
        .get();

    for (var message in messagesQuery.docs) {
      await message.reference.update({'status': types.Status.seen.name});
    }
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Photo'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('File'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        mimeType: lookupMimeType(result.files.single.path!),
        name: result.files.single.name,
        size: result.files.single.size,
        uri: result.files.single.path!,
        status: types.Status.sending,
      );

      await _addMessage(message);
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final message = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: image.height.toDouble(),
        id: const Uuid().v4(),
        name: result.name,
        size: bytes.length,
        uri: result.path,
        width: image.width.toDouble(),
        status: types.Status.sending,
      );

      await _addMessage(message);
    }
  }

  Future<void> _addMessage(types.Message message) async {
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    final chatSnapshot = await chatDoc.get();
    if (!chatSnapshot.exists) {
      await chatDoc.set({
        'participants': [widget.recipientId, _currentUser.uid],
        'isGroup': false, // 기본값 설정: 처음에는 그룹이 아님
      });
    } else {
      // 'isGroup' 필드 설정
      final participants = chatSnapshot.data()?['participants'] ?? [];
      final isGroup = participants.length > 2;

      if (!(participants.contains(_currentUser.uid))) {
        await chatDoc.update({
          'participants': FieldValue.arrayUnion([_currentUser.uid]),
        });
      }
      if (!(participants.contains(widget.recipientId))) {
        await chatDoc.update({
          'participants': FieldValue.arrayUnion([widget.recipientId]),
        });
      }

      // 참가자 수에 따라 'isGroup' 필드 업데이트
      await chatDoc.update({
        'isGroup': isGroup,
      });
    }

    final messageRef = await chatDoc.collection('messages').add(message.toJson());

    // Firestore에 추가된 후 메시지 상태를 'sent'로 업데이트
    await messageRef.update({'status': types.Status.sent.name});

    // 메시지 추가 후 푸시 알림 전송
    await _sendPushNotification(message);
  }

  Future<ServiceAccountCredentials> _getServiceAccountCredentials() async {
    final jsonString = await rootBundle.loadString('assets/data/ciaotalk-213fbb4dd307.json');
    final json = jsonDecode(jsonString);
    return ServiceAccountCredentials.fromJson(json);
  }

  Future<String> _getAccessToken() async {
    final accountCredentials = await _getServiceAccountCredentials();

    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final authClient = await clientViaServiceAccount(accountCredentials, scopes);
    final accessToken = await authClient.credentials.accessToken.data;
    return accessToken;
  }

  Future<void> _sendPushNotification(types.Message message) async {
    final accessToken = await _getAccessToken();

    final recipientDoc = await FirebaseFirestore.instance.collection('users').doc(widget.recipientId).get();
    final recipientToken = recipientDoc.data()?['fcmToken'];

    if (recipientToken != null) {
      final data = {
        'message': {
          'token': recipientToken,
          'notification': {
            'title': _user.firstName,
            'body': (message is types.TextMessage) ? message.text : 'You have a new message.',
          },
          'data': {
            'chatId': widget.chatId,
          },
        }
      };

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/66487788584/messages:send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        print('Failed to send FCM message: ${response.body}');
      }
    }
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      if (message.uri.startsWith('http')) {
        if (await canLaunch(message.uri)) {
          await launch(message.uri); // URL을 기본 브라우저에서 엽니다.
        } else {
          throw 'Could not launch ${message.uri}';
        }
      } 
    }
  }

  void _handlePreviewDataFetched(types.TextMessage message, types.PreviewData previewData) {
    final updatedMessage = (message as types.TextMessage).copyWith(
      previewData: previewData,
    );
  }

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
      status: types.Status.sending,
    );

    _addMessage(textMessage);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final chatTheme = isDarkMode
      ? DarkChatTheme(
          backgroundColor: ThemeConfig.darkBG,
          inputBackgroundColor: ThemeConfig.darkPrimary,
          inputTextColor: ThemeConfig.lightBG,
          inputTextCursorColor: ThemeConfig.lightBG,
          primaryColor: ThemeConfig.darkAccent,
          secondaryColor: ThemeConfig.darkPrimary,
          inputBorderRadius: BorderRadius.circular(20.0),
          inputTextStyle: TextStyle(fontSize: 16.0, color: ThemeConfig.lightBG),
          inputPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          inputMargin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        )
      : DefaultChatTheme(
          backgroundColor: ThemeConfig.lightBG,
          inputBackgroundColor: Color.fromARGB(255, 237, 237, 237),
          inputTextColor: ThemeConfig.darkBG,
          inputTextCursorColor: ThemeConfig.darkBG,
          primaryColor: ThemeConfig.lightAccent,
          secondaryColor: Color.fromARGB(255, 237, 237, 237),
          inputBorderRadius: BorderRadius.circular(20.0),
          inputTextStyle: TextStyle(fontSize: 16.0, color: ThemeConfig.darkBG),
          inputPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          inputMargin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_recipientUser.firstName ?? 'Loading...'),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats/${widget.chatId}/messages')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: LoadingAnimationWidget.staggeredDotsWave(
                        color: isDarkMode ? Colors.white : Colors.blue,
                        size: 50,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final messages = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final author = data['author'] as Map<String, dynamic>;
                    final isCurrentUser = author['id'] == _user.id;

                    return types.Message.fromJson({
                      ...data,
                      'author': {
                        ...author,
                        'imageUrl': isCurrentUser ? _user.imageUrl : _recipientUser.imageUrl ?? 'assets/default_profile_icon.png',
                      },
                    });
                  }).toList();

                  WidgetsBinding.instance.addPostFrameCallback((_) => _markMessagesAsSeen());

                  return Chat(
                    messages: messages,
                    onAttachmentPressed: _handleAttachmentPressed,
                    onMessageTap: _handleMessageTap,
                    onPreviewDataFetched: _handlePreviewDataFetched,
                    onSendPressed: _handleSendPressed,
                    showUserAvatars: true,
                    showUserNames: true,
                    user: _user,
                    theme: chatTheme,
                    inputOptions: InputOptions(
                      sendButtonVisibilityMode: SendButtonVisibilityMode.always,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}