// tool_screen.dart
import 'package:flutter/material.dart';

import '../tool.dart';
import 'about_page.dart';
import 'gallery_page.dart';
import 'gps.dart';
import 'coach_search_page.dart';
import 'station_screen.dart';

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
                leading: const Icon(Icons.train, size: 32),
                title: const Text('客车查询'),
                subtitle: const Text('查询普速客车'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CoachSearchPage(),
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
                    MaterialPageRoute(
                      builder: (context) => const SpeedometerPage(),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.touch_app_outlined, size: 32),
                title: const Text('友情链接'),
                subtitle: const Text('推荐使用的APP'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MoreAppsPage(),
                    ),
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

class MoreAppsPage extends StatelessWidget {
  const MoreAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('友情链接')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              leading: Image.asset(
                'assets/icon/llt.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              title: const Text('路路通'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Tool.launchBrowser(
                  context,
                  'https://sj.qq.com/appdetail/com.lltskb.lltskb',
                );
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/icon/railre.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              title: const Text('动车组查询'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Tool.launchBrowser(context, 'https://rail.re/');
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/icon/railgo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              title: const Text('RailGo'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Tool.launchBrowser(context, 'https://railgo.dev/android.html');
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/icon/moefactory.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              title: const Text('MoeFactory车箱'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Tool.launchBrowser(context, 'https://sharyou.moefactory.com/');
              },
            ),
            ListTile(
              title: const Text('动车组图鉴网站'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Tool.launchBrowser(context, 'https://china-emu.cn/');
              },
            ),
          ],
        ),
      ),
    );
  }
}
