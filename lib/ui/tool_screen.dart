// tool_screen.dart
import 'package:flutter/material.dart';

import 'about_page.dart';
import 'gallery_page.dart';
import 'station_screen.dart';
import 'gps.dart';
import 'ticket.dart';

class ToolScreen extends StatelessWidget {
  const ToolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 车站大屏卡片放在最上面
            Card(
              child: ListTile(
                leading: const Icon(Icons.tv, size: 32),
                title: const Text('车站大屏'),
                subtitle: const Text('查看车站实时信息'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StationScreen(),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.photo_library, size: 32),
                title: const Text('动车图鉴'),
                subtitle: const Text('精选了一批特殊的列车'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GalleryPage(),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info, size: 32),
                title: const Text('关于软件'),
                subtitle: const Text('这里有一些其他的东西'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutPage()),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.av_timer, size: 32),
                title: const Text('速度计'),
                subtitle: const Text('实验性功能，可能不准'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SpeedometerPage()),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book, size: 32),
                title: const Text('纪念票生成器'),
                subtitle: const Text('实验性功能，当个玩具'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TicketPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
