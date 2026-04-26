// lib/main.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journey_provider.dart';
import 'speed_service.dart';
import 'ui/gallery_page.dart';
import 'ui/coach_search_page.dart';
import 'ui/emu_search_page.dart';
import 'ui/settings.dart';
import 'ui/tool_screen.dart';
import 'ui/travel_screen.dart';
import 'update.dart';

// ==================== 应用常量 ====================
class Vars {
  static const String lastUpdate = '26-04-18-11-30';
  static const String version = '1.2.1.1';
  static const String build = '1211';
  static const String urlServer = 'version';
  static const String commandServer = 'remote';
  static const String stationData = 'assets/stations';
  static const String trainData = 'assets/train';
  static const String coachTrainData = 'assets/coach';
  static const String locoData = 'assets/loco';

  static String defaultStationBuild = '4';
  static String defaultTrainBuild = '7';
  static String defaultCoachTrainBuild = '4';
  static String defaultLocoBuild = '1';

  // ---------- stationBuild ----------
  static String _stationBuild = defaultStationBuild;
  static bool _isStationBuildInitialized = false;

  static String get stationBuild => _stationBuild;

  static Future<void> initStationBuild() async {
    if (_isStationBuildInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _stationBuild = prefs.getString('stationBuild') ?? defaultStationBuild;
    _isStationBuildInitialized = true;
  }

  static Future<void> setStationBuild(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stationBuild', value);
    _stationBuild = value;
    _isStationBuildInitialized = true;
  }

  // ---------- trainBuild ----------
  static String _trainBuild = defaultTrainBuild;
  static bool _isTrainBuildInitialized = false;

  static String get trainBuild => _trainBuild;

  static Future<void> initTrainBuild() async {
    if (_isTrainBuildInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _trainBuild = prefs.getString('trainBuild') ?? defaultTrainBuild;
    _isTrainBuildInitialized = true;
  }

  static Future<void> setTrainBuild(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trainBuild', value);
    _trainBuild = value;
    _isTrainBuildInitialized = true;
  }

  // ---------- coachTrainBuild ----------
  static String _coachTrainBuild = defaultCoachTrainBuild;
  static bool _isCoachTrainBuildInitialized = false;

  static String get coachTrainBuild => _coachTrainBuild;

  static Future<void> initCoachTrainBuild() async {
    if (_isCoachTrainBuildInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _coachTrainBuild =
        prefs.getString('coachTrainBuild') ?? defaultCoachTrainBuild;
    _isCoachTrainBuildInitialized = true;
  }

  static Future<void> setCoachTrainBuild(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('coachTrainBuild', value);
    _coachTrainBuild = value;
    _isCoachTrainBuildInitialized = true;
  }

  // ---------- locoBuild ----------
  static String _locoBuild = defaultLocoBuild;
  static bool _isLocoBuildInitialized = false;

  static String get locoBuild => _locoBuild;

  static Future<void> initLocoBuild() async {
    if (_isLocoBuildInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _locoBuild = prefs.getString('locoBuild') ?? defaultLocoBuild;
    _isLocoBuildInitialized = true;
  }

  static Future<void> setLocoBuild(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locoBuild', value);
    _locoBuild = value;
    _isLocoBuildInitialized = true;
  }

  // ---------- 网络 ----------
  static Future<Map<String, dynamic>?> fetchVersionInfo() async {
    final response = await http
        .get(
          Uri.parse(
            'https://gitee.com/CrYinLang/EmuTrain/raw/master/$urlServer.json',
          ),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) return json.decode(response.body);
    return null;
  }

  static Future<Map<String, dynamic>?> fetchCommand() async {
    final response = await http
        .get(
          Uri.parse(
            'https://gitee.com/CrYinLang/EmuTrain/raw/master/$commandServer.json',
          ),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty)
        return data[0] as Map<String, dynamic>;
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }
}

// ==================== 数据文件帮助类 ====================

class DataFileHelper {
  static Future<List<CoachRecord>> loadCoaches() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/coach.json');
    String? jsonString;
    if (await file.exists()) {
      try {
        jsonString = await file.readAsString();
        json.decode(jsonString); // 验证 JSON 合法
        debugPrint('[DataFileHelper] 已加载下载版本 coach.json');
      } catch (e) {
        debugPrint('[DataFileHelper] coach.json 损坏，回退 assets: $e');
        jsonString = null;
      }
    }
    jsonString ??= await rootBundle.loadString('assets/coach.json');
    debugPrint('[DataFileHelper] 已加载 assets/coach.json');

    final Map<String, dynamic> dataJson = json.decode(jsonString);
    final List<CoachRecord> result = [];
    for (final model in dataJson.keys) {
      for (final record in dataJson[model]) {
        result.add(CoachRecord.fromJson(Map<String, dynamic>.from(record)));
      }
    }
    return result;
  }

  /// 读取车站数据（List 结构）
  static Future<List<dynamic>> loadStations() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/stations.json');

    if (await file.exists()) {
      try {
        final jsonString = await file.readAsString();
        final data = json.decode(jsonString);
        if (data is List) {
          debugPrint('[DataFileHelper] 已加载下载版本 stations.json');
          return data;
        }
        debugPrint('[DataFileHelper] stations.json 格式异常，回退 assets');
      } catch (e) {
        debugPrint('[DataFileHelper] stations.json 损坏，回退 assets: $e');
      }
    }

    final jsonString = await rootBundle.loadString('assets/stations.json');
    debugPrint('[DataFileHelper] 已加载 assets/stations.json');
    return json.decode(jsonString) as List<dynamic>;
  }

  /// 读取列车数据（Map 结构），并展开为带 type_code 的 List
  static Future<List<Map<String, dynamic>>> loadTrains() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/train.json');

    String? jsonString;

    if (await file.exists()) {
      try {
        jsonString = await file.readAsString();
        json.decode(jsonString); // 验证 JSON 合法
        debugPrint('[DataFileHelper] 已加载下载版本 train.json');
      } catch (e) {
        debugPrint('[DataFileHelper] train.json 损坏，回退 assets: $e');
        jsonString = null;
      }
    }

    jsonString ??= await rootBundle.loadString('assets/train.json');

    final Map<String, dynamic> dataJson = json.decode(jsonString);
    final List<Map<String, dynamic>> result = [];
    for (var model in dataJson.keys) {
      for (var record in dataJson[model]) {
        final r = Map<String, dynamic>.from(record);
        r['type_code'] = model;
        result.add(r);
      }
    }
    return result;
  }

  static Future<List<Map<String, dynamic>>> loadLocos() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/loco.json');

    String? jsonString;

    if (await file.exists()) {
      try {
        jsonString = await file.readAsString();
        json.decode(jsonString); // 验证 JSON 合法
        debugPrint('[DataFileHelper] 已加载下载版本 loco.json');
      } catch (e) {
        debugPrint('[DataFileHelper] loco.json 损坏，回退 assets: $e');
        jsonString = null;
      }
    }

    jsonString ??= await rootBundle.loadString('assets/loco.json');
    debugPrint('[DataFileHelper] 已加载 assets/loco.json');

    final Map<String, dynamic> dataJson = json.decode(jsonString);
    final List<Map<String, dynamic>> result = [];
    for (final model in dataJson.keys) {
      for (final record in dataJson[model]) {
        result.add({
          'model': model,
          'number': (record['车组号'] ?? '').toString(),
          'depot': (record['配属段'] ?? '').toString(),
        });
      }
    }
    return result;
  }
}

