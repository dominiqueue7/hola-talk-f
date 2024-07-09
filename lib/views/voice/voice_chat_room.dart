import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'participant_slots.dart';
import 'text_chat.dart';

class VoiceChatRoom extends StatelessWidget {
  final String roomId;
  final String roomName;

  VoiceChatRoom({required this.roomId, required this.roomName});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('voiceChatRooms').doc(roomId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final roomData = snapshot.data!.data() as Map<String, dynamic>;
        final isHost = roomData['hostId'] == currentUserId;

        return Scaffold(
          appBar: AppBar(
            title: Text(roomName),
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
                child: ParticipantSlots(roomId: roomId, hostId: roomData['hostId']),
              ),
              Expanded(
                flex: 3,
                child: TextChat(roomId: roomId),
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
    // Delete the room from Firestore
    await FirebaseFirestore.instance.collection('voiceChatRooms').doc(roomId).delete();
  }

  Future<void> _removeParticipant() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('voiceChatRooms').doc(roomId).update({
      'participants': FieldValue.arrayRemove([currentUserId])
    });
  }
}