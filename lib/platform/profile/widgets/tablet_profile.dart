import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
      child: hasPhoto ? null : const Icon(Icons.person, color: Colors.white),
    );
  }
}