// ==================== 数据源枚举 ====================

/// 车次查询数据源
enum TrainStationDataSource { moeFactory, ctrip }

/// 车次查询数据源
enum TrainDataSource { railRe, railGo, official12306 }

/// 车号/交路查询数据源
enum TrainEmuDataSource { railRe, railGo, moeFactory }

// ==================== 设置管理 ====================
class AppSettings extends ChangeNotifier {
  // ---------- 版本信息 ----------
  static const String version = Vars.version;
  static const String build = Vars.build;
  static const String lastUpdate = Vars.lastUpdate;

  // ---------- 主题 ----------
  ThemeMode _themeMode = ThemeMode.dark;
  bool _midnightMode = false;
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;

  bool get midnightMode => _midnightMode;

  bool get isLoading => _isLoading;

  // ---------- 图标显示 ----------
  bool _showTrainIcons = true;
  bool _showBureauIcons = true;

  bool get showTrainIcons => _showTrainIcons;

  bool get showBureauIcons => _showBureauIcons;

  // ---------- 自动更新 ----------
  bool _showAutoUpdate = true;

  bool get showAutoUpdate => _showAutoUpdate;

  // ---------- 远程控制 ----------
  String? _commandMessage;
  bool _showRemoteMessages = true;

  String? get commandMessage => _commandMessage;

