import 'package:flutter/material.dart';

class GroupTopBar extends StatelessWidget {
  final VoidCallback onPressed;
  final String buttonText;

  const GroupTopBar({
    super.key,
    required this.onPressed,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          // 그룹 참여
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.grey[300],
            padding: const EdgeInsets.symmetric(
              horizontal: 40.0,
              vertical: 10.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            buttonText,
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Ink(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: NetworkImage("https://picsum.photos/600/400"),
              fit: BoxFit.cover,
            ),
          ),
          child: InkWell(customBorder: CircleBorder(), onTap: () {}),
        ),
      ],
    );
  }
}
