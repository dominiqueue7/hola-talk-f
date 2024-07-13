import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'participant_slots.dart';
import 'text_chat.dart';
import 'package:HolaTalk/services/webrtc_service.dart';

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
  late WebRTCService _webRTCService;
  bool _isMuted = false;
  final _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser!.uid;
    _webRTCService = WebRTCService(roomId: widget.roomId, userId: currentUserId);
    _initializeRoom();
  }

  Future<void> _initializeRoom() async {
    try {
      await _joinRoom();
      await _webRTCService.initialize();
      await _webRTCService.joinRoom();
      await _remoteRenderer.initialize();
      
      _webRTCService.remoteStream.listen((stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      });
    } catch (e) {
      print('Error initializing room: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize voice chat. Please check your microphone permissions.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _joinRoom() async {
    await _firestore.collection('voiceChatRooms').doc(widget.roomId).update({
      'participants': FieldValue.arrayUnion([currentUserId])
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _webRTCService.toggleMute(_isMuted);
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
                icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                onPressed: _toggleMute,
              ),
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
                flex: 1,
                child: RTCVideoView(_remoteRenderer, mirror: true),
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
    // 방 문서의 참조를 가져옵니다.
    DocumentReference roomRef = _firestore.collection('voiceChatRooms').doc(widget.roomId);

    // 'messages' 하위 컬렉션의 모든 문서를 삭제합니다.
    QuerySnapshot messagesSnapshot = await roomRef.collection('messages').get();
    for (DocumentSnapshot doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // 'webrtc' 하위 컬렉션의 모든 문서를 삭제합니다.
    QuerySnapshot webrtcSnapshot = await roomRef.collection('webrtc').get();
    for (DocumentSnapshot doc in webrtcSnapshot.docs) {
      await doc.reference.delete();
    }

    // 마지막으로 방 문서 자체를 삭제합니다.
    await roomRef.delete();

    print('Room and all its contents have been deleted successfully.');
  }
  
  Future<void> _removeParticipant() async {
    await _firestore.collection('voiceChatRooms').doc(widget.roomId).update({
      'participants': FieldValue.arrayRemove([currentUserId])
    });
  }

  @override
  void dispose() {
    _removeParticipant();
    _webRTCService.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }
}