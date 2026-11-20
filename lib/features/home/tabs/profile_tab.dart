import 'package:flutter/material.dart';

import '../../profile/profile_page.dart';

/// 底部导航的「我的」标签：外壳只负责把选中状态传给页面。
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, this.active = true});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return ProfilePage(active: active);
  }
}
