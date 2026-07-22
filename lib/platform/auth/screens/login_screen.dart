import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 201, 200, 200),
          ),
          child: Column(
            children: [
              TextField(decoration: InputDecoration(hintText: '아이디')),
              TextField(decoration: InputDecoration(hintText: '비밀번호')),
              TextField(decoration: InputDecoration()),
            ],
          ),
        ),
      ),
    );
  }
}
