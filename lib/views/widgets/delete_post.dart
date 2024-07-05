import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeletePost {
  static Future<bool> deletePost(BuildContext context, String postId) async {
    try {
      // Use transaction to delete post and related comments simultaneously
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Delete post
        transaction.delete(FirebaseFirestore.instance.collection('moments').doc(postId));

        // Delete related comments
        final commentSnapshots = await FirebaseFirestore.instance
            .collection('comments')
            .where('postId', isEqualTo: postId)
            .get();
        
        for (var doc in commentSnapshots.docs) {
          transaction.delete(doc.reference);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post deleted successfully.'))
      );
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e'))
      );
      return false;
    }
  }
}