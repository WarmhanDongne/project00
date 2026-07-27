import 'package:flutter/material.dart';

class HomeMobile extends StatefulWidget {
  const HomeMobile({super.key});

  @override
  State<HomeMobile> createState() => _HomeMobileState();
}

class _HomeMobileState extends State<HomeMobile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),

        child: Column(
          children: [
            SizedBox(height: 10),

            Row(
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
                  onPressed: () {
                    print("그룹에 참여하기"); // 나중에 클릭 시 그룹 참여하기 카메라 큐알 페이지로 넘기기
                  },
                  child: Text(
                    "그룹 참여",
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
                  child: InkWell(
                    customBorder: CircleBorder(),
                    onTap: () {
                      print('click');
                    },
                  ),
                ),
              ],
            ),
            Column(
              // 보유 중인 게임
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Text(
                  "보유 중인 게임",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    "https://picsum.photos/200/300",
                    width: 115,
                    height: 150,
                    fit: BoxFit.cover, // 지정된 비율에 맞도록 설정
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
