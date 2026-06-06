import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const OrbixApp());
}

class OrbixApp extends StatelessWidget {
  const OrbixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Orbix',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: Color(0xFFF2F2F7),
      ),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.arrow_down_circle_fill), label: '种子'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.graph_square_fill), label: '统计'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.search), label: '搜索'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: '设置'),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0: return const TorrentListScreen();
              case 1: return const Center(child: Text('统计 (开发中)'));
              case 2: return const Center(child: Text('搜索 (开发中)'));
              case 3: return const Center(child: Text('设置 (开发中)'));
              default: return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }
}

class TorrentListScreen extends StatelessWidget {
  const TorrentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const CupertinoSliverNavigationBar(
          largeTitle: Text('种子'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: _buildSpeedCard('上传', '3.27 MB/s', CupertinoIcons.arrow_up_circle_fill, CupertinoColors.activeBlue)),
                const SizedBox(width: 16),
                Expanded(child: _buildSpeedCard('下载', '7.19 MB/s', CupertinoIcons.arrow_down_circle_fill, CupertinoColors.systemTeal)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedCard(String title, String speed, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Text(speed, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CupertinoColors.black)),
        ],
      ),
    );
  }
}
