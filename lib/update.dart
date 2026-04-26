import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'main.dart';
import 'tool.dart';

class UpdateService {
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://gitee.com/CrYinLang/EmuTrain/raw/master/${Vars.urlServer}.json',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'error': '网络错误 ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

/// ================= 对外调用入口 =================
class UpdateUI {
  static Future<void> showAppUpdateFlow(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CheckingDialog(),
    );

    final versionInfo = await UpdateService.checkForUpdate();

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AppUpdateResultDialog(versionInfo: versionInfo),
    );
  }

  static Future<void> showStationUpdateFlow(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CheckingDialog(),
    );

    final versionInfo = await UpdateService.checkForUpdate();

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => StationUpdateResultDialog(versionInfo: versionInfo),
    );
  }

  static Future<void> showTrainUpdateFlow(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CheckingDialog(),
    );

    final versionInfo = await UpdateService.checkForUpdate();

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => TrainUpdateResultDialog(versionInfo: versionInfo),
    );
  }

  static Future<void> showCoachTrainUpdateFlow(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CheckingDialog(),
    );

    final versionInfo = await UpdateService.checkForUpdate();

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => CoachTrainUpdateResultDialog(versionInfo: versionInfo),
    );
  }

  static Future<void> showLocoUpdateFlow(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CheckingDialog(),
    );

    final versionInfo = await UpdateService.checkForUpdate();

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => LocoUpdateResultDialog(versionInfo: versionInfo),
    );
  }
}