  bool get showRemoteMessages => _showRemoteMessages;

  // ---------- 数据源 ----------
  TrainDataSource _dataSource = TrainDataSource.railRe;
  TrainEmuDataSource _dataEmuSource = TrainEmuDataSource.railRe;
  TrainStationDataSource _dataStationSource = TrainStationDataSource.moeFactory;

  TrainDataSource get dataSource => _dataSource;

  TrainEmuDataSource get dataEmuSource => _dataEmuSource;

  TrainStationDataSource get dataStationSource => _dataStationSource;

  String get dataSourceDisplayName {
    switch (_dataSource) {
      case TrainDataSource.railRe:
        return 'Rail.re';
      case TrainDataSource.railGo:
        return 'RailGo';
      case TrainDataSource.official12306:
        return '12306官方';
    }
  }

  String get dataEmuSourceDisplayName {
    switch (_dataEmuSource) {
      case TrainEmuDataSource.railRe:
        return 'Rail.re';
      case TrainEmuDataSource.railGo:
        return 'RailGo';
      case TrainEmuDataSource.moeFactory:
        return 'MoeFactory';
    }
  }

  String get dataSourceDescription {
    switch (_dataSource) {
      case TrainDataSource.railRe:
        return '第三方API，提供更丰富的数据，但可能缺少部分数据';
      case TrainDataSource.railGo:
        return '第三方API，提供更丰富的数据，但可能缺少部分数据';
      case TrainDataSource.official12306:
        return '官方数据源，最准确可靠，但不显示重连，城际等';
    }
  }

  String get dataEmuSourceDescription => '第三方数据源，提供更全面的车型信息';

  Future<void> setDataSource(TrainDataSource source) async {
    if (_dataSource == source) return;
    _dataSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dataSource', source.index);
    notifyListeners();
  }

  Future<void> setEmuDataSource(TrainEmuDataSource source) async {
    if (_dataEmuSource == source) return;
    _dataEmuSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dataEmuSource', source.index);
    notifyListeners();
  }

  Future<void> setStationDataSource(TrainStationDataSource source) async {
    if (_dataStationSource == source) return;
    _dataStationSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dataStationSource', source.index);
    notifyListeners();
  }

  // ==================== 初始化 ====================
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeMode = (prefs.getBool('isDark') ?? true)
          ? ThemeMode.dark
          : ThemeMode.light;
      _midnightMode = prefs.getBool('midnightMode') ?? false;
      _showTrainIcons = prefs.getBool('showTrainIcons') ?? true;
      _showBureauIcons = prefs.getBool('showBureauIcons') ?? true;
      _showAutoUpdate = prefs.getBool('showAutoUpdate') ?? true;
      _showRemoteMessages = prefs.getBool('showRemoteMessages') ?? true;

      // 数据源
      final dataSourceIndex = prefs.getInt('dataSource') ?? 0;
      _dataSource = TrainDataSource
          .values[dataSourceIndex.clamp(0, TrainDataSource.values.length - 1)];

