import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:uuid/uuid.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:HolaTalk/util/theme_config.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String recipientId;

  const ChatPage({Key? key, required this.chatId, required this.recipientId}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  late types.User _user;
  types.User? _recipientUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    _user = types.User(id: _currentUser.uid, imageUrl: _currentUser.photoURL);
    await _loadRecipientInfo();
    setState(() => _isLoading = false);
  }

  Future<void> _loadRecipientInfo() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.recipientId).get();
      final userData = userDoc.data();
      if (userData != null && mounted) {
        setState(() {
          _recipientUser = types.User(
            id: widget.recipientId,
            firstName: userData['name'] ?? 'Unknown',
            imageUrl: userData['profileImageUrl'],
          );
        });
      }
    } catch (e) {
      print('Failed to load recipient info: $e');
    }
  }

  Future<void> _markMessagesAsSeen() async {
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    final messagesQuery = await chatDoc.collection('messages')
        .where('author.id', isNotEqualTo: _currentUser.uid)
        .where('status', isEqualTo: types.Status.sent.name)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var message in messagesQuery.docs) {
      batch.update(message.reference, {'status': types.Status.seen.name});
    }
    await batch.commit();
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.photo),
              title: Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _handleImageSelection();
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_file),
              title: Text('File'),
              onTap: () {
                Navigator.pop(context);
                _handleFileSelection();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        mimeType: lookupMimeType(file.path!),
        name: file.name,
        size: file.size,
        uri: file.path!,
        status: types.Status.sending,
      );
      await _addMessage(message);
    }
  }

  Future<void> _handleImageSelection() async {
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
        'isGroup': false,
      });
    } else {
      final participants = chatSnapshot.data()?['participants'] ?? [];
      final isGroup = participants.length > 2;
      await chatDoc.update({
        'participants': FieldValue.arrayUnion([_currentUser.uid, widget.recipientId]),
        'isGroup': isGroup,
      });
    }

    final messageRef = await chatDoc.collection('messages').add(message.toJson());
    await messageRef.update({'status': types.Status.sent.name});
    await _sendPushNotification(message);
  }

  Future<void> _sendPushNotification(types.Message message) async {
    try {
      final accessToken = await _getAccessToken();
      final recipientDoc = await FirebaseFirestore.instance.collection('users').doc(widget.recipientId).get();
      final recipientToken = recipientDoc.data()?['fcmToken'];
      if (recipientToken != null) {
        final response = await http.post(
          Uri.parse('https://fcm.googleapis.com/v1/projects/66487788584/messages:send'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
          body: jsonEncode({
            'message': {
              'token': recipientToken,
              'notification': {
                'title': _user.firstName,
                'body': (message is types.TextMessage) ? message.text : 'You have a new message.',
              },
              'data': {'chatId': widget.chatId},
            }
          }),
        );
        if (response.statusCode != 200) {
          print('Failed to send FCM message: ${response.body}');
        }
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  Future<String> _getAccessToken() async {
    final jsonString = await rootBundle.loadString('assets/data/ciaotalk-213fbb4dd307.json');
    final accountCredentials = ServiceAccountCredentials.fromJson(jsonDecode(jsonString));
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final authClient = await clientViaServiceAccount(accountCredentials, scopes);
    return authClient.credentials.accessToken.data;
  }

  Future<void> _launchInApp(Uri url) async {
    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
      if (!launched) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  void _handleMessageTap(BuildContext _, types.Message message) {
    String? urlString;
    if (message is types.TextMessage) {
      final urlRegExp = RegExp(r"(https?:\/\/[^\s]+)");
      final match = urlRegExp.firstMatch(message.text);
      urlString = match?.group(0);
    } else if (message is types.FileMessage && message.uri.startsWith('http')) {
      urlString = message.uri;
    }

    if (urlString != null) {
      final url = Uri.parse(urlString);
      _launchInApp(url);
    }
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

  Widget _avatarBuilder(types.User user) {
    return user.imageUrl != null
        ? CircleAvatar(backgroundImage: CachedNetworkImageProvider(user.imageUrl!))
        : CircleAvatar(child: Icon(Icons.person), backgroundColor: Colors.grey[300]);
  }

  Widget _customBubbleBuilder(Widget child, {required types.Message message, required bool nextMessageInGroup}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = message.author.id == _user.id
      ? (isDarkMode ? Colors.blue[700] : Colors.blue[300])
      : (isDarkMode ? Colors.grey[700] : Colors.grey[300]);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
      child: Material(
        borderRadius: BorderRadius.circular(1.0),
        elevation: 2.0,
        color: bubbleColor,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
            inputPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            inputMargin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            messageInsetsHorizontal: 20,
            messageInsetsVertical: 7,
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
            inputPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            inputMargin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            messageInsetsHorizontal: 20,
            messageInsetsVertical: 7,
          );

    return Scaffold(
      appBar: AppBar(title: Text(_recipientUser?.firstName ?? 'Chat')),
      body: StreamBuilder<QuerySnapshot>(
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
                'imageUrl': isCurrentUser ? _user.imageUrl : _recipientUser?.imageUrl,
              },
            });
          }).toList();

          WidgetsBinding.instance.addPostFrameCallback((_) => _markMessagesAsSeen());

          return Chat(
            messages: messages,
            onAttachmentPressed: _handleAttachmentPressed,
            onMessageTap: _handleMessageTap,
            onSendPressed: _handleSendPressed,
            showUserAvatars: true,
            showUserNames: true,
            user: _user,
            theme: chatTheme,
            avatarBuilder: _avatarBuilder,
            inputOptions: InputOptions(sendButtonVisibilityMode: SendButtonVisibilityMode.always),
            bubbleBuilder: _customBubbleBuilder,
          );
        },
      ),
    );
  }
}