import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ParticipantSlots extends StatelessWidget {
  final String roomId;
  final String hostId;
  final int maxParticipants = 12;

  ParticipantSlots({required this.roomId, required this.hostId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('voiceChatRooms').doc(roomId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        List<dynamic> participants = snapshot.data!['participants'] ?? [];
        return GridView.builder(
          padding: EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: maxParticipants,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildParticipantSlot(hostId, isHost: true);
            } else if (index < participants.length) {
              return _buildParticipantSlot(participants[index]);
            } else {
              return _buildEmptySlot();
            }
          },
        );
      },
    );
  }

  Widget _buildParticipantSlot(String userId, {bool isHost = false}) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorSlot();
        }

        // 안전하게 문서 데이터에 접근
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final String? profileImageUrl = data?['profileImageUrl'] as String?;
        final String name = data?['name'] as String? ?? 'Unknown';

        return Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty) 
                      ? CachedNetworkImageProvider(profileImageUrl) 
                      : null,
                  child: (profileImageUrl == null || profileImageUrl.isEmpty) 
                      ? Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                if (isHost)
                  Icon(Icons.star, color: Color.fromARGB(255, 254, 233, 48), size: 20),
              ],
            ),
            SizedBox(height: 1),
            Text(name, overflow: TextOverflow.ellipsis),
          ],
        );
      },
    );
  }

  Widget _buildEmptySlot() {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: Icon(Icons.person, color: Colors.grey),
        ),
        SizedBox(height: 4),
        Text('Empty', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildErrorSlot() {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.red),
        ),
        SizedBox(height: 4),
        Text('Error', style: TextStyle(color: Colors.red)),
      ],
    );
  }
}