      final dataEmuSourceIndex = prefs.getInt('dataEmuSource') ?? 0;
      _dataEmuSource =
          TrainEmuDataSource.values[dataEmuSourceIndex.clamp(
            0,
            TrainEmuDataSource.values.length - 1,
          )];

      final dataStationSourceIndex = prefs.getInt('dataStationSource') ?? 0;
      _dataStationSource =
          TrainStationDataSource.values[dataStationSourceIndex.clamp(
            0,
            TrainStationDataSource.values.length - 1,
          )];
    } catch (_) {
      _setDefaultValues();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setDefaultValues() {
    _themeMode = ThemeMode.dark;
    _midnightMode = false;
    _showTrainIcons = true;
    _showBureauIcons = true;
    _showAutoUpdate = true;
    _dataSource = TrainDataSource.railRe;
    _dataEmuSource = TrainEmuDataSource.railRe;
  }

  // ==================== 主题 ====================
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    notifyListeners();
  }

  Future<void> toggleMidnightMode(bool value) async {
    _midnightMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('midnightMode', value);
    notifyListeners();
  }

  // ==================== 图标显示 ====================
  Future<void> toggleTrainIcons(bool value) async {
    _showTrainIcons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTrainIcons', value);
    notifyListeners();
  }

  Future<void> toggleBureauIcons(bool value) async {
    _showBureauIcons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showBureauIcons', value);
    notifyListeners();
  }

  // ==================== 自动更新 ====================
  Future<void> toggleAutoUpdate(bool value) async {
    _showAutoUpdate = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showAutoUpdate', value);
    notifyListeners();
  }

  // ==================== 远程控制 ====================
  Future<void> checkRemoteCommand() async {
    final command = await Vars.fetchCommand();
    if (command == null) return;

    final message = command['message']?.toString();
    if (message != null && message.isNotEmpty && _showRemoteMessages) {
      _commandMessage = message;
      notifyListeners();
    }

    final minVersion = command['minVersion']?.toString() ?? Vars.build;
    if (double.parse(minVersion) >= double.parse(Vars.build)) exit(0);

    final operation = command['operation']?.toString() ?? '';
    if (operation.isNotEmpty) _handleOperation(operation);
  }

  void _handleOperation(String operation) {
    switch (operation) {
      case 'exit':
        Future.delayed(const Duration(milliseconds: 100), () => exit(0));
        break;
    }
  }

  void clearCommandMessage() {
    _commandMessage = null;
    notifyListeners();
  }

  Future<void> setShowRemoteMessages(bool value) async {
    _showRemoteMessages = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showRemoteMessages', value);
    notifyListeners();
  }
}

// ==================== 入口 ====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Vars.initStationBuild();
  await Vars.initTrainBuild();
  await Vars.initCoachTrainBuild();
  await Vars.initLocoBuild();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()..loadSettings()),
        ChangeNotifierProvider(create: (_) => SpeedService()),
      ],
      child: const EmuTrainApp(),
    ),
  );
}

