/*
그룹 참여하기 - 방 입장화면. 
카메라를 통한 큐알 스캔 또는 참여 코드로 그룹에 입장하는 단계의 페이지.
*/
import 'package:flutter/material.dart';
import 'package:project00/platform/hub/screens/mobile_group_input.dart';

class MobileGroupJoin extends StatefulWidget {
  const MobileGroupJoin({super.key});

  @override
  State<MobileGroupJoin> createState() => _MobileGroupJoinState();
}

class _MobileGroupJoinState extends State<MobileGroupJoin> {
  late double screenWidth = MediaQuery.sizeOf(context).width;
  late double screenHeight = MediaQuery.sizeOf(context).height;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(centerTitle: true, title: Text("그룹 참여하기")),
        body: Column(
          children: [
            SizedBox(height: 4),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 23),
              child: Text(
                "테블릿에 표시된 QR 코드를 스캔, 혹은 참여 코드를 입력해 주세요. ",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight(400), fontSize: 25),
              ),
            ),
            SizedBox(height: 26),
            Container(
              height: 310,
              width: 310,
              color: Colors.grey,
              child: Center(child: Text('카메라')),
            ),
            SizedBox(height: 36),
            Text(
              "--------------- OR --------------",
              style: TextStyle(fontWeight: FontWeight(400), fontSize: 25),
            ),
            SizedBox(height: 26),
            Container(
              height: 126,
              width: 342,
              color: Colors.grey,
              child: Center(
                child: Text('_______ _______ _______ _______ _______ ________'),
              ),
            ),
            SizedBox(height: 26),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MobileGroupInput()),
                );
              },
              child: Text('data'),
            ),
          ],
        ),
      ),
    );
  }
}
