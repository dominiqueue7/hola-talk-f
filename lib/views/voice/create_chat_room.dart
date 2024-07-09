import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 새 채팅방 생성 함수
Future<String?> createNewRoom(BuildContext context) async {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? createdRoomId;

  await showDialog(
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
                final currentUserId = _auth.currentUser!.uid;
                // 새 채팅방 정보를 Firestore에 추가
                DocumentReference docRef = await _firestore.collection('voiceChatRooms').add({
                  'name': roomName,
                  'hostId': currentUserId, // 방장 ID 추가
                  'createdBy': currentUserId,
                  'createdAt': FieldValue.serverTimestamp(),
                  'participants': [currentUserId], // 방 생성자를 참가자 목록에 추가
                });
                createdRoomId = docRef.id;
                Navigator.pop(context);
              }
            },
          ),
        ],
      );
    },
  );

  return createdRoomId;
}