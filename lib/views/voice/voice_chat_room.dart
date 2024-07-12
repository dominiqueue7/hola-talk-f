import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'participant_slots.dart';
import 'text_chat.dart';

class VoiceChatRoom extends StatefulWidget {
  final String roomId;
  final String roomName;

  VoiceChatRoom({required this.roomId, required this.roomName});

  @override
  _VoiceChatRoomState createState() => _VoiceChatRoomState();
}

class _VoiceChatRoomState extends State<VoiceChatRoom> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser!.uid;
    _joinRoom();
  }

  Future<void> _joinRoom() async {
    await _firestore.collection('voiceChatRooms').doc(widget.roomId).update({
      'participants': FieldValue.arrayUnion([currentUserId])
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('voiceChatRooms').doc(widget.roomId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final roomData = snapshot.data!.data() as Map<String, dynamic>;
        final isHost = roomData['hostId'] == currentUserId;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.roomName),
            actions: [
              IconButton(
                icon: Icon(Icons.exit_to_app),
                onPressed: () => _leaveRoom(context, isHost),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                flex: 2,
                child: ParticipantSlots(roomId: widget.roomId, hostId: roomData['hostId']),
              ),
              Expanded(
                flex: 3,
                child: TextChat(roomId: widget.roomId),
              ),
            ],
          ),
        );
      },
    );
  }

  void _leaveRoom(BuildContext context, bool isHost) async {
    if (isHost) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Close Room'),
          content: Text('If the host leaves, the room will be closed. Are you sure you want to leave?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Leave'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _closeRoom();
        Navigator.of(context).pop(); // Leave the room screen
      }
    } else {
      await _removeParticipant();
      Navigator.of(context).pop(); // Leave the room screen
    }
  }

  Future<void> _closeRoom() async {
    // Firestore에서 방 삭제
    await _firestore.collection('voiceChatRooms').doc(widget.roomId).delete();
  }

  Future<void> _removeParticipant() async {
    await _firestore.collection('voiceChatRooms').doc(widget.roomId).update({
      'participants': FieldValue.arrayRemove([currentUserId])
    });
  }

  @override
  void dispose() {
    _removeParticipant(); // 화면을 나갈 때 참가자 목록에서 제거
    super.dispose();
  }
}