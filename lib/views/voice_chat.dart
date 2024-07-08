import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 음성 채팅방 목록을 표시하는 StatelessWidget
class VoiceChatRoomList extends StatelessWidget {
  // Firestore 인스턴스 초기화
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Firebase 인증 인스턴스 초기화
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Chat Rooms'),
      ),
      // StreamBuilder를 사용하여 실시간으로 채팅방 목록 업데이트
      body: StreamBuilder<QuerySnapshot>(
        // Firestore의 'voiceChatRooms' 컬렉션을 실시간으로 감시
        stream: _firestore.collection('voiceChatRooms').snapshots(),
        builder: (context, snapshot) {
          // 데이터 로딩 중일 때 로딩 인디케이터 표시
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          // 채팅방이 없을 때 메시지 표시
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No chat rooms available.'));
          }

          // 채팅방 목록을 ListView로 표시
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var room = snapshot.data!.docs[index];
              return _buildRoomListTile(context, room);
            },
          );
        },
      ),
      // 새 채팅방 생성 버튼
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _createNewRoom(context),
      ),
    );
  }

  // 각 채팅방을 표시하는 ListTile 위젯 생성
  Widget _buildRoomListTile(BuildContext context, DocumentSnapshot room) {
    return ListTile(
      title: Text(room['name']),
      subtitle: Text('Participants: ${room['participants'].length}'),
      trailing: Icon(Icons.chevron_right),
      onTap: () => _joinRoom(context, room.id),
    );
  }

  // 새 채팅방 생성 다이얼로그 표시
  void _createNewRoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String roomName = '';
        return AlertDialog(
          title: Text('Create New Chat Room'),
          content: TextField(
            onChanged: (value) => roomName = value,
            decoration: InputDecoration(hintText: "Enter room name"),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Create'),
              onPressed: () async {
                if (roomName.isNotEmpty) {
                  // 새 채팅방 정보를 Firestore에 추가
                  await _firestore.collection('voiceChatRooms').add({
                    'name': roomName,
                    'createdBy': _auth.currentUser!.uid,
                    'createdAt': FieldValue.serverTimestamp(),
                    'participants': [],
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 채팅방 참가 함수 (아직 구현되지 않음)
  void _joinRoom(BuildContext context, String roomId) {
    // TODO: 채팅방 참가 로직 구현
    // 예: 음성 채팅 페이지로 네비게이션
    print('Joining room: $roomId');
    // Navigator.push(context, MaterialPageRoute(builder: (context) => VoiceChatRoom(roomId: roomId)));
  }
}