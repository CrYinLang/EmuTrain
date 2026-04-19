// lib/ui/settings.dart  —  EmuTrain
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../tool.dart';
import '../update.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // ---------- Tab 控制器 ----------
  late TabController _tabController;

  // ---------- 旅途 tab 状态 ----------
  bool _showTrainImage = true;
  bool _showRealTrainMap = true;
  bool _showAutoUpdate = true;
  String _defaultHomePage = '旅途';

  static const String _trainImageKey = 'show_train_image';
  static const String _realTrainMapKey = 'show_real_train_map';
  static const String _defaultHomePageKey = 'default_home_page';
  static const String _showAutoUpdateKey = 'show_auto_update';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showTrainImage = prefs.getBool(_trainImageKey) ?? true;
      _showRealTrainMap = prefs.getBool(_realTrainMapKey) ?? true;
      _showAutoUpdate = prefs.getBool(_showAutoUpdateKey) ?? true;
      _defaultHomePage = prefs.getString(_defaultHomePageKey) ?? '旅途';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  // ==================== 通用 UI 构建 ====================

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) => SwitchListTile(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
    subtitle: Text(
      subtitle,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    ),
    secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
    value: value,
    onChanged: onChanged,
  );

  Widget _buildTile({
    IconData? icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null
          ? Icon(icon, color: theme.colorScheme.primary, size: 24)
          : null,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          : null,
      trailing:
          trailing ??
          (trailingIcon != null
              ? Icon(
                  trailingIcon,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null),
      onTap: onTap,
    );
  }

  // ==================== 数据源卡片 ====================

  Widget _buildEmuDataSourceCard({
    required AppSettings settings,
    required TrainEmuDataSource source,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = settings.dataEmuSource == source;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!isSelected) settings.setEmuDataSource(source);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? primary : onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? primary : onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? primary.withValues(alpha: 0.8)
                      : onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                Icon(Icons.check_circle_rounded, size: 16, color: primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationDataSourceCard({
    required AppSettings settings,
    required TrainStationDataSource source,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = settings.dataStationSource == source;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!isSelected) settings.setStationDataSource(source);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? primary : onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? primary : onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? primary.withValues(alpha: 0.8)
                      : onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                Icon(Icons.check_circle_rounded, size: 16, color: primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 旅途 Tab ====================
  // 主题设置 + 列车显示 + 应用信息

  Widget _buildTravelTab() {
    final settings = Provider.of<AppSettings>(context);
    final isDarkMode = settings.themeMode == ThemeMode.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 主题设置
        Tool.buildSection(
          context: context,
          icon: Icons.color_lens,
          title: '主题设置',
          children: [
            Tool.buildSwitch(
              context: context,
              title: '深色主题',
              subtitle: '启用深色模式',
              icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
              value: isDarkMode,
              onChanged: settings.toggleTheme,
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSection(
          icon: Icons.home,
          title: '主页设置',
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.home_work,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '默认主页',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '设置应用启动时显示的首页',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  DropdownButton<String>(
                    value: _defaultHomePage,
                    items: ['旅途', '搜索']
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              v,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      if (v != null) {
                        setState(() => _defaultHomePage = v);
                        await _saveSetting(_defaultHomePageKey, v);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        // 应用信息
        _buildSection(
          icon: Icons.info,
          title: '应用信息',
          children: [
            _buildTile(
              title: '应用版本 (点击检测更新)',
              subtitle: '${Vars.version} | ${Vars.build} | ${Vars.lastUpdate}',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () => UpdateUI.showAppUpdateFlow(context),
            ),
            const Divider(height: 1),
            _buildTile(
              title: '开发者',
              subtitle: 'Cr.YinLang',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () => Tool.showDeveloperDialog(context),
            ),
          ],
        ),

        // 应用设置
        _buildSection(
          icon: Icons.info,
          title: '应用设置',
          children: [
            _buildTile(
              title: '车站数据版本',
              subtitle: 'V${Vars.stationBuild}',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () => UpdateUI.showStationUpdateFlow(context),
            ),
            const Divider(height: 1),
            _buildTile(
              title: '动车组配属数据版本',
              subtitle: 'V${Vars.trainBuild}',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () => UpdateUI.showTrainUpdateFlow(context),
            ),
            const Divider(height: 1),
            _buildTile(
              title: '普速客车配属数据版本',
              subtitle: 'V${Vars.coachTrainBuild}',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () => UpdateUI.showCoachTrainUpdateFlow(context),
            ),
            const Divider(height: 1),
            Tool.buildSwitch(
              context: context,
              title: '自动检测更新',
              subtitle: '在有更新时自动弹出',
              icon: Icons.browser_updated_sharp,
              value: _showAutoUpdate,
              onChanged: (v) async {
                setState(() => _showAutoUpdate = v);
                await _saveSetting(_showAutoUpdateKey, v);
              },
            ),
          ],
        ),
      ],
    );
  }

  // ==================== 查询 Tab ====================

  Widget _buildSearchTab(AppSettings settings) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 图标显示设置
        _buildSection(
          icon: Icons.photo_library,
          title: '图标显示设置 (查询)',
          children: [
            _buildSwitch(
              title: '显示动车组图标',
              subtitle: '在查询结果中显示动车组图标',
              icon: Icons.image,
              value: settings.showTrainIcons,
              onChanged: settings.toggleTrainIcons,
            ),
            const Divider(height: 1),
            _buildSwitch(
              title: '显示路局图标',
              subtitle: '在查询结果中显示路局图标',
              icon: Icons.account_balance,
              value: settings.showBureauIcons,
              onChanged: settings.toggleBureauIcons,
            ),
          ],
        ),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildStationDataSourceCard(
                  settings: settings,
                  source: TrainStationDataSource.moeFactory,
                  title: 'MoeFactory',
                  description: '有里程查看',
                  icon: Icons.cloud_upload,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStationDataSourceCard(
                  settings: settings,
                  source: TrainStationDataSource.ctrip,
                  title: '某大厂数据源',
                  description: '没有里程查看',
                  icon: Icons.factory,
                ),
              ),
            ],
          ),
        ),
        // 数据源设置
        _buildSection(
          icon: Icons.storage,
          title: '数据源设置  (查询)',
          children: [
            // 车次数据源
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                '车次数据源',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Tool.buildTrainDataSourceCard(
                      context: context,
                      settings: settings,
                      source: TrainDataSource.railRe,
                      title: 'Rail.re',
                      description: '第三方数据源',
                      icon: Icons.cloud_upload,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Tool.buildTrainDataSourceCard(
                      context: context,
                      settings: settings,
                      source: TrainDataSource.official12306,
                      title: '12306',
                      description: '官方数据源',
                      icon: Icons.train,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                settings.dataSourceDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 车号数据源
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                '车号数据源',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildEmuDataSourceCard(
                      settings: settings,
                      source: TrainEmuDataSource.railRe,
                      title: 'Rail.re',
                      description: '第三方数据源',
                      icon: Icons.cloud_upload,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEmuDataSourceCard(
                      settings: settings,
                      source: TrainEmuDataSource.moeFactory,
                      title: 'MoeFactory',
                      description: '第三方数据源',
                      icon: Icons.factory,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                settings.dataEmuSourceDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),

        // 列车显示设置
        Tool.buildSection(
          context: context,
          icon: Icons.train,
          title: '列车显示设置 (旅途)',
          children: [
            Tool.buildSwitch(
              context: context,
              title: '显示列车图片',
              subtitle: '在旅途详情中显示列车图片',
              icon: Icons.photo_camera,
              value: _showTrainImage,
              onChanged: (v) async {
                setState(() => _showTrainImage = v);
                await _saveSetting(_trainImageKey, v);
              },
            ),
            const Divider(height: 1),
            Tool.buildSwitch(
              context: context,
              title: '显示相似走向图',
              subtitle: '显示更相似列车走行走向图（网络）',
              icon: Icons.map,
              value: _showRealTrainMap,
              onChanged: (v) async {
                setState(() => _showRealTrainMap = v);
                await _saveSetting(_realTrainMapKey, v);
              },
            ),
          ],
        ),
      ],
    );
  }

  // ==================== 根 build ====================

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: '通用设置'),
            Tab(icon: Icon(Icons.directions_railway), text: '功能设置'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildTravelTab(), _buildSearchTab(settings)],
          ),
        ),
      ],
    );
  }
}
