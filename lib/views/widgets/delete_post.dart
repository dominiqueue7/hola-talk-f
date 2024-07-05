import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class DeletePost {
  static Future<bool> deletePost(BuildContext context, String postId) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final FirebaseStorage storage = FirebaseStorage.instance;

      // Use transaction to ensure all operations are completed or none are
      bool success = await firestore.runTransaction((transaction) async {
        // Get the post document
        DocumentSnapshot postDoc = await transaction.get(firestore.collection('moments').doc(postId));

        if (!postDoc.exists) {
          throw Exception('Post does not exist');
        }

        Map<String, dynamic> postData = postDoc.data() as Map<String, dynamic>;

        // Delete the image from Firebase Storage if it exists
        if (postData['imageUrl'] != null) {
          await storage.refFromURL(postData['imageUrl']).delete();
        }

        // Delete the post document
        transaction.delete(postDoc.reference);

        // Delete related comments
        QuerySnapshot commentSnapshots = await firestore
            .collection('comments')
            .where('postId', isEqualTo: postId)
            .get();
        
        for (var doc in commentSnapshots.docs) {
          transaction.delete(doc.reference);
        }

        return true;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post deleted successfully.'))
        );
      }

      return success;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e'))
      );
      return false;
    }
  }
}