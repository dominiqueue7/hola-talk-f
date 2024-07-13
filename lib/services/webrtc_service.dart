import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class WebRTCService {
  final String roomId;
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;

  WebRTCService({required this.roomId, required this.userId});

  Future<void> initialize() async {
    print('Initializing WebRTC service');
    // 마이크 권한 요청
    var status = await Permission.microphone.request();
    if (status.isDenied) {
      throw Exception('Microphone permission is required');
    }

    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true});

    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
        {'urls': 'stun:stun4.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(configuration, {});

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      print('ICE candidate: ${candidate.candidate}');
      _sendIceCandidate(candidate);
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state change: $state');
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('Remote track received');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(_remoteStream!);
      }
    };

    _listenForRemoteSDPAndCandidates();
  }

  void _listenForRemoteSDPAndCandidates() {
    _firestore.collection('voiceChatRooms').doc(roomId).collection('webrtc')
        .snapshots().listen((snapshot) {
      snapshot.docChanges.forEach((change) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>;
          final docId = change.doc.id;
          
          if (docId.startsWith('offer_') && data['from'] != userId) {
            _handleRemoteOffer(data);
          } else if (docId.startsWith('answer_') && docId.endsWith('_to_$userId')) {
            _handleRemoteAnswer(data);
          } else if (docId.startsWith('ice_candidate_') && data['to'] == userId) {
            _handleRemoteIceCandidate(data);
          }
        }
      });
    });
  }

  Future<void> _handleRemoteOffer(Map<String, dynamic> data) async {
    print('Handling remote offer');
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['sdp'], data['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _firestore.collection('voiceChatRooms').doc(roomId).collection('webrtc').doc('answer_${userId}_to_${data['from']}').set({
      'type': 'answer',
      'sdp': answer.sdp,
      'from': userId,
      'to': data['from'],
    });
  }

  Future<void> _handleRemoteAnswer(Map<String, dynamic> data) async {
    print('Handling remote answer');
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['sdp'], data['type']),
    );
  }

  Future<void> _handleRemoteIceCandidate(Map<String, dynamic> data) async {
    print('Handling remote ICE candidate');
    final candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    await _firestore.collection('voiceChatRooms').doc(roomId).collection('webrtc').doc('ice_candidate_$userId').set({
      'type': 'ice_candidate',
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      'from': userId,
    });
  }

  Future<void> joinRoom() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await _firestore.collection('voiceChatRooms').doc(roomId).collection('webrtc').doc('offer_$userId').set({
      'type': 'offer',
      'sdp': offer.sdp,
      'from': userId,
    });
  }

  void toggleMute(bool isMuted) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !isMuted;
    });
  }

  void dispose() {
    _localStream?.dispose();
    _peerConnection?.dispose();
    _remoteStreamController.close();
  }
}