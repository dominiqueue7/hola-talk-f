import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:HolaTalk/views/voice/create_chat_room.dart';
import 'package:HolaTalk/views/voice/voice_chat_room.dart';

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
        onPressed: () async {
          String? newRoomId = await createNewRoom(context);
          if (newRoomId != null) {
            _joinRoom(context, newRoomId);
          }
        },
      ),
    );
  }

  // 각 채팅방을 표시하는 ListTile 위젯 생성
  Widget _buildRoomListTile(BuildContext context, DocumentSnapshot room) {
    return ListTile(
      title: Text(room['name']),
      subtitle: Text('Participants: ${(room['participants'] as List).length}'),
      trailing: Icon(Icons.chevron_right),
      onTap: () => _joinRoom(context, room.id),
    );
  }

  void _joinRoom(BuildContext context, String roomId) async {
    // 방 정보를 가져옵니다.
    DocumentSnapshot roomSnapshot = await _firestore.collection('voiceChatRooms').doc(roomId).get();
    
    if (roomSnapshot.exists) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceChatRoom(
            roomId: roomId,
            roomName: roomSnapshot['name'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This room no longer exists.')),
      );
    }
  }
}