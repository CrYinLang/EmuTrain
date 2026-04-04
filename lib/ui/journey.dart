// journey.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../journey_model.dart';
import '../journey_provider.dart';
import 'linemap.dart';
import 'travel_screen.dart';

class AddJourneyPage extends StatefulWidget {
  final String? initialTrainNumber;
  final bool autoSearchAndExpand;

  const AddJourneyPage({
    super.key,
    this.initialTrainNumber,
    this.autoSearchAndExpand = false,
  });

  @override
  State<AddJourneyPage> createState() => _AddJourneyPageState();
}

class _AddJourneyPageState extends State<AddJourneyPage>
    with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
  final _trainNumberCtrl = TextEditingController();
  bool _loading = false;
  List<dynamic> _trainResults = [];
  int? _expandedIndex;
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  String? _fromCode, _toCode;
  String? _fromName = '请选择', _toName = '请选择';
  List<dynamic> _allStations = [];
  bool _loadingStations = false;
  List<dynamic> _stationResults = [];
  int? _stationExpandedIndex;
  final Map<int, List<dynamic>> _stationDetails = {};
  final Map<int, bool> _stationLoading = {};
  int _searchMode = 0;
  final Map<int, List<dynamic>> _trainDetails = {};
  final Map<int, bool> _trainLoading = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _loadStations();
    _trainNumberCtrl.addListener(() {
      final text = _trainNumberCtrl.text;
      if (text.isNotEmpty && text != text.toUpperCase()) _formatInput(text);
    });
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDate = today.add(const Duration(days: 1));

    if (widget.initialTrainNumber != null && widget.initialTrainNumber!.isNotEmpty) {
      _trainNumberCtrl.text = widget.initialTrainNumber!;
      _searchMode = 0; // 强制车次查询模式
      _selectedDate = today;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchTrain(); // 自动触发搜索
      });
    }
  }

  Map<String, String> _stationNameMap = {};

  String _normalizeStationName(String name) {
    if (name.isEmpty) return '';
    // 移除"站"字和空格
    return name.replaceAll('站', '').replaceAll(' ', '').trim();
  }

  Future<void> _loadStations() async {
    setState(() => _loadingStations = true);
    try {
      List<dynamic> stationsList = [];

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final versionFile = File('${directory.path}/stationVer.json');
      final dataFile = File('${directory.path}/stations.json');

      // 检查是否存在更新版本
      if (await versionFile.exists() && await dataFile.exists()) {
        try {
          // 读取版本信息（即使不使用也保持读取以验证文件完整性）
          final versionContent = await versionFile.readAsString();
          final versionData = json.decode(versionContent);

          // 读取更新后的数据文件
          final jsonString = await dataFile.readAsString();
          stationsList = json.decode(jsonString);

          // 可以使用版本信息进行日志记录
          debugPrint('已加载更新版本: ${versionData['StationBuild']}');
        } catch (e) {
          // 如果更新文件损坏，回退到默认资源
          final jsonString = await rootBundle.loadString(
            'assets/stations.json',
          );
          stationsList = json.decode(jsonString);
          debugPrint('更新文件损坏，使用默认资源: $e');
        }
      } else {
        // 加载默认资源文件
        final jsonString = await rootBundle.loadString('assets/stations.json');
        stationsList = json.decode(jsonString);
        debugPrint('加载默认资源文件');
      }

      final Map<String, String> nameMap = {};
      for (var station in stationsList) {
        final telecode = station['telecode'];
        final name = station['name'];
        if (telecode != null && name != null) {
          nameMap[telecode] = name;
        }
      }

      setState(() {
        _allStations = stationsList;
        _stationNameMap = nameMap;
      });
    } catch (e) {
      _showSnack('加载站点数据失败: $e');
    } finally {
      setState(() => _loadingStations = false);
    }
  }

  String _getStationName(String telecode) {
    final name = _stationNameMap[telecode.replaceAll(' ', '')] ?? telecode;
    return name.contains(RegExp(r'[a-zA-Z]')) ? '始发站  (环线)' : name;
  }

  String _cleanStationName(String name) {
    return name.replaceAll(' ', '');
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _trainNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daytwo = today.add(const Duration(days: -2));
    final tomorrow = today.add(const Duration(days: 1));
    final maxDate = today.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? tomorrow,
      firstDate: daytwo,
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _expandedIndex = null;
        _stationExpandedIndex = null;
        _trainDetails.clear();
        _trainLoading.clear();
        _stationDetails.clear();
        _stationLoading.clear();
        if (_animCtrl.isAnimating) _animCtrl.reset();
      });
    }
  }

  String get dateText => _selectedDate == null
      ? "选择日期"
      : "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

  String get _formattedDate => _selectedDate == null
      ? ""
      : "${_selectedDate!.year}${_selectedDate!.month.toString().padLeft(2, '0')}${_selectedDate!.day.toString().padLeft(2, '0')}";

  void _formatInput(String value) {
    if (value.isEmpty) return;
    String uppercase = value.toUpperCase();
    const allowed = 'GDCSKZTWPQ';
    String result = '';
    for (int i = 0; i < uppercase.length; i++) {
      String char = uppercase[i];
      if (i == 0) {
        if (RegExp(r'[0-9]').hasMatch(char) || allowed.contains(char)) {
          result += char;
        }
      } else {
        if (RegExp(r'[0-9]').hasMatch(char)) result += char;
      }
    }
    if (result != _trainNumberCtrl.text) {
      _trainNumberCtrl.value = _trainNumberCtrl.value.copyWith(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  void _switchMode(int mode) {
    if (_searchMode == mode) return;
    setState(() {
      _searchMode = mode;
      _expandedIndex = null;
      _stationExpandedIndex = null;
      _trainDetails.clear();
      _trainLoading.clear();
      _stationDetails.clear();
      _stationLoading.clear();
      if (_animCtrl.isAnimating) _animCtrl.reset();
    });
  }

  Future<void> _searchTrain() async {
    if (_selectedDate == null) {
      _showSnack('请先选择日期');
      return;
    }
    final trainNumber = _trainNumberCtrl.text.trim();
    if (trainNumber.isEmpty) {
      _showSnack('请输入车次');
      return;
    }

    setState(() {
      _loading = true;
      _trainResults.clear();
      _trainDetails.clear();
      _trainLoading.clear();
      _expandedIndex = null;
      if (_animCtrl.isAnimating) _animCtrl.reset();
    });

    try {
      final url =
          'https://search.12306.cn/search/v1/train/search?keyword=$trainNumber&date=$_formattedDate';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true) {
          final allResults = data['data'] ?? [];
          final limitedResults = allResults.length > 15
              ? allResults.sublist(0, 15)
              : allResults;

          setState(() => _trainResults = limitedResults);

          // ==================== 自动展开逻辑（关键修复） ====================
          if (widget.autoSearchAndExpand && limitedResults.isNotEmpty) {
            if (limitedResults.length == 1) {
              // 只有一条结果时：自动展开 + 加载详情 + 禁止收回
              setState(() => _expandedIndex = 0);
              _animCtrl.forward();
              await _fetchDetails(0, false);   // 加载停站信息
            } else {
              // 多条结果时：只自动展开第一条（可选），不强制禁止收回
              setState(() => _expandedIndex = 0);
              _animCtrl.forward();
              await _fetchDetails(0, false);
            }
          }
          // =================================================================

          _showSnack(
            _trainResults.isEmpty
                ? '未找到相关车次信息'
                : '找到 ${_trainResults.length} 条结果',
          );
        } else {
          _showSnack('搜索失败: ${data['errorMsg'] ?? '未知错误'}');
        }
      } else {
        _showSnack('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _showSnack('发生错误: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String> _getBenWu(String trainCode, String date) async {
    if (!RegExp(r'^[GDCS]', caseSensitive: false).hasMatch(trainCode)) {
      return '';
    }

    final url = Uri.parse('https://rail.moefactory.com/api/trainNumber/query');

    final resp1 = await http.post(
      url,
      body: {"trainNumber": trainCode, "date": date},
    );

    final Map<String, dynamic> responseData = jsonDecode(resp1.body);

    // 检查响应码
    if (responseData['code'] == 200) {
      final List<dynamic> dataList = responseData['data']['data'];

      if (dataList.isNotEmpty) {
        final int trainIndex = dataList[0]['trainIndex'];

        final url2 = Uri.parse(
          'https://rail.moefactory.com/api/trainDetails/query',
        );

        final resp2 = await http.post(
          url2,
          body: {"trainIndex": trainIndex.toString(), "date": date},
        );

        final Map<String, dynamic> responseData2 = jsonDecode(resp2.body);

        // 检查响应码
        if (responseData2['code'] == 200) {
          final String? trainModel =
              responseData2['data']['routing']['trainModel'];

          if (trainModel != null && trainModel.isNotEmpty) {
            String result = trainModel.substring(
              0,
              trainModel.length > 14 ? 14 : trainModel.length,
            );

            final commaIndex = result.indexOf(',');
            final chineseCommaIndex = result.indexOf('，');

            if (commaIndex != -1) {
              result = result.substring(0, commaIndex);
            } else if (chineseCommaIndex != -1) {
              result = result.substring(0, chineseCommaIndex);
            }
            return result;
          } else {
            return '未知';
          }
        } else {
          return '未知';
        }
      } else {
        return '未知';
      }
    }

    return '未知';
  }

  Future<void> _searchStation() async {
    if (_selectedDate == null) {
      _showSnack('请先选择日期');
      return;
    }
    if (_fromCode == null || _toCode == null) {
      _showSnack('请选择起始站和终点站');
      return;
    }

    setState(() {
      _loading = true;
      _stationResults.clear();
      _stationDetails.clear();
      _stationLoading.clear();
      _stationExpandedIndex = null;
      if (_animCtrl.isAnimating) _animCtrl.reset();
    });

    try {
      final stationDay =
          '${_formattedDate.substring(0, 4)}-${_formattedDate.substring(4, 6)}-${_formattedDate.substring(6, 8)}';

      // 同时请求余票查询和价格查询
      final ticketFuture = http.get(
        Uri.parse(
          'https://kyfw.12306.cn/otn/leftTicket/queryG?leftTicketDTO.train_date=$stationDay&leftTicketDTO.from_station=$_fromCode&leftTicketDTO.to_station=$_toCode&purpose_codes=ADULT',
        ),
        headers: _getApiHeaders(),
      );

      final priceFuture = http.get(
        Uri.parse(
          'https://kyfw.12306.cn/otn/leftTicketPrice/queryAllPublicPrice?leftTicketDTO.train_date=$stationDay&leftTicketDTO.from_station=$_fromCode&leftTicketDTO.to_station=$_toCode&purpose_codes=ADULT',
        ),
        headers: _getApiHeaders(),
      );

      // 等待两个请求完成
      final responses = await Future.wait([ticketFuture, priceFuture]);
      final ticketResponse = responses[0];
      final priceResponse = responses[1];

      if (ticketResponse.statusCode == 200 && priceResponse.statusCode == 200) {
        final ticketData = json.decode(ticketResponse.body);
        final priceData = json.decode(priceResponse.body);

        if (ticketData['status'] == true && priceData['status'] == true) {
          final ticketResultData = ticketData['data'] as Map<String, dynamic>?;
          final priceList = priceData['data'] as List<dynamic>? ?? [];

          if (ticketResultData != null &&
              ticketResultData.containsKey('result')) {
            final results = ticketResultData['result'] as List<dynamic>?;
            final stationMap =
                ticketResultData['map'] as Map<String, dynamic>? ?? {};

            // 将价格数据转换为便于查询的 Map
            final priceMap = _buildPriceMap(priceList);

            // 解析车次数据并合并价格信息
            final List<Map<String, dynamic>> parsedTrains = [];
            for (final trainStr in results ?? []) {
              if (trainStr is String) {
                final trainInfo = _parseTrainString(trainStr, stationMap);
                if (trainInfo != null) {
                  // 合并价格信息
                  final mergedInfo = _mergePriceData(trainInfo, priceMap);
                  parsedTrains.add(mergedInfo);
                }
              }
            }

            setState(() => _stationResults = parsedTrains);

            _showSnack(
              _stationResults.isEmpty
                  ? '未找到相关车次信息'
                  : '找到 ${_stationResults.length} 条结果',
            );
          }
        } else {
          _showSnack('数据获取失败');
        }
      } else {
        _showSnack('网络请求失败');
      }
    } catch (e) {
      _showSnack('发生错误: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, String> _getApiHeaders() {
    return {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Referer': 'https://kyfw.12306.cn/otn/leftTicket/init',
      'Cookie':
          '_jc_save_fromStation=$_fromCode; _jc_save_toStation=$_toCode; _jc_save_fromDate=$_formattedDate; _jc_save_toDate=$_formattedDate;',
    };
  }

  // 构建价格查询 Map
  Map<String, Map<String, dynamic>> _buildPriceMap(List<dynamic> priceList) {
    final Map<String, Map<String, dynamic>> priceMap = {};

    for (final item in priceList) {
      final dto = item['queryLeftNewDTO'] as Map<String, dynamic>?;
      if (dto != null) {
        final trainCode = dto['station_train_code'] as String?;
        if (trainCode != null) {
          priceMap[trainCode] = dto;
        }
      }
    }

    return priceMap;
  }

  // 合并余票和价格数据
  Map<String, dynamic> _mergePriceData(
    Map<String, dynamic> trainInfo,
    Map<String, Map<String, dynamic>> priceMap,
  ) {
    final trainCode = trainInfo['station_train_code'] as String?;
    final priceInfo = trainCode != null ? priceMap[trainCode] : null;

    if (priceInfo != null) {
      // 合并价格信息
      trainInfo['price_info'] = priceInfo;

      trainInfo['swz_price'] = _formatPrice(
        priceInfo['swz_price'],
        priceInfo['tz_price'],
      );
      trainInfo['zy_price'] = _formatPrice(
        priceInfo['zy_price'],
        priceInfo['zy_price'],
      );
      trainInfo['ze_price'] = _formatPrice(
        priceInfo['ze_price'],
        priceInfo['wz_price'],
      );
      trainInfo['gr_price'] = _formatPrice(
        priceInfo['gr_price'],
        priceInfo['gr_price'],
      );
      trainInfo['rw_price'] = _formatPrice(
        priceInfo['rw_price'],
        priceInfo['srrb_price'],
      );
      trainInfo['yw_price'] = _formatPrice(
        priceInfo['yw_price'],
        priceInfo['yw_price'],
      );
      trainInfo['rz_price'] = _formatPrice(
        priceInfo['rz_price'],
        priceInfo['rz_price'],
      );
      trainInfo['yz_price'] = _formatPrice(
        priceInfo['yz_price'],
        priceInfo['yz_price'],
      );
      trainInfo['wz_price'] = _formatPrice(
        priceInfo['ze_price'],
        priceInfo['yz_price'],
      );
      trainInfo['tz_price'] = _formatPrice(
        priceInfo['tz_price'],
        priceInfo['swz_price'],
      );
      trainInfo['qt_price'] = _formatPrice(
        priceInfo['qt_price'],
        priceInfo['qt_price'],
      );
      trainInfo['gg_price'] = _formatPrice(
        priceInfo['gg_price'],
        priceInfo['gg_price'],
      );
      trainInfo['srrb_price'] = _formatPrice(
        priceInfo['srrb_price'],
        priceInfo['rw_price'],
      );
      trainInfo['yb_price'] = _formatPrice(
        priceInfo['yb_price'],
        priceInfo['yb_price'],
      );
    }

    return trainInfo;
  }

  // 价格格式化（角转元）
  String _formatPrice(dynamic priceValue, dynamic priceValueBa) {
    if (priceValue == null) {
      if (priceValueBa == null) {
        return '--';
      }
      priceValue = priceValueBa;
    }

    try {
      final priceStr = priceValue.toString().trim();
      if (priceStr.isEmpty || priceStr == '0') return '--';

      final priceInt = int.tryParse(priceStr) ?? 0;
      if (priceInt == 0) return '--';

      final priceYuan = priceInt / 10.0;

      return priceYuan.toStringAsFixed(1);
    } catch (e) {
      return '--';
    }
  }

  // 添加解析车次字符串的方法
  Map<String, dynamic>? _parseTrainString(
    String trainStr,
    Map<String, dynamic> stationMap,
  ) {
    try {
      // 多重解码处理
      String decodedStr = trainStr;

      // 尝试多次解码，直到没有可解码的内容
      bool hasEncodedContent = true;
      int maxAttempts = 5;

      while (hasEncodedContent && maxAttempts > 0) {
        try {
          String temp = Uri.decodeComponent(decodedStr);
          // 如果解码后内容不变，说明没有编码内容了
          if (temp == decodedStr) {
            hasEncodedContent = false;
          } else {
            decodedStr = temp;
          }
        } catch (e) {
          // 解码失败，停止尝试
          hasEncodedContent = false;
        }
        maxAttempts--;
      }

      final fields = decodedStr.split('|');

      // 使用与Python代码完全一致的座位字段索引映射
      final Map<int, String> seatFields = {
        20: 'gg_num', // 优选一等座
        21: 'gr_num', // 高级软卧
        22: 'qt_num', // 其他
        23: 'rw_num', // 软卧
        24: 'rz_num', // 软座
        25: 'tz_num', // 特等座
        26: 'wz_num', // 无座
        27: 'yb_num', // 预留
        28: 'yw_num', // 硬卧
        29: 'yz_num', // 硬座
        30: 'ze_num', // 二等座
        31: 'zy_num', // 一等座
        32: 'swz_num', // 商务座
        33: 'srrb_num', // 动卧
      };

      // 解析座位信息
      final Map<String, String> seatInfo = {};

      for (final entry in seatFields.entries) {
        final value = fields[entry.key];
        final cleanedValue = _cleanSeatValue(value);
        seatInfo[entry.value] = cleanedValue;
      }

      // 构建车次信息
      return {
        'station_train_code': fields[3],
        'from_station_code': fields[4],
        'to_station_code': fields[5],
        'from_station': _cleanStationName(stationMap[fields[4]] ?? fields[4]),
        'to_station': _cleanStationName(stationMap[fields[5]] ?? fields[5]),
        'start_time': fields[8],
        'arrive_time': fields[9],
        'run_time': fields[10],
        'can_web_buy': fields[11] == 'Y' ? '是' : '否',
        '座位信息': seatInfo,
      };
    } catch (e) {
      return null;
    }
  }

  // 清理座位数值
  String _cleanSeatValue(String value) {
    if (value.isEmpty || value == '--' || value == '无' || value == 'NULL') {
      return '无票';
    } else if (value == '有') {
      return '有票';
    } else if (value.isNotEmpty && int.tryParse(value) != null) {
      return '$value张';
    } else {
      return value;
    }
  }

  Future<void> _fetchDetails(int index, bool isStation) async {
    if (isStation) {
      if (_stationDetails.containsKey(index)) return;
      final trainInfo = _stationResults[index];
      final trainNumber = trainInfo['station_train_code']?.toString() ?? '';
      if (trainNumber.isEmpty) return;
      setState(() => _stationLoading[index] = true);
      try {
        final stopData = await _fetchStopInfo(trainNumber);
        setState(() {
          _stationDetails[index] = stopData;
          _stationLoading[index] = false;
        });
      } catch (e) {
        _showSnack('获取停站信息失败: $e');
        setState(() => _stationLoading[index] = false);
      }
    } else {
      if (_trainDetails.containsKey(index)) return;
      final trainInfo = _trainResults[index];
      final trainNumber = trainInfo['station_train_code']?.toString() ?? '';
      if (trainNumber.isEmpty) return;
      setState(() => _trainLoading[index] = true);
      try {
        final stopData = await _fetchStopInfo(trainNumber);
        setState(() {
          _trainDetails[index] = stopData;
          _trainLoading[index] = false;
        });
      } catch (e) {
        _showSnack('获取停站信息失败: $e');
        setState(() => _trainLoading[index] = false);
      }
    }
  }

  Future<List<dynamic>> _fetchStopInfo(String trainNumber) async {
    final url = Uri.parse(
      'https://m.ctrip.com/restapi/soa2/14674/json/GetTrainStopTimeInfo',
    );
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Referer': 'https://m.ctrip.com/',
      'Origin': 'https://m.ctrip.com',
    };
    final body = {'TrainNumber': trainNumber, 'DepartDate': _formattedDate};
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['RetCode'] == 1 && data['StopList'] != null) {
          final List<dynamic> stopList = data['StopList'];
          return stopList
              .map(
                (stop) => {
                  'stationNo': stop['StationNo'] ?? '',
                  'stationName': _cleanStationName(stop['StationName']),
                  'arriveTime': stop['ArriveTime'] ?? '--:--',
                  'departTime': stop['DepartTime'] ?? '--:--',
                  'stayTime': stop['StayWayStationTime'] ?? '0',
                  'DayDifference': stop['DayDifference'] ?? 0,
                  'telCode': stop['TelCode'] ?? '',
                  'isFirst': stop['StationNo'] == '01',
                  'isLast':
                      stop['StationNo'] ==
                      stopList.length.toString().padLeft(2, '0'),
                },
              )
              .toList();
        } else if (data['RetCode'] != 1) {
          throw Exception(
            'API返回失败: RetCode=${data['RetCode']}, Ack=${data['ResponseStatus']?['Ack']}',
          );
        } else {
          return [];
        }
      } else {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _showStationSelector(bool isFrom) async {
    if (_loadingStations) {
      _showSnack('正在加载站点数据...');
      return;
    }
    if (_allStations.isEmpty) {
      _showSnack('站点数据为空，请稍后重试');
      return;
    }
    String? selectedCode = isFrom ? _fromCode : _toCode;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StationSelectorModal(
        stations: _allStations,
        selectedCode: selectedCode,
        title: isFrom ? '选择出发站' : '选择到达站',
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isFrom) {
          _fromCode = result['telecode'];
          _fromName = result['name'];
        } else {
          _toCode = result['telecode'];
          _toName = result['name'];
        }
      });
    }
  }

  void _toggleExpand(int index, bool isStation) async {
    if (widget.autoSearchAndExpand &&
        !isStation &&                    // 车次查询模式
        _trainResults.length == 1 &&     // 只有一条结果
        _expandedIndex == index) {
      return; // 不允许收回
    }

    if (isStation) {
      if (_stationExpandedIndex == index) {
        _animCtrl.reverse().then((_) {
          if (mounted) {
            setState(() => _stationExpandedIndex = null);
          }
        });
      } else {
        setState(() => _stationExpandedIndex = index);
        _animCtrl.forward();
        await _fetchDetails(index, true);
      }
    } else {
      if (_expandedIndex == index) {
        _animCtrl.reverse().then((_) {
          if (mounted) {
            setState(() => _expandedIndex = null);
          }
        });
      } else {
        setState(() => _expandedIndex = index);
        _animCtrl.forward();
        await _fetchDetails(index, false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _clearResults() {
    if (_searchMode == 0) {
      setState(() {
        _trainResults.clear();
        _trainDetails.clear();
        _trainLoading.clear();
        _expandedIndex = null;
        if (_animCtrl.isAnimating) _animCtrl.reset();
      });
      _trainNumberCtrl.clear();
      _showSnack('已清除车次搜索结果');
    } else {
      setState(() {
        _stationResults.clear();
        _stationDetails.clear();
        _stationLoading.clear();
        _stationExpandedIndex = null;
        if (_animCtrl.isAnimating) _animCtrl.reset();
      });
      _showSnack('已清除站点搜索结果');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加旅途'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if ((_searchMode == 0 && _trainResults.isNotEmpty) ||
              (_searchMode == 1 && _stationResults.isNotEmpty))
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearResults,
              tooltip: '清除搜索结果',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 日期选择器 - 使用主题色边框
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedDate == null
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SegmentedButton - 保持原样
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('车次查询', style: TextStyle(fontSize: 16)),
                      icon: Icon(Icons.train, size: 20),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('车站查询', style: TextStyle(fontSize: 16)),
                      icon: Icon(Icons.location_on, size: 20),
                    ),
                  ],
                  selected: {_searchMode},
                  onSelectionChanged: (Set<int> s) => _switchMode(s.first),
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    selectedBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary,
                    selectedForegroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimary,
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 56),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_searchMode == 0) ...[
                // 车次输入框 - 使用主题色
                SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _trainNumberCtrl,
                    onChanged: (value) {
                      if (value.isNotEmpty) _formatInput(value);
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9GDCSKZTWPQgdcskztwpq1]'),
                      ),
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.copyWith(
                          text: newValue.text.toUpperCase(),
                        ),
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: "请输入车次",
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 20),

                // 搜索按钮
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _searchTrain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            '搜索车次',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // 车次列表结果
                _buildTrainList(),
              ],

              if (_searchMode == 1) ...[
                // 车站选择器 - 使用主题色
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showStationSelector(true),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _fromCode != null
                                  ? Colors.blue
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: _fromCode != null
                                    ? Colors.blue
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _fromName!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _fromCode != null
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showStationSelector(false),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _toCode != null
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: _toCode != null
                                    ? Colors.red
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _toName!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _toCode != null
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 搜索按钮
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _searchStation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            '搜索站点间车次',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // 车站列表结果
                _buildStationList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trainResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无车次搜索结果\n\n信息仅供参考,合理安排时间行程\n买票请上12306,发货请上95306',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(
        _trainResults.length,
        (index) => _buildItem(index, false),
      ),
    );
  }

  Widget _buildStationList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stationResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无站点间车次结果\n\n信息仅供参考,合理安排时间行程\n买票请上12306,发货请上95306',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(
        _stationResults.length,
        (index) => _buildItem(index, true),
      ),
    );
  }

  Widget _buildItem(int index, bool isStation) {
    final item = isStation ? _stationResults[index] : _trainResults[index];
    final isExpanded = isStation
        ? _stationExpandedIndex == index
        : _expandedIndex == index;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.train, color: Colors.blue),
            title: Text(
              '${item['station_train_code']} 次列车',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${_getStationName(item['from_station'])} → ${_getStationName(item['to_station'])}',
            ),
            trailing: AnimatedIcon(
              icon: AnimatedIcons.arrow_menu,
              progress: isExpanded
                  ? _anim
                  : Tween<double>(
                      begin: 0,
                      end: 1,
                    ).animate(AlwaysStoppedAnimation(0)),
              color: Theme.of(context).colorScheme.primary,
            ),
            onTap: () => _toggleExpand(index, isStation),
          ),
          if (isExpanded) ...[
            SizeTransition(
              sizeFactor: _anim,
              child: _buildExpanded(index, item, isStation),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpanded(int index, Map<String, dynamic> item, bool isStation) {
    final loading = isStation
        ? (_stationLoading[index] ?? false)
        : (_trainLoading[index] ?? false);
    final stopData = isStation
        ? (_stationDetails[index] ?? [])
        : (_trainDetails[index] ?? []);

    final trainCode = item['station_train_code']?.toString() ?? '';

    String depTime = item['start_time']?.toString() ?? '--:--';
    String arrTime = item['arrive_time']?.toString() ?? '--:--';
    String runTime = item['run_time']?.toString() ?? '--';

    // 检查是否是环线列车（始发站和终点站相同）
    bool isCircularLine =
        _getStationName(item['from_station']) ==
        _getStationName(item['to_station']);

    if (isStation && stopData.isNotEmpty) {
      final fromStationName = _fromName;
      final toStationName = _toName;

      if (fromStationName != null && toStationName != null) {
        // 对于环线列车选择同一车站的特殊处理
        if (isCircularLine && fromStationName == toStationName) {
          // 环线列车：使用第一个站的发车时间和最后一个站的到达时间
          final firstStop = stopData.first as Map<String, dynamic>?;
          final lastStop = stopData.last as Map<String, dynamic>?;

          if (firstStop != null && lastStop != null) {
            final firstDep = firstStop['departTime'] as String?;
            final lastArr = lastStop['arriveTime'] as String?;

            if (firstDep != null && lastArr != null) {
              final firstDayDiff = _parseDayDifference(
                firstStop['DayDifference'],
              );
              final lastDayDiff = _parseDayDifference(
                lastStop['DayDifference'],
              );
              final totalDayDiff = lastDayDiff - firstDayDiff;

              depTime = firstDep;
              arrTime = lastArr;
              runTime = _calcRunTime(
                firstDep,
                lastArr,
                totalDayDiff.toString(),
              );
            }
          }
        } else {
          // 原有的非环线逻辑保持不变
          Map<String, dynamic>? fromStation;
          Map<String, dynamic>? toStation;

          for (final stop in stopData) {
            final station = stop as Map<String, dynamic>;
            final stationName = station['stationName'] as String?;

            if (stationName == fromStationName) {
              fromStation = station;
            }
            if (stationName == toStationName) {
              toStation = station;
            }

            // 如果两个都找到了，提前退出循环
            if (fromStation != null && toStation != null) break;
          }

          if (fromStation != null && toStation != null) {
            // 获取上车站的发车/到达时间
            final fromDep = fromStation['departTime'] as String?;
            final fromArr = fromStation['arriveTime'] as String?;

            // 获取下车站的到达/发车时间
            final toArr = toStation['arriveTime'] as String?;
            final toDep = toStation['departTime'] as String?;

            // 上车站时间：优先发车时间，其次到达时间
            final selectedDepTime = fromDep ?? fromArr ?? '--:--';
            // 下车站时间：优先到达时间，其次发车时间
            final selectedArrTime = toArr ?? toDep ?? '--:--';

            // 计算跨天信息
            final fromDayDiff =
                int.tryParse(fromStation['DayDifference']?.toString() ?? '0') ??
                0;
            final toDayDiff =
                int.tryParse(toStation['DayDifference']?.toString() ?? '0') ??
                0;
            final dayOffset = (toDayDiff - fromDayDiff).abs();

            if (selectedDepTime != '--:--' && selectedArrTime != '--:--') {
              depTime = selectedDepTime;
              arrTime = selectedArrTime;
              runTime = _calcRunTime(
                selectedDepTime,
                selectedArrTime,
                dayOffset.toString(),
              );
            }
          }
        }
      }
    } else if (stopData.isNotEmpty) {
      // 车次查询模式：对于环线列车也使用完整运行时间
      final firstStop =
          stopData.cast<Map<String, dynamic>?>().firstWhere(
            (stop) => stop?['isFirst'] == true,
            orElse: () => null,
          ) ??
          stopData.first as Map<String, dynamic>?;

      final lastStop =
          stopData.cast<Map<String, dynamic>?>().firstWhere(
            (stop) => stop?['isLast'] == true,
            orElse: () => null,
          ) ??
          stopData.last as Map<String, dynamic>?;

      if (firstStop != null) {
        final firstArr = firstStop['arriveTime'] as String?;
        final firstDep = firstStop['departTime'] as String?;
        depTime = firstDep ?? firstArr ?? depTime;
      }
      if (lastStop != null) {
        final lastArr = lastStop['arriveTime'] as String?;
        final lastDep = lastStop['departTime'] as String?;
        arrTime = lastArr ?? lastDep ?? arrTime;
      }
      if (firstStop != null && lastStop != null) {
        final firstDep = firstStop['departTime'] as String?;
        final lastArr = lastStop['arriveTime'] as String?;
        if (firstDep != null && lastArr != null) {
          final firstDayDiff = _parseDayDifference(firstStop['DayDifference']);
          final lastDayDiff = _parseDayDifference(lastStop['DayDifference']);
          final totalDayDiff = lastDayDiff - firstDayDiff;

          runTime = _calcRunTime(firstDep, lastArr, totalDayDiff.toString());
        }
      }
    }

    final bool expired = _isExpired(index, item, isStation);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final referencePrice =
        item['ze_price'] ?? item['zy_price'] ?? item['swz_price'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${item['station_train_code'] ?? '--'}${isCircularLine ? ' (环线)' : ''}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: expired
                                        ? Colors.grey
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                if (expired) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '已过期',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['train_class_name'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: expired
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: expired
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                depTime,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: expired
                                      ? Colors.grey
                                      : (isDark ? Colors.white : Colors.black),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: expired
                                    ? Colors.grey.shade400
                                    : (isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                arrTime,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: expired
                                      ? Colors.grey
                                      : (isDark ? Colors.white : Colors.black),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                isStation ? '区间时长: $runTime' : '运行时长: $runTime',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: expired
                                      ? Colors.grey.shade400
                                      : (isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade600),
                                ),
                              ),
                              if (isStation &&
                                  referencePrice != null &&
                                  referencePrice != '--') ...[
                                const SizedBox(width: 12),
                                Text(
                                  '参考价: ¥$referencePrice',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: expired
                                        ? Colors.grey.shade400
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _stationRow(
                              '始发站',
                              "${_getStationName(item['from_station'])}站",
                              expired ? Colors.grey : Colors.green,
                            ),
                            const SizedBox(height: 8),
                            _stationRow(
                              '终点站',
                              "${_getStationName(item['to_station'])}站",
                              expired ? Colors.grey : Colors.red,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 24,
                        color: expired
                            ? Colors.grey.shade400
                            : (isDark
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade300),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 坐席信息
          if (isStation) _buildSeatList(item),

          const SizedBox(height: 20),

          Container(
            margin: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '信息仅供参考,合理安排时间行程\n买票请上12306,发货请上95306',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 16),
                if (trainCode.isNotEmpty && _selectedDate != null)
                  FutureBuilder<String>(
                    future: _getBenWu(trainCode, _formattedDate),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      } else if (snapshot.hasError) {
                        return Tooltip(
                          message: '',
                          child: Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red,
                          ),
                        );
                      } else if (snapshot.hasData && snapshot.data != '未知') {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 4),
                              Text(
                                snapshot.data!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.train,
                                size: 12,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '本务: 未知',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildStopSection(index, stopData, loading, isStation),

          const SizedBox(height: 20),

          Row(
            children: [
              // 添加车次按钮
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: expired
                      ? null
                      : () => _handleSelect(index, item, isStation),
                  icon: Icon(
                    Icons.add,
                    color: expired
                        ? Colors.grey.shade400
                        : Theme.of(context).colorScheme.surface,
                  ),
                  label: Text(
                    expired ? '车次已过期' : '添加此车次',
                    style: TextStyle(
                      color: expired
                          ? Colors.grey.shade400
                          : Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: expired
                        ? Colors.grey.shade300
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: expired
                        ? Colors.grey.shade400
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 查看线路走向图按钮
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openLineMap(item, isStation),
                  icon: const Icon(Icons.map, size: 20),
                  label: const Text('线路走向图'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeatList(Map<String, dynamic> item) {
    // 座位映射
    final Map<String, String> seatMapping = {
      'swz_num': '商务座',
      'zy_num': '一等座',
      'ze_num': '二等座',
      'gr_num': '高级软卧',
      'rw_num': '软卧',
      'yw_num': '硬卧',
      'rz_num': '软座',
      'yz_num': '硬座',
      'wz_num': '无座',
      'tz_num': '特等座',
      'gg_num': '优选一等座',
      'srrb_num': '动卧',
      'qt_num': '其他',
      'yb_num': '预留',
    };

    // 价格映射
    final Map<String, String> priceMapping = {
      'swz_num':
          item['swz_price']?.toString() ?? item['tz_price']?.toString() ?? '--',
      'zy_num': item['zy_price']?.toString() ?? '--',
      'ze_num': item['ze_price']?.toString() ?? '--',
      'gr_num': item['gr_price']?.toString() ?? '--',
      'rw_num':
          item['rw_price']?.toString() ??
          item['srrb_price']?.toString() ??
          '--',
      'yw_num': item['yw_price']?.toString() ?? '--',
      'rz_num': item['rz_price']?.toString() ?? '--',
      'yz_num': item['yz_price']?.toString() ?? '--',
      'wz_num':
          item['wz_price']?.toString() ?? item['ze_price']?.toString() ?? '--',
      'tz_num':
          item['tz_price']?.toString() ?? item['swz_price']?.toString() ?? '--',
      'qt_num': item['qt_price']?.toString() ?? '--',
      'gg_num':
          item['gg_price']?.toString() ?? item['zy_price']?.toString() ?? '--',
      'srrb_num':
          item['srrb_price']?.toString() ??
          item['rw_price']?.toString() ??
          '--',
      'yb_num': item['yb_price']?.toString() ?? '--',
    };

    final Map<String, dynamic> seatInfo = item['座位信息'] ?? {};

    // 座位类别配置
    final List<Map<String, dynamic>> seatCategories = [
      {
        'name': '商务/特等座',
        'seats': ['swz_num', 'tz_num', 'gg_num'],
        'color': Colors.red,
      },
      {
        'name': '一等/二等座',
        'seats': ['zy_num', 'ze_num', 'wz_num'],
        'color': Colors.blue,
      },
      {
        'name': '卧铺',
        'seats': ['gr_num', 'rw_num', 'yw_num', 'srrb_num'],
        'color': Colors.orange,
      },
      {
        'name': '坐席',
        'seats': ['rz_num', 'yz_num'],
        'color': Colors.green,
      },
      {
        'name': '其他',
        'seats': ['qt_num', 'yb_num'],
        'color': Colors.grey,
      },
    ];

    // 检查是否有任何可用的票
    final bool hasAvailableTickets = _hasAvailableTickets(seatInfo);

    // 检查是否有动卧
    final bool hasMotorSleeper =
        priceMapping['srrb_num'] != null &&
        priceMapping['srrb_num'] != '--' &&
        priceMapping['srrb_num'] != '0';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题部分
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(30),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_seat,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '坐席信息    仅供参考',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (!hasAvailableTickets) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '无票',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 座位信息内容
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: seatCategories
                  .map((category) {
                    final categorySeats = category['seats'] as List<String>;
                    final categoryColor = category['color'] as Color;

                    // 过滤：只显示有价格的座位类型
                    final seatsWithPrice = categorySeats.where((seatCode) {
                      final price = priceMapping[seatCode];
                      return price != null && price != '--' && price != '0';
                    }).toList();

                    // 特殊处理：卧铺类别中，软卧和动卧不能同时存在
                    if (category['name'] == '卧铺') {
                      final hasSoftSleeper = seatsWithPrice.contains('rw_num');
                      final hasMotorSleeper = seatsWithPrice.contains(
                        'srrb_num',
                      );

                      // 如果同时存在软卧和动卧，优先显示动卧，隐藏软卧
                      if (hasSoftSleeper && hasMotorSleeper) {
                        seatsWithPrice.remove('rw_num');
                      }
                    }

                    // 如果该类别下所有座位都没有价格，则不显示整个类别
                    if (seatsWithPrice.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 类别标题
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 16,
                              color: categoryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category['name'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 座位列表 - 只显示有价格的座位，无票的用红色标识
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: seatsWithPrice.map((seatCode) {
                            final seatName = seatMapping[seatCode] ?? seatCode;
                            final seatValue =
                                seatInfo[seatCode]?.toString() ?? '无票';
                            final seatPrice = priceMapping[seatCode] ?? '--';
                            final isAvailable = _isSeatAvailable(
                              seatInfo[seatCode],
                            );

                            // 清理座位值显示
                            String displayValue = seatValue;
                            if (!isAvailable) {
                              displayValue = '无票';
                            }

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: categoryColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: categoryColor.withAlpha(100),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    seatName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: categoryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayValue,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isAvailable
                                          ? categoryColor
                                          : Colors.red[300],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '¥$seatPrice',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: categoryColor.withAlpha(150),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  })
                  .where(
                    (categoryWidget) =>
                        categoryWidget is! SizedBox ||
                        categoryWidget.child != null,
                  )
                  .toList(),
            ),
          ),

          // 底部提示信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hasMotorSleeper
                        ? '动卧或部分列车有折扣，请上12306查看'
                        : '部分列车有折扣，请上12306查看',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasAvailableTickets(Map<String, dynamic> seatInfo) {
    return seatInfo.entries.any((entry) => _isSeatAvailable(entry.value));
  }

  bool _isSeatAvailable(dynamic value) {
    return value != null &&
        value != '无票' &&
        value != '无' &&
        value != '' &&
        value != '--' &&
        value != 'NULL' &&
        value != '0';
  }

  String _calcRunTime(String start, String end, String day) {
    try {
      if (start == '--:--' || end == '--:--') return '--';

      List<String> startParts = start.split(':');
      List<String> endParts = end.split(':');
      if (startParts.length != 2 || endParts.length != 2) return '--';

      int startHour = int.tryParse(startParts[0]) ?? 0;
      int startMin = int.tryParse(startParts[1]) ?? 0;
      int endHour = int.tryParse(endParts[0]) ?? 0;
      int endMin = int.tryParse(endParts[1]) ?? 0;

      // 将day转换为整数，day=0表示不跨天
      int dayOffset = int.tryParse(day) ?? 0;

      int startTotal = startHour * 60 + startMin;
      int endTotal = endHour * 60 + endMin;

      // 如果day>0，需要加上跨天的分钟数
      endTotal += dayOffset * 24 * 60;

      // 如果end时间仍然小于start时间，再补上24小时
      if (endTotal < startTotal) endTotal += 24 * 60;

      int total = endTotal - startTotal;
      int hours = total ~/ 60;
      int minutes = total % 60;

      if (hours > 0) {
        return '$hours小时$minutes分';
      } else {
        return '$minutes分';
      }
    } catch (e) {
      return '--';
    }
  }

  bool _isStationPassedSection(Map<String, dynamic> stop, DateTime trainDate) {
    final first = (stop['isFirst'] as bool?) ?? false;
    final last = (stop['isLast'] as bool?) ?? false;

    // 修复：安全转换 DayDifference
    final dayDiffValue = stop['DayDifference'];
    int dayDiff = 0;

    if (dayDiffValue != null) {
      if (dayDiffValue is int) {
        dayDiff = dayDiffValue;
      } else if (dayDiffValue is String) {
        dayDiff = int.tryParse(dayDiffValue) ?? 0;
      } else if (dayDiffValue is num) {
        dayDiff = dayDiffValue.toInt();
      }
    }

    if (first) {
      // 始发站判断发车时间
      final dep = stop['departTime'] as String?;
      return _isTimePassed(trainDate, dep, dayDiff, last);
    } else if (last) {
      // 终点站判断到达时间
      final arr = stop['arriveTime'] as String?;
      return _isTimePassed(trainDate, arr, dayDiff, last);
    } else {
      // 中间站优先判断到达时间
      final arr = stop['arriveTime'] as String?;
      final dep = stop['departTime'] as String?;
      if (arr != null && arr != '--:--') {
        return _isTimePassed(trainDate, arr, dayDiff, last);
      } else if (dep != null && dep != '--:--') {
        return _isTimePassed(trainDate, dep, dayDiff, last);
      }
    }
    return false;
  }

  bool _isStationPassed(Map<String, dynamic> stop, DateTime trainDate) {
    final first = (stop['isFirst'] as bool?) ?? false;
    final last = (stop['isLast'] as bool?) ?? false;
    final dayDiff = (stop['DayDifference'] as int?) ?? 0;

    if (first) {
      // 始发站判断发车时间
      final dep = stop['departTime'] as String?;
      return _isTimePassed(trainDate, dep, dayDiff, last);
    } else if (last) {
      // 终点站判断到达时间
      final arr = stop['arriveTime'] as String?;
      return _isTimePassed(trainDate, arr, dayDiff, last);
    } else {
      // 中间站优先判断到达时间
      final arr = stop['arriveTime'] as String?;
      final dep = stop['departTime'] as String?;
      if (arr != null && arr != '--:--') {
        return _isTimePassed(trainDate, arr, dayDiff, last);
      } else if (dep != null && dep != '--:--') {
        return _isTimePassed(trainDate, dep, dayDiff, last);
      }
    }
    return false;
  }

  bool _isExpired(int index, Map<String, dynamic> item, bool isStation) {
    // 获取车次日期
    final date = _selectedDate ?? DateTime.now();

    if (isStation) {
      return _isStationExpired(index, date);
    } else {
      return _isTrainExpired(index, date);
    }
  }

  bool _isStationExpired(int index, DateTime trainDate) {
    final stopData = _stationDetails[index] ?? [];
    if (stopData.isEmpty) return false;

    // 找到用户查询的车站
    final queryStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
      (stop) => stop?['isCurrent'] == true,
      orElse: () => null,
    );

    if (queryStop != null) {
      return _isStationPassed(queryStop, trainDate);
    }

    return false;
  }

  bool _isTrainExpired(int index, DateTime trainDate) {
    final stopData = _trainDetails[index] ?? [];
    if (stopData.isEmpty) return false;

    // 找到终点站
    final lastStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
      (stop) => stop?['isLast'] == true,
      orElse: () => null,
    );

    if (lastStop != null) {
      final arriveTime = lastStop['arriveTime'] as String?;
      final dayDiff = _parseDayDifference(lastStop['DayDifference']);
      return _isTimePassed(trainDate, arriveTime, dayDiff, true);
    }

    return false;
  }

  int _parseDayDifference(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();

    return 0;
  }

  Widget _stationRow(String label, String? name, Color iconColor) {
    return Row(
      children: [
        Icon(Icons.place, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              name ?? '--',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  void _openLineMap(Map<String, dynamic> item, bool isStation) {
    try {
      final currentIndex = isStation
          ? (_stationExpandedIndex ?? 0)
          : (_expandedIndex ?? 0);

      // 获取站点数据
      final stopData = isStation
          ? (_stationDetails[currentIndex] ?? [])
          : (_trainDetails[currentIndex] ?? []);

      if (stopData.isEmpty) {
        _showSnack('暂无站点信息，无法显示线路走向图');
        return;
      }

      // 使用现有的工厂方法创建 Journey 对象
      final journey = Journey.fromMapWithStations(
        trainInfo: item,
        date: _selectedDate ?? DateTime.now(),
        stationList: stopData,
        isStation: isStation,
        fromStation: isStation ? _fromName : null,
        toStation: isStation ? _toName : null,
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: LineMapDialog(journey: journey),
          ),
        ),
      );
    } catch (e) {
      _showSnack('打开线路走向图失败: $e');
    }
  }

  Widget _buildStopSection(
    int index,
    List<dynamic> stops,
    bool loading,
    bool isStation,
  ) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (stops.isEmpty) {
      return GestureDetector(
        onTap: () => _fetchDetails(index, isStation),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Center(child: Text('点击加载停站信息')),
        ),
      );
    }

    final item = isStation ? _stationResults[index] : _trainResults[index];
    final trainDate = _selectedDate ?? DateTime.now();

    return _buildStopList(stops, trainDate, item);
  }

  Widget _buildStopList(
    List<dynamic> stops,
    DateTime trainDate,
    Map<String, dynamic> journey, {
    bool isSelectable = false,
    Function(int)? onStationTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: stops.length,
        itemBuilder: (context, index) {
          final stop = stops[index] as Map<String, dynamic>;
          final no = stop['stationNo']?.toString() ?? '';
          final name = stop['stationName']?.toString() ?? '';
          final arr = stop['arriveTime']?.toString() ?? '--:--';
          final dep = stop['departTime']?.toString() ?? '--:--';
          final stay = int.tryParse(stop['stayTime']?.toString() ?? '0') ?? 0;
          final first = (stop['isFirst'] as bool?) ?? false;
          final last = (stop['isLast'] as bool?) ?? false;
          final terminal = first || last;

          // 安全转换 DayDifference
          final dayDiffValue = stop['DayDifference'];
          int dayDiff = 0;

          if (dayDiffValue != null) {
            if (dayDiffValue is int) {
              dayDiff = dayDiffValue;
            } else if (dayDiffValue is String) {
              dayDiff = int.tryParse(dayDiffValue) ?? 0;
            } else if (dayDiffValue is num) {
              dayDiff = dayDiffValue.toInt();
            }
          }

          bool passed = false;
          if (first) {
            passed = _isTimePassed(trainDate, dep, dayDiff, last);
          } else if (last) {
            passed = _isTimePassed(trainDate, arr, dayDiff, last);
          } else if (arr != '--:--') {
            passed = _isTimePassed(trainDate, arr, dayDiff, last);
          } else if (dep != '--:--') {
            passed = _isTimePassed(trainDate, dep, dayDiff, last);
          }

          // 修改这里：正确判断上车站和下车站
          bool isFromStation = false;
          bool isToStation = false;

          // 获取当前journey的fromStation和toStation
          final currentFromStation = _normalizeStationName(
            journey['from_station']?.toString() ?? '',
          );
          final currentToStation = _normalizeStationName(
            journey['to_station']?.toString() ?? '',
          );
          final currentStationName = _normalizeStationName(name);

          // 只有当车站名称完全匹配时才显示标识
          if (currentStationName == currentFromStation) {
            isFromStation = true;
          }
          if (currentStationName == currentToStation) {
            isToStation = true;
          }

          // 对于环线列车（始发站=终点站），比第一个站晚的相同名称站就是下车站
          bool isCircularLine = currentFromStation == currentToStation;
          if (isCircularLine && isFromStation && isToStation) {
            // 找到第一个出现的该车站
            int firstOccurrenceIndex = -1;
            for (int i = 0; i < stops.length; i++) {
              final station = stops[i] as Map<String, dynamic>;
              final stationName = _normalizeStationName(
                station['stationName']?.toString() ?? '',
              );
              if (stationName == currentStationName) {
                firstOccurrenceIndex = i;
                break;
              }
            }

            // 如果当前车站不是第一个出现的，就显示为下车站
            if (firstOccurrenceIndex != -1 && index > firstOccurrenceIndex) {
              isToStation = true;
              isFromStation = false;
            } else {
              isFromStation = true;
              isToStation = false;
            }
          }

          BorderRadius? getBorderRadius() {
            if (stops.length == 1) {
              return BorderRadius.circular(12);
            } else if (index == 0) {
              return const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              );
            } else if (index == stops.length - 1) {
              return const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              );
            }
            return null;
          }

          return GestureDetector(
            onTap: isSelectable
                ? () {
                    if (onStationTap != null) {
                      onStationTap(index);
                    }
                  }
                : null,
            child: Container(
              decoration: BoxDecoration(
                color: passed
                    ? Colors.orange.withAlpha(30)
                    : (isFromStation || isToStation
                          ? Colors.blue.withAlpha(30)
                          : terminal
                          ? Colors.green.withAlpha(30)
                          : Theme.of(context).colorScheme.surface),
                border: index < stops.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      )
                    : null,
                borderRadius: getBorderRadius(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 车站编号圆圈
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: passed
                            ? Colors.orange
                            : (isFromStation || isToStation
                                  ? Colors.blue
                                  : terminal
                                  ? Colors.green
                                  : Colors.black),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        no,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      "$name站",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    if (passed) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          '已过时',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (dayDiff > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.purple.withAlpha(76)
                                              : Colors.purple.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '+$dayDiff天',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // 车站标识 - 修改这里
                              if (isFromStation) ...[
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '上',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (isToStation) ...[
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '下',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _timeBlock(
                                '到达',
                                first ? '--' : arr,
                                passed,
                                first,
                              ),
                              if (stay > 0)
                                Column(
                                  children: [
                                    Text(
                                      '停站',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: passed
                                              ? Colors.orange.shade700
                                              : (isDark
                                                    ? Colors.green.shade300
                                                    : Colors.green.shade600),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$stay分',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: passed
                                                ? Colors.orange.shade700
                                                : (isDark
                                                      ? Colors.green.shade300
                                                      : Colors.green.shade600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              _timeBlock('发车', last ? '--' : dep, passed, last),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _timeBlock(String label, String time, bool passed, bool isTerminal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: passed
                ? Colors.orange.shade700
                : isTerminal
                ? (isDark ? Colors.green.shade300 : Colors.green.shade600)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  bool _isTimePassed(
    DateTime trainDate,
    String? timeString,
    int dayDiff,
    bool isLast,
  ) {
    if (timeString == null || timeString.isEmpty || timeString == '--:--') {
      return false;
    }

    try {
      // 解析时间字符串
      final timeParts = timeString.split(':');
      if (timeParts.length < 2) return false;

      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      // 计算列车实际时间
      // trainDate 是用户选择的日期
      // dayDiff 是相对于发车日的天数差
      final stationDateTime = DateTime(
        trainDate.year,
        trainDate.month,
        trainDate.day + dayDiff, // 加上天数差
        hour,
        minute,
      );

      // 获取当前时间
      final now = DateTime.now();

      // 直接比较：列车时间是否已经过去了
      return stationDateTime.isBefore(now);
    } catch (e) {
      return false;
    }
  }

  void _handleSelect(
    int index,
    Map<String, dynamic> train,
    bool isStation,
  ) async {
    if (!_hasDetails(index, isStation)) {
      await _fetchDetails(index, isStation);
    }

    if (mounted) {
      if (isStation) {
        // 车站查询模式保持不变
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('添加行程'),
            content: Text(
              '是否添加 ${train['station_train_code']} 次列车？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _addJourney(index, train, true);
                },
                child: const Text('添加'),
              ),
            ],
          ),
        );
      } else {
        _showStationRangeSelector(index, train);
      }
    }
  }

  bool _hasDetails(int index, bool isStation) {
    if (isStation) {
      return _stationDetails.containsKey(index) &&
          (_stationDetails[index]?.isNotEmpty ?? false);
    } else {
      return _trainDetails.containsKey(index) &&
          (_trainDetails[index]?.isNotEmpty ?? false);
    }
  }

  void _showStationRangeSelector(int index, Map<String, dynamic> train) {
    final stopData = _trainDetails[index] ?? [];
    final trainDate = _selectedDate ?? DateTime.now();

    if (stopData.isEmpty) {
      _showSnack('站点信息未加载，请稍后重试');
      return;
    }

    String? selectedFrom;
    String? selectedTo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void handleStationTap(int index) {
            final station = stopData[index] as Map<String, dynamic>;
            final stationName = station['stationName']?.toString() ?? '';

            if (_isStationPassedSection(station, trainDate)) {
              _showSnack('该车站已过期，无法选择');
              return;
            }

            setDialogState(() {
              if (selectedFrom == null) {
                // 第一次选择：选择上车站
                selectedFrom = stationName;
                selectedTo = null;
              } else if (selectedTo == null) {
                // 第二次选择：选择下车站（必须在上车站之后）
                final fromIndex = stopData.indexWhere(
                  (s) =>
                      (s as Map<String, dynamic>)['stationName'] ==
                      selectedFrom,
                );

                if (index > fromIndex) {
                  // 下车站在上车站之后，允许选择
                  selectedTo = stationName;
                } else {
                  // 下车站不能在上车站之前，显示提示
                  _showSnack('下车站必须在上车站之后');
                }
              } else {
                // 已经选择了两个车站，重新选择上车站
                selectedFrom = stationName;
                selectedTo = null;
              }
            });
          }

          bool isStationSelectable(int index) {
            final station = stopData[index] as Map<String, dynamic>;

            if (_isStationPassedSection(station, trainDate)) {
              return false;
            }

            if (selectedFrom == null) {
              // 还没有选择上车站，所有未过期车站都可选为上车站
              return true;
            } else if (selectedTo == null) {
              // 已经选择了上车站，下车站必须在上车站之后且未过期
              final fromIndex = stopData.indexWhere(
                (s) =>
                    (s as Map<String, dynamic>)['stationName'] == selectedFrom,
              );
              return index > fromIndex;
            } else {
              // 已经选择了两个车站，所有未过期车站都可重新选择
              return true;
            }
          }

          // 判断车站是否被选择
          bool isStationSelected(int index) {
            final station = stopData[index] as Map<String, dynamic>;
            final stationName = station['stationName']?.toString() ?? '';
            return stationName == selectedFrom || stationName == selectedTo;
          }

          bool isStationExpired(int index) {
            final station = stopData[index] as Map<String, dynamic>;
            return _isStationPassedSection(station, trainDate);
          }

          // 判断是上车站还是下车站
          String getStationSelectionType(int index) {
            final station = stopData[index] as Map<String, dynamic>;
            final stationName = station['stationName']?.toString() ?? '';
            if (stationName == selectedFrom) return 'from';
            if (stationName == selectedTo) return 'to';
            return 'none';
          }

          return AlertDialog(
            title: Text('选择乘车区间 - ${train['station_train_code']}'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 选择状态提示
                    if (selectedFrom != null || selectedTo != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              selectedFrom ?? '请选择上车站',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selectedFrom != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.grey,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward, size: 16),
                            ),
                            Text(
                              selectedTo ?? '请选择下车站',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selectedTo != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 停站列表
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: stopData.length,
                        itemBuilder: (context, index) {
                          final stop = stopData[index] as Map<String, dynamic>;
                          final no = stop['stationNo']?.toString() ?? '';
                          final name = stop['stationName']?.toString() ?? '';
                          final arr = stop['arriveTime']?.toString() ?? '--:--';
                          final dep = stop['departTime']?.toString() ?? '--:--';
                          final stay =
                              int.tryParse(
                                stop['stayTime']?.toString() ?? '0',
                              ) ??
                              0;

                          final isSelected = isStationSelected(index);
                          final isExpired = isStationExpired(index);
                          final isSelectable = isStationSelectable(index);
                          final selectionType = getStationSelectionType(index);

                          final dayDiffValue = stop['DayDifference'];
                          int dayDiff = 0;

                          if (dayDiffValue != null) {
                            if (dayDiffValue is int) {
                              dayDiff = dayDiffValue;
                            } else if (dayDiffValue is String) {
                              dayDiff = int.tryParse(dayDiffValue) ?? 0;
                            } else if (dayDiffValue is num) {
                              dayDiff = dayDiffValue.toInt();
                            }
                          }

                          // 在车站列表项的构建中添加跨天显示
                          return GestureDetector(
                            onTap: isSelectable
                                ? () => handleStationTap(index)
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? Colors.grey.withAlpha(30)
                                    : isSelected
                                    ? Colors.blue.withAlpha(30)
                                    : Colors.transparent,
                                border: index < stopData.length - 1
                                    ? Border(
                                        bottom: BorderSide(
                                          color: Theme.of(context).dividerColor,
                                          width: 0.5,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 车站编号
                                    Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isExpired
                                            ? Colors.orange
                                            : isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        no,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isExpired
                                                            ? Colors.orange[200]
                                                            : isSelectable
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                            : Colors.grey,
                                                      ),
                                                    ),

                                                    // 添加跨天标识
                                                    if (dayDiff > 0)
                                                      Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              left: 8,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.purple
                                                              .withAlpha(76),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          '+$dayDiff天',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
                                                        ),
                                                      ),

                                                    if (isExpired)
                                                      Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              left: 8,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: const Text(
                                                          '已过',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              // 选择标识
                                              if (selectionType == 'from')
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    '上车站',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              if (selectionType == 'to')
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    '下车站',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '到达: $arr',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isExpired
                                                      ? Colors.grey
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                              if (stay > 0)
                                                Text(
                                                  '停站: $stay分',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isExpired
                                                        ? Colors.grey
                                                        : Colors.grey.shade600,
                                                  ),
                                                ),
                                              Text(
                                                '发车: $dep',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isExpired
                                                      ? Colors.grey
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // 操作提示
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        selectedFrom == null
                            ? '请点击未过期的车站选择上车站'
                            : selectedTo == null
                            ? '请点击在上车站之后的未过期车站选择下车站'
                            : '确认添加 $selectedFrom → $selectedTo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              if (selectedFrom != null)
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedFrom = null;
                      selectedTo = null;
                    });
                  },
                  child: const Text('重新选择'),
                ),
              ElevatedButton(
                onPressed: (selectedFrom != null && selectedTo != null)
                    ? () {
                        Navigator.of(context).pop();
                        _addJourney(
                          index,
                          train,
                          false,
                          fromStation: selectedFrom,
                          toStation: selectedTo,
                        );
                      }
                    : null,
                child: const Text('确认添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addJourney(
    int index,
    Map<String, dynamic> train,
    bool isStation, {
    String? fromStation,
    String? toStation,
  }) {
    if (_isExpired(index, train, isStation)) {
      _showSnack('车次已过期，无法添加');
      return;
    }

    List<dynamic> stationList;
    if (isStation) {
      stationList = _stationDetails[index] ?? [];
    } else {
      stationList = _trainDetails[index] ?? [];
    }

    if (stationList.isEmpty) {
      _showSnack('无法获取车次详细信息');
      return;
    }

    DateTime actualDate = _selectedDate!;

    // 修复：确保正确传递用户选择的站点
    String actualFromStation;
    String actualToStation;

    if (isStation) {
      // 车站查询模式：使用用户选择的站点
      actualFromStation = _fromName ?? train['from_station']?.toString() ?? '';
      actualToStation = _toName ?? train['to_station']?.toString() ?? '';
    } else {
      // 车次查询模式：使用用户选择的区间或默认站点
      actualFromStation =
          fromStation ?? train['from_station']?.toString() ?? '';
      actualToStation = toStation ?? train['to_station']?.toString() ?? '';
    }

    // 验证站点是否存在
    final fromExists = stationList.any(
      (s) =>
          (s as Map<String, dynamic>)['stationName']?.toString() ==
          actualFromStation,
    );
    final toExists = stationList.any(
      (s) =>
          (s as Map<String, dynamic>)['stationName']?.toString() ==
          actualToStation,
    );

    if (!fromExists || !toExists) {
      _showSnack('选择的站点不存在于该车次中');
      return;
    }

    // 计算实际日期（考虑跨天）
    if (!isStation && fromStation != null) {
      final fromStationData = stationList
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (stop) => stop?['stationName'] == fromStation,
            orElse: () => null,
          );

      if (fromStationData != null) {
        final dayDiffValue = fromStationData['DayDifference'];
        int dayDiff = 0;

        if (dayDiffValue != null) {
          if (dayDiffValue is int) {
            dayDiff = dayDiffValue;
          } else if (dayDiffValue is String) {
            dayDiff = int.tryParse(dayDiffValue) ?? 0;
          } else if (dayDiffValue is num) {
            dayDiff = dayDiffValue.toInt();
          }
        }

        actualDate = actualDate.add(Duration(days: dayDiff));
      }
    }

    // 显示座位选择弹窗
    _showSeatSelectionDialog(
      train: train,
      actualDate: actualDate,
      stationList: stationList,
      isStation: isStation,
      actualFromStation: actualFromStation,
      actualToStation: actualToStation,
    );
  }

  // 座位选择弹窗
  void _showSeatSelectionDialog({
    required Map<String, dynamic> train,
    required DateTime actualDate,
    required List<dynamic> stationList,
    required bool isStation,
    required String actualFromStation,
    required String actualToStation,
  }) {
    String? selectedSeatType = 'wz_num';
    String seatInfo = ''; // 改为字符串类型
    final TextEditingController seatInfoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('选择座位'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 座位类型选择器
                DropdownButtonFormField<String>(
                  initialValue: selectedSeatType,
                  decoration: const InputDecoration(
                    labelText: '座位类型',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'swz_num',
                      child: Text('商务座 (${train['swz_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'zy_num',
                      child: Text('一等座 (${train['zy_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'ze_num',
                      child: Text('二等座 (${train['ze_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'gr_num',
                      child: Text('高级软卧 (${train['gr_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'rw_num',
                      child: Text('软卧 (${train['rw_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'yw_num',
                      child: Text('硬卧 (${train['yw_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'rz_num',
                      child: Text('软座 (${train['rz_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'yz_num',
                      child: Text('硬座 (${train['yz_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'wz_num',
                      child: Text('无座 (${train['wz_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'tz_num',
                      child: Text('特等座 (${train['tz_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'gg_num',
                      child: Text('优选一等座 (${train['gg_num'] ?? '--'})'),
                    ),
                    DropdownMenuItem(
                      value: 'srrb_num',
                      child: Text('动卧 (${train['srrb_num'] ?? '--'})'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedSeatType = value;
                      // 如果选择无座，清空座位信息
                      if (value == 'wz_num') {
                        seatInfo = '';
                        seatInfoController.text = '';
                      } else if (seatInfo.isEmpty) {
                        // 可以选择设置默认提示文本
                        seatInfoController.text = '';
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // 座位信息输入（无座时禁用）
                TextFormField(
                  controller: seatInfoController,
                  enabled: selectedSeatType != 'wz_num',
                  decoration: InputDecoration(
                    labelText: '座位信息',
                    hintText: '例如: 01车12F',
                    border: const OutlineInputBorder(),
                    suffixIcon: selectedSeatType != 'wz_num'
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                seatInfo = '';
                                seatInfoController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      seatInfo = value;
                    });
                  },
                ),

                // 添加提示文本
                if (selectedSeatType != 'wz_num')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '请输入座位信息，如: 01车12F、02车厢05A等',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedSeatType == null) {
                    _showSnack('请选择座位类型');
                    return;
                  }

                  if (selectedSeatType != 'wz_num' && seatInfo.isEmpty) {
                    _showSnack('请输入座位信息');
                    return;
                  }

                  // 创建行程并保存
                  _createAndSaveJourney(
                    train: train,
                    actualDate: actualDate,
                    stationList: stationList,
                    isStation: isStation,
                    actualFromStation: actualFromStation,
                    actualToStation: actualToStation,
                    seatType: selectedSeatType!,
                    seatInfo: seatInfo, // 传递文本格式的座位信息
                  );

                  Navigator.pop(context);
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 创建并保存行程
  void _createAndSaveJourney({
    required Map<String, dynamic> train,
    required DateTime actualDate,
    required List<dynamic> stationList,
    required bool isStation,
    required String actualFromStation,
    required String actualToStation,
    required String seatType,
    required String seatInfo, // 改为字符串参数
  }) {
    final journey = Journey.fromMapWithStations(
      trainInfo: train,
      date: actualDate,
      stationList: stationList,
      isStation: isStation,
      fromStation: actualFromStation,
      toStation: actualToStation,
      seatType: seatType,
      seatInfo: seatInfo, // 传递座位信息文本
    );

    if (mounted) {
      Provider.of<JourneyProvider>(context, listen: false).addJourney(journey);

      // 显示添加成功的提示
      final seatTypeNames = {
        'swz_num': '商务座',
        'zy_num': '一等座',
        'ze_num': '二等座',
        'gr_num': '高级软卧',
        'rw_num': '软卧',
        'yw_num': '硬卧',
        'rz_num': '软座',
        'yz_num': '硬座',
        'wz_num': '无座',
        'tz_num': '特等座',
        'gg_num': '优选一等座',
        'srrb_num': '动卧',
      };

      final seatName = seatTypeNames[seatType] ?? '未知座位';
      final infoText = seatType == 'wz_num' ? '' : ' ($seatInfo)';

      _showSnack(
        '已添加 ${train['station_train_code']} 次列车 '
        '($actualFromStation -> $actualToStation) '
        '$seatName$infoText',
      );

      // 延迟返回主页
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }
}
