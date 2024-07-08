import 'package:flutter/material.dart';
import 'participant_slots.dart';
import 'text_chat.dart';

class VoiceChatRoom extends StatelessWidget {
  final String roomId;
  final String roomName;

  VoiceChatRoom({required this.roomId, required this.roomName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(roomName),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () {
              // TODO: Implement leave room functionality
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: ParticipantSlots(roomId: roomId),
          ),
          Expanded(
            flex: 3,
            child: TextChat(roomId: roomId),
          ),
        ],
      ),
    );
  }
}