/// ================= 检测中弹窗 =================
class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            SizedBox(height: 20),
            Text('正在检测更新...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// ================= 下载中弹窗 =================
class _DownloadingDialog extends StatelessWidget {
  const _DownloadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            SizedBox(height: 20),
            Text('正在下载数据库文件...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ==================== 通用数据更新弹窗（内部复用） ==============
class _DataUpdateDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  /// version.json 中对应的 Build key，例如 'StationBuild'
  final String remoteBuildKey;

  /// 当前本地 build 字符串（Vars.stationBuild 等）
  final String currentBuildStr;

  /// 远端数据文件路径（Vars.stationData 等，不含 .json）
  final String remoteDataPath;

  /// 下载后保存到本地的文件名（含 .json）
  final String localFileName;

  /// 保存版本号的回调
  final Future<void> Function(String) saveBuild;

  /// 成功后的提示文字
  final String successSnackBar;

  const _DataUpdateDialog({
    required this.versionInfo,
    required this.remoteBuildKey,
    required this.currentBuildStr,
    required this.remoteDataPath,
    required this.localFileName,
    required this.saveBuild,
    required this.successSnackBar,
  });

  @override
  Widget build(BuildContext context) {
    final currentBuild = int.tryParse(currentBuildStr) ?? 0;
    int remoteBuild = 0;

    bool hasUpdate = false;
    String resultMessage = '';
    Color resultColor = Colors.green;
    IconData resultIcon = Icons.check_circle;

    if (versionInfo != null && versionInfo!.containsKey('error')) {
      resultMessage = '检查更新失败: ${versionInfo!['error']}';
      resultColor = Colors.red;
      resultIcon = Icons.error;
    } else if (versionInfo != null) {
      remoteBuild =
          int.tryParse(versionInfo![remoteBuildKey]?.toString() ?? '') ?? 0;

      if (remoteBuild > currentBuild) {
        hasUpdate = true;
        resultColor = Colors.green;
        resultIcon = Icons.file_copy;
      }
    } else {
      resultMessage = '检查更新失败: 未知错误';
      resultColor = Colors.red;
      resultIcon = Icons.error;
    }

    // 捕获一份 remoteBuild 供按钮 onPressed 闭包使用
    final int capturedRemoteBuild = remoteBuild;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(resultIcon, size: 50, color: resultColor),
                const SizedBox(height: 20),
                Text(
                  hasUpdate ? '发现数据库新版本' : '已是最新版本',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                if (hasUpdate)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'V$currentBuild',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'V$capturedRemoteBuild',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  )
                else if (resultMessage.isNotEmpty)
                  Text(
                    resultMessage,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                if (resultMessage.isNotEmpty) const SizedBox(height: 24),

                if (hasUpdate) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const _DownloadingDialog(),
                            );

                            try {
                              final url =
                                  'https://gitee.com/CrYinLang/EmuTrain/raw/master/$remoteDataPath.json';

                              final response = await http.get(Uri.parse(url));

                              if (response.statusCode == 200) {
                                // 验证 JSON 合法
                                json.decode(response.body);

                                final directory =
                                    await getApplicationDocumentsDirectory();
                                final file = File(
                                  '${directory.path}/$localFileName',
                                );
                                await file.writeAsString(response.body);

                                await saveBuild(capturedRemoteBuild.toString());

                                if (context.mounted) {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(successSnackBar)),
                                  );
                                }
                              } else {
                                throw Exception('下载失败: ${response.statusCode}');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('更新失败: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.download, size: 20),
                          label: const Text(
                            '升级',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            '关闭',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('关闭', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ================= 更新结果弹窗：应用本体 =================
class AppUpdateResultDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  const AppUpdateResultDialog({super.key, required this.versionInfo});

  @override
  Widget build(BuildContext context) {
    final currentBuild = int.tryParse(Vars.build) ?? 0;
    final currentVersion = Vars.version;

    bool hasUpdate = false;
    String resultMessage = '';
    Color resultColor = Colors.green;
    IconData resultIcon = Icons.check_circle;
    String? describeText;
    String? githubUrl;
    String? giteeUrl;
    String? qqUrl;
    String? newVersion;
    String? updateTime;

    if (versionInfo != null && versionInfo!.containsKey('error')) {
      resultMessage = '检查更新失败: ${versionInfo!['error']}';
      resultColor = Colors.red;
      resultIcon = Icons.error;
    } else if (versionInfo != null) {
      final remoteBuild = int.tryParse(versionInfo!['Build'].toString()) ?? 0;
      newVersion = versionInfo!['Version'];
      updateTime = versionInfo!['LastUpdate'];

      githubUrl = versionInfo!['github'];
      giteeUrl = versionInfo!['gitee'];
      qqUrl = versionInfo!['qq'];

      describeText = versionInfo!['describe'] ?? '修复了一些已知问题';

      if (remoteBuild > currentBuild) {
        hasUpdate = true;
        resultMessage =
            '发现新版本\n\n'
            '当前版本: $currentVersion ($currentBuild)\n'
            '最新版本: $newVersion ($remoteBuild)\n\n'
            '更新时间: $updateTime\n\n'
            '更新内容:\n$describeText';
        resultColor = Colors.orange;
        resultIcon = Icons.system_update;
      } else {
        resultMessage =
            '已是最新版本\n\n'
            '当前版本: $currentVersion ($currentBuild)\n'
            '最新版本: $newVersion ($remoteBuild)';
      }
    } else {
      resultMessage = '检查更新失败: 未知错误';
      resultColor = Colors.red;
      resultIcon = Icons.error;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(resultIcon, size: 50, color: resultColor),
                const SizedBox(height: 20),
                Text(
                  hasUpdate ? '发现新版本' : '检查完成',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    resultMessage,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (hasUpdate) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (qqUrl != null && qqUrl.isNotEmpty) {
                              Tool.launchBrowser(context, qqUrl);
                            }
                          },
                          icon: const Icon(Icons.group, size: 20),
                          label: const Text(
                            'QQ群下载',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (giteeUrl != null && giteeUrl.isNotEmpty) {
                              Tool.launchBrowser(context, giteeUrl);
                            }
                          },
                          icon: const Icon(Icons.code, size: 20),
                          label: const Text(
                            'Gitee下载',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (githubUrl != null && githubUrl.isNotEmpty) {
                              Tool.launchBrowser(context, githubUrl);
                            }
                          },
                          icon: const Icon(Icons.cloud_download, size: 20),
                          label: const Text(
                            'Github',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            '关闭',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('关闭', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ================= 数据更新弹窗：车站数据 =================
class StationUpdateResultDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  const StationUpdateResultDialog({super.key, required this.versionInfo});

  @override
  Widget build(BuildContext context) {
    return _DataUpdateDialog(
      versionInfo: versionInfo,
      remoteBuildKey: 'StationBuild',
      currentBuildStr: Vars.stationBuild,
      remoteDataPath: Vars.stationData,
      localFileName: 'stations.json',
      saveBuild: Vars.setStationBuild,
      successSnackBar: '车站数据更新成功！',
    );
  }
}

/// ================= 数据更新弹窗：动车组配属数据 =================
class TrainUpdateResultDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  const TrainUpdateResultDialog({super.key, required this.versionInfo});

  @override
  Widget build(BuildContext context) {
    return _DataUpdateDialog(
      versionInfo: versionInfo,
      remoteBuildKey: 'TrainBuild',
      currentBuildStr: Vars.trainBuild,
      remoteDataPath: Vars.trainData,
      localFileName: 'train.json',
      saveBuild: Vars.setTrainBuild,
      successSnackBar: '动车组配属数据更新成功！',
    );
  }
}

/// ================= 数据更新弹窗：普速客车配属数据 =================
class CoachTrainUpdateResultDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  const CoachTrainUpdateResultDialog({super.key, required this.versionInfo});

  @override
  Widget build(BuildContext context) {
    return _DataUpdateDialog(
      versionInfo: versionInfo,
      remoteBuildKey: 'CoachTrainBuild',
      currentBuildStr: Vars.coachTrainBuild,
      remoteDataPath: Vars.coachTrainData,
      localFileName: 'coach.json',
      saveBuild: Vars.setCoachTrainBuild,
      successSnackBar: '普速客车数据更新成功！',
    );
  }
}

class LocoUpdateResultDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  const LocoUpdateResultDialog({super.key, required this.versionInfo});

  @override
  Widget build(BuildContext context) {
    return _DataUpdateDialog(
      versionInfo: versionInfo,
      remoteBuildKey: 'LocoBuild',
      currentBuildStr: Vars.locoBuild,
      remoteDataPath: Vars.locoData,
      localFileName: 'loco.json',
      saveBuild: Vars.setLocoBuild,
      successSnackBar: '机车配属数据更新成功！',
    );
  }
}
