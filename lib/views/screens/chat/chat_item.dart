import 'package:flutter/material.dart';
import 'package:HolaTalk/views/screens/chat/chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ChatItem 위젯: 채팅 목록의 각 항목을 표시하는 위젯
class ChatItem extends StatelessWidget {
  // 상수 정의
  static const double _avatarRadius = 25.0;
  static const double _onlineIndicatorSize = 11.0;
  static const double _onlineIndicatorInnerSize = 7.0;

  // 필요한 데이터 필드
  final String chatId;
  final String dp;  // 프로필 이미지 URL
  final String name;
  final String time;
  final String msg;
  final bool isOnline;
  final int counter;  // 읽지 않은 메시지 수
  final String recipientId;

  /// ChatItem 생성자
  const ChatItem({
    Key? key,
    required this.chatId,
    required this.dp,
    required this.name,
    required this.time,
    required this.msg,
    required this.isOnline,
    required this.counter,
    required this.recipientId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _buildAvatar(),
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
        onTap: () => _navigateToChatPage(context),
      ),
    );
  }

  /// 아바타 이미지와 온라인 상태 표시기를 포함한 위젯 생성
  Widget _buildAvatar() {
    return Stack(
      children: <Widget>[
        _buildAvatarImage(),
        _buildOnlineIndicator(),
      ],
    );
  }

  /// 사용자 프로필 이미지 또는 기본 아이콘을 표시하는 위젯 생성
  Widget _buildAvatarImage() {
    return dp.isNotEmpty
        ? CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(dp),
            radius: _avatarRadius,
          )
        : CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Colors.grey),
            radius: _avatarRadius,
          );
  }

  /// 사용자의 온라인/오프라인 상태를 나타내는 표시기 위젯 생성
  Widget _buildOnlineIndicator() {
    return Positioned(
      bottom: 0.0,
      left: 6.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_onlineIndicatorSize / 2),
        ),
        height: _onlineIndicatorSize,
        width: _onlineIndicatorSize,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: isOnline ? Colors.greenAccent : Colors.grey,
              borderRadius: BorderRadius.circular(_onlineIndicatorInnerSize / 2),
            ),
            height: _onlineIndicatorInnerSize,
            width: _onlineIndicatorInnerSize,
          ),
        ),
      ),
    );
  }

  /// 채팅방 이름 또는 상대방 이름을 표시하는 위젯 생성
  Widget _buildTitle() {
    return Text(
      name,
      maxLines: 1,
      style: TextStyle(fontWeight: FontWeight.bold),
    );
  }

  /// 최근 메시지 내용을 표시하는 위젯 생성
  Widget _buildSubtitle() {
    return Text(
      msg,
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }

  /// 시간 및 읽지 않은 메시지 수를 표시하는 trailing 위젯 생성
  Widget _buildTrailing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        SizedBox(height: 10),
        _buildTimeStamp(),
        SizedBox(height: 5),
        _buildMessageCounter(),
      ],
    );
  }

  /// 최근 메시지 시간을 표시하는 위젯 생성
  Widget _buildTimeStamp() {
    return Text(
      time,
      style: TextStyle(
        fontWeight: FontWeight.w300,
        fontSize: 11,
      ),
    );
  }

  /// 읽지 않은 메시지 수를 표시하는 위젯 생성
  Widget _buildMessageCounter() {
    return counter == 0
        ? SizedBox()
        : Container(
            padding: EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            constraints: BoxConstraints(
              minWidth: 11,
              minHeight: 11,
            ),
            child: Padding(
              padding: EdgeInsets.only(top: 1, left: 5, right: 5),
              child: Text(
                counter.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
  }

  /// 채팅 페이지로 이동하는 함수
  void _navigateToChatPage(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (BuildContext context) => ChatPage(chatId: chatId, recipientId: recipientId),
      ),
    );
  }
}