// ==================== App 根组件 ====================
class EmuTrainApp extends StatelessWidget {
  const EmuTrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        return ChangeNotifierProvider(
          create: (_) => JourneyProvider(),
          child: MaterialApp(
            title: 'EmuTrain',
            themeMode: settings.themeMode,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            home: const MainScreen(),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

// ==================== 主屏幕（导航） ====================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDefaultHomePage();
    _handleUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<AppSettings>(context, listen: false);
      settings.checkRemoteCommand();
    });
  }

  Future<void> _loadDefaultHomePage() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultPage = prefs.getString('default_home_page') ?? '旅途';
    setState(() {
      _currentIndex = defaultPage == '旅途' ? 0 : 1;
    });
  }

  Future<bool> _getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  Future<void> _handleUpdate() async {
    bool update = await _getSetting('showAutoUpdate');
    if (!update) return;
    final versionInfo = await Vars.fetchVersionInfo();
    if (versionInfo == null) return;
    final remoteBuild = versionInfo['Build']?.toString() ?? '';
    final currentBuild = Vars.build;
    if (remoteBuild.isNotEmpty &&
        int.tryParse(remoteBuild) != null &&
        int.tryParse(currentBuild) != null) {
      if (int.parse(remoteBuild) > int.parse(currentBuild) && mounted) {
        UpdateUI.showAppUpdateFlow(context);
      }
    }
  }

  void _showCommandMessageDialog(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('系统消息'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(settings.commandMessage!),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  settings.clearCommandMessage();
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );
  }

  String get _currentPageTitle {
    switch (_currentIndex) {
      case 0:
        return '行程';
      case 1:
        return '搜索';
      case 2:
        return '其他';
      case 3:
        return '设置';
      default:
        return 'EmuTrain';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        if (settings.commandMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showCommandMessageDialog(context, settings);
          });
        }

        return Scaffold(
          appBar: AppBar(title: Text(_currentPageTitle), centerTitle: true),
          body: _buildCurrentPage(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '旅途'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: '搜索'),
              BottomNavigationBarItem(icon: Icon(Icons.build), label: '其他'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const TravelScreen();
      case 1:
        return const SearchPage();
      case 2:
        return const ToolScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const TravelScreen();
    }
  }
}

// ==================== 图标工具类 ====================
class IconUtils {
  /// 返回路局图标文件名（无扩展名），空字符串返回 null
  static String? getBureauIconFileName(String bureau) {
    if (bureau.isEmpty) return null;
    return bureau; // assets/icon/bureau/<bureau>.png
  }
}

// ==================== 车次图标 Widget ====================
class TrainIconWidget extends StatelessWidget {
  final String model;
  final String number;
  final double size;
  final bool showIcon;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const TrainIconWidget({
    super.key,
    required this.model,
    required this.number,
    this.size = 32,
    this.showIcon = true,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (!settings.showTrainIcons || !showIcon) {
      return SizedBox(width: size, height: size);
    }

    final iconModel = TrainInfo.getTrainIconModel(model, number);
    final cleanName = _removePngExtension(iconModel);
    final assetPath = 'assets/icon/train/$cleanName.png';

    return FutureBuilder<bool>(
      future: _checkAssetExists(assetPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return snapshot.data == true
              ? _buildImageAsset(assetPath)
              : _buildFallbackIcon();
        }
        return _buildLoadingIndicator();
      },
    );
  }

  Future<bool> _checkAssetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _removePngExtension(String fileName) {
    if (fileName.toLowerCase().endsWith('.png')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  Widget _buildImageAsset(String assetPath) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor,
      ),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor ?? Colors.grey[200],
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.train, size: size * 0.4, color: Colors.grey[600]),
          if (size > 40)
            Text(
              model,
              style: TextStyle(
                fontSize: size * 0.2,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor ?? Colors.grey[200],
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      ),
    );
  }
}

// ==================== 路局图标 Widget ====================
class BureauIconWidget extends StatelessWidget {
  final String bureau;
  final double size;
  final bool showIcon;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const BureauIconWidget({
    super.key,
    required this.bureau,
    this.size = 32,
    this.showIcon = true,
    this.backgroundColor,
    this.borderRadius,
  });

  Future<bool> _checkImageExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (!settings.showBureauIcons || !showIcon || bureau.isEmpty) {
      return SizedBox(width: size, height: size);
    }

    final fileName = IconUtils.getBureauIconFileName(bureau);
    if (fileName == null) return SizedBox(width: size, height: size);

    final iconPath = 'assets/icon/bureau/$fileName.png';

    return FutureBuilder<bool>(
      future: _checkImageExists(iconPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == true) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
                color: backgroundColor ?? Colors.transparent,
              ),
              child: Image.asset(
                iconPath,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallbackIcon(),
              ),
            );
          } else {
            return _buildFallbackIcon();
          }
        }
        return _buildLoadingIndicator();
      },
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: Colors.grey[200],
      ),
      child: Icon(
        Icons.account_balance,
        size: size * 0.6,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: Colors.grey[200],
      ),
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
