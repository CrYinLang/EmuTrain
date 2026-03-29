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
          .get(Uri.parse('https://gitee.com/CrYinLang/EmuTrain/raw/master/${Vars.urlServer}.json'))
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

/// ================= 更新结果弹窗 =================
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
        resultMessage = '发现新版本\n\n'
            '当前版本: $currentVersion ($currentBuild)\n'
            '最新版本: $newVersion ($remoteBuild)\n\n'
            '更新时间: $updateTime\n\n'
            '更新内容:\n$describeText';
        resultColor = Colors.orange;
        resultIcon = Icons.system_update;
      } else {
        resultMessage = '已是最新版本\n\n'
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 更新描述区域
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          label: const Text('QQ群下载', style: TextStyle(fontSize: 14)),
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
                          label: const Text('Gitee下载', style: TextStyle(fontSize: 14)),
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
                          label: const Text('Github', style: TextStyle(fontSize: 14)),
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
                          child: const Text('关闭', style: TextStyle(fontSize: 14)),
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

class StationUpdateResultDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  const StationUpdateResultDialog({super.key, required this.versionInfo});

  @override
  Widget build(BuildContext context) {
    final currentBuild = int.tryParse(Vars.stationBuild) ?? 42;
    int remoteBuild = 42;

    bool hasUpdate = false;
    String resultMessage = '';
    Color resultColor = Colors.green;
    IconData resultIcon = Icons.check_circle;

    if (versionInfo != null && versionInfo!.containsKey('error')) {
      resultMessage = '检查更新失败: ${versionInfo!['error']}';
      resultColor = Colors.red;
      resultIcon = Icons.error;
    } else if (versionInfo != null) {
      remoteBuild = int.tryParse(versionInfo!['StationBuild'].toString()) ?? 42;

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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      Icon(Icons.arrow_forward, size: 20, color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: 8),
                      Text(
                        'V$remoteBuild',
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
                              String stationDataUrl = 'https://gitee.com/CrYinLang/EmuTrain/raw/master/${Vars.stationData}.json';

                              // 下载文件内容
                              final response = await http.get(Uri.parse(stationDataUrl));

                              if (response.statusCode == 200) {
                                final directory = await getApplicationDocumentsDirectory();

                                final file = File('${directory.path}/statiosns.json');
                                await file.writeAsString(response.body);

                                final versionFile = File('${directory.path}/stationVer.json');
                                final versionData = {
                                  "StationBuild": remoteBuild.toString(),
                                  "file": "stations.json"
                                };
                                await versionFile.writeAsString(json.encode(versionData));
                                await Vars.setStationBuild(remoteBuild.toString());

                                if (context.mounted) {
                                  Navigator.of(context, rootNavigator: true).pop();
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('车站数据更新成功！'),
                                    ),
                                  );
                                }
                              } else {
                                throw Exception('下载失败: ${response.statusCode}');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.of(context, rootNavigator: true).pop(); // 关闭下载弹窗

                                // 显示错误提示
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('更新失败: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          label: const Text('升级', style: TextStyle(fontSize: 14)),
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
                          child: const Text('关闭', style: TextStyle(fontSize: 14)),
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

class TrainUpdateResultDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  const TrainUpdateResultDialog({super.key, required this.versionInfo});

  @override
  Widget build(BuildContext context) {
    final currentBuild = int.tryParse(Vars.trainBuild) ?? 42;
    int remoteBuild = 42;

    bool hasUpdate = false;
    String resultMessage = '';
    Color resultColor = Colors.green;
    IconData resultIcon = Icons.check_circle;

    if (versionInfo != null && versionInfo!.containsKey('error')) {
      resultMessage = '检查更新失败: ${versionInfo!['error']}';
      resultColor = Colors.red;
      resultIcon = Icons.error;
    } else if (versionInfo != null) {
      remoteBuild = int.tryParse(versionInfo!['TrainBuild'].toString()) ?? 42;

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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      Icon(Icons.arrow_forward, size: 20, color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: 8),
                      Text(
                        'V$remoteBuild',
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
                              String trainDataUrl = 'https://gitee.com/CrYinLang/EmuTrain/raw/master/${Vars.trainData}.json';

                              // 下载文件内容
                              final response = await http.get(Uri.parse(trainDataUrl));

                              if (response.statusCode == 200) {
                                final directory = await getApplicationDocumentsDirectory();

                                final file = File('${directory.path}/train.json');
                                await file.writeAsString(response.body);

                                final versionFile = File('${directory.path}/trainVer.json');
                                final versionData = {
                                  "TrainBuild": remoteBuild.toString(),
                                  "file": "train.json"
                                };
                                await versionFile.writeAsString(json.encode(versionData));
                                await Vars.setTrainBuild(remoteBuild.toString());

                                if (context.mounted) {
                                  Navigator.of(context, rootNavigator: true).pop();
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('车站数据更新成功！'),
                                    ),
                                  );
                                }
                              } else {
                                throw Exception('下载失败: ${response.statusCode}');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.of(context, rootNavigator: true).pop(); // 关闭下载弹窗

                                // 显示错误提示
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('更新失败: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          label: const Text('升级', style: TextStyle(fontSize: 14)),
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
                          child: const Text('关闭', style: TextStyle(fontSize: 14)),
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