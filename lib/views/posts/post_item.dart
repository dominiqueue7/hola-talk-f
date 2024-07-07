import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:HolaTalk/views/posts/post_detail.dart';

class PostItem extends StatelessWidget {
  // 클래스 속성 정의
  final String postId;
  final String userId;
  final String name;
  final DateTime time;
  final String img;
  final String content;
  final String? userProfileUrl;
  final int? maxLines;

  // 생성자
  const PostItem({
    Key? key,
    required this.postId,
    required this.userId,
    required this.name,
    required this.time,
    required this.img,
    required this.content,
    this.userProfileUrl,
    this.maxLines,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () => _navigateToPostDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildUserInfo(context),
            if (img.isNotEmpty) _buildPostImage(context),
            _buildPostContent(),
          ],
        ),
      ),
    );
  }

  // 사용자 정보 위젯 구성
  Widget _buildUserInfo(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        child: _buildProfileImage(),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Text(
        _formatTime(time),
        style: const TextStyle(
          fontWeight: FontWeight.w300,
          fontSize: 11,
        ),
      ),
    );
  }

  // 프로필 이미지 위젯 구성
  Widget _buildProfileImage() {
    if (userProfileUrl != null && userProfileUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: userProfileUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.person, size: 30.0, color: Colors.grey),
      );
    } else {
      return const Icon(Icons.person, size: 30.0, color: Colors.grey);
    }
  }

  // 게시물 이미지 위젯 구성
  Widget _buildPostImage(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: img,
      height: 170,
      width: MediaQuery.of(context).size.width,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blue,
          size: 50,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 170,
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.error, color: Colors.red),
        ),
      ),
    );
  }

  // 게시물 내용 위젯 구성
  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        content,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // 게시물 상세 페이지로 이동
  Future<void> _navigateToPostDetail(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          postId: postId,
          userId: userId,
          name: name,
          time: time,
          img: img,
          content: content,
        ),
      ),
    );
    if (result == true) {
      // TODO: 새로고침 로직을 여기에 추가할 수 있습니다.
    }
  }

  // 시간 포맷 변환
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 1) {
      if (dateTime.year == now.year) {
        return DateFormat('MM/dd HH:mm').format(dateTime); // 올해의 경우 월/일 시:분
      } else {
        return DateFormat('yyyy/MM/dd').format(dateTime); // 올해가 아닌 경우 년/월/일
      }
    } else {
      if (difference.inHours >= 1) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inMinutes} minutes ago';
      }
    }
  }
}