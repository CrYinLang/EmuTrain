// loco_search_page.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';

// ==================== 配属段 → 路局图标 映射 ====================
class LocoDepotMapper {
  static String? getIconName(String depot) {
    if (depot.isEmpty) return null;

    if (depot.startsWith('上局') || depot.startsWith('三新铁路')) {
      return '上海铁路局';
    }
    if (depot.startsWith('乌局')) return '乌鲁木齐铁路局';
    if (depot.startsWith('京局')) return '北京铁路局';
    if (depot.startsWith('兰局')) return '兰州铁路局';
    if (depot.startsWith('南局')) return '南昌铁路局';
    if (depot.startsWith('宁局')) return '南宁铁路局';
    if (depot.startsWith('呼局') || depot == '集通大段') return '呼和浩特铁路局';
    if (depot.startsWith('哈局')) return '哈尔滨铁路局';
    if (depot.startsWith('太局') || depot == '晋神铁路' || depot == '潞安公司') {
      return '太原铁路局';
    }
    if (depot.startsWith('成局')) return '成都铁路局';
    if (depot.startsWith('昆局')) return '昆明铁路局';
    if (depot.startsWith('武局')) return '武汉铁路局';
    if (depot.startsWith('沈局') || depot == '沈阳铁博' || depot == '阜新矿') {
      return '沈阳铁路局';
    }
    if (depot.startsWith('济局') ||
        depot == '德大铁路' ||
        depot == '梁邹公司' ||
        depot == '金台铁路') {
      return '济南铁路局';
    }
    if (depot.startsWith('西局') || depot == '西延公司') return '西安铁路局';
    if (depot.startsWith('郑局')) return '郑州铁路局';
    if (depot.startsWith('广铁') ||
        depot == '广州港' ||
        depot == '金温温段' ||
        depot == '广东城际' ||
        depot == '广通铁运') {
      return '广州铁路局';
    }
    if (depot.startsWith('青藏') || depot == '青藏宁段' || depot == '青藏格段') {
      return '青藏铁路局';
    }

    if (depot == '专运处' || depot == '铁博' || depot == '铁科院') {
      return '国铁集团';
    }
    if (depot.contains('香港')) return '香港铁路有限公司';

    return null;
  }

  static String getFullName(String depot) {
    final icon = getIconName(depot);
    return icon ?? depot;
  }
}

// ==================== 数据模型 ====================
class LocoResult {
  final String model;
  final String number;
  final String depot;
  final double? score;
  final int? rank;

  LocoResult({
    required this.model,
    required this.number,
    required this.depot,
    this.score,
    this.rank,
  });
}

// ==================== 主页面 ====================
class LocoSearchPage extends StatefulWidget {
  const LocoSearchPage({super.key});

  @override
  State<LocoSearchPage> createState() => _LocoSearchPageState();
}

class _LocoSearchPageState extends State<LocoSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _searchType = 'locoId'; // locoId | depot | carType

  bool _isLoading = false;
  String _errorMsg = '';

  List<Map<String, dynamic>> _locoData = [];

  // 分页
  List<Map<String, dynamic>> _allPageRecords = [];
  final List<LocoResult> _results = [];
  int _currentPage = 1;
  final int _pageSize = 10;
  int _totalResults = 0;
  String? _currentSearchLabel;
  bool _loadingPage = false;

  late TextEditingController _pageController;

  int get _totalPages => (_totalResults / _pageSize).ceil();

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(text: '1');
    _loadLocoData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadLocoData() async {
    try {
      final List<Map<String, dynamic>> flat = await DataFileHelper.loadLocos();
      if (mounted) {
        setState(() => _locoData = flat);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = '加载机车数据失败: $e');
      }
    }
  }

  void _resetPagination() {
    _currentPage = 1;
    _totalResults = 0;
    _currentSearchLabel = null;
    _allPageRecords = [];
    _loadingPage = false;
    _pageController.text = '1';
  }

  List<String> _getAllModels() {
    return _locoData.map((r) => r['model'] as String).toSet().toList()..sort();
  }

  List<String> _getAllDepots() {
    return _locoData
        .map((r) => r['depot'] as String)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  // ==================== 搜索入口 ====================
  void _performSearch() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMsg = '请输入查询内容');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _results.clear();
      _resetPagination();
    });

    switch (_searchType) {
      case 'locoId':
        _searchByLocoId(input);
        break;
      case 'depot':
        _searchByDepot(input);
        break;
      case 'carType':
        _searchByModel(input);
        break;
    }
  }

  // ==================== 车号搜索（模糊 + 评分） ====================
  void _searchByLocoId(String input) {
    final cleanInput = input
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();

    final List<MapEntry<Map<String, dynamic>, double>> scored = [];

    for (final record in _locoData) {
      final model = record['model'] as String;
      final number = record['number'] as String;
      final full = '${model.toUpperCase()}$number';

      double score = 0;

      if (cleanInput == full) {
        score = 1.0;
      } else if (full.endsWith(cleanInput)) {
        score = 0.95;
      } else if (full.contains(cleanInput)) {
        score = 0.8;
      } else if (number.endsWith(cleanInput)) {
        score = 0.75;
      } else if (number.contains(cleanInput)) {
        score = 0.6;
      } else if (model.toUpperCase().startsWith(cleanInput) ||
          cleanInput.startsWith(model.toUpperCase())) {
        score = 0.3;
      }

      if (score > 0) scored.add(MapEntry(record, score));
    }

    if (scored.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = '未找到匹配的机车车号';
      });
      return;
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    final topScore = scored.first.value;
    // 只保留与最高分同分段的结果，最多10条，避免低分误匹配
    final top = scored
        .where((e) => e.value >= topScore - 0.05)
        .take(10)
        .toList();

    setState(() {
      _results.addAll(
        top.asMap().entries.map(
          (e) => LocoResult(
            model: e.value.key['model'],
            number: e.value.key['number'],
            depot: e.value.key['depot'],
            score: e.value.value,
            rank: e.key + 1,
          ),
        ),
      );
      _totalResults = _results.length;
      _currentSearchLabel = input;
      _isLoading = false;
    });
  }

  // ==================== 配属段搜索 ====================
  void _searchByDepot(String input) {
    final pattern = input.trim().toLowerCase();
    final matched = _locoData.where((r) {
      return (r['depot'] as String).toLowerCase().contains(pattern);
    }).toList();

    if (matched.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = '未找到配属段 "$input" 的机车';
      });
      return;
    }

    matched.sort((a, b) {
      final mc = (a['model'] as String).compareTo(b['model'] as String);
      return mc != 0
          ? mc
          : (a['number'] as String).compareTo(b['number'] as String);
    });

    _allPageRecords = matched;
    _totalResults = matched.length;
    _currentSearchLabel = input;
    _loadPage(1);
  }

  // ==================== 车型搜索 ====================
  void _searchByModel(String input) {
    final pattern = input.trim().toUpperCase();
    final matched = _locoData
        .where((r) => (r['model'] as String).toUpperCase() == pattern)
        .toList();

    if (matched.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = '未找到车型 "$input"';
      });
      return;
    }

    matched.sort(
      (a, b) => (a['number'] as String).compareTo(b['number'] as String),
    );

    _allPageRecords = matched;
    _totalResults = matched.length;
    _currentSearchLabel = pattern;
    _loadPage(1);
  }

  // ==================== 分页 ====================
  void _loadPage(int page) {
    if (_allPageRecords.isEmpty || page < 1 || page > _totalPages) return;

    setState(() => _loadingPage = true);

    final start = (page - 1) * _pageSize;
    final end = min(page * _pageSize, _allPageRecords.length);
    final pageRecords = _allPageRecords.sublist(start, end);

    final newResults = pageRecords.map((r) {
      return LocoResult(
        model: r['model'] as String,
        number: r['number'] as String,
        depot: r['depot'] as String,
      );
    }).toList();

    setState(() {
      _results.clear();
      _results.addAll(newResults);
      _currentPage = page;
      _pageController.text = page.toString();
      _loadingPage = false;
      _isLoading = false;
    });
  }

  void _goToPage(int page) {
    if (page == _currentPage ||
        _loadingPage ||
        page < 1 ||
        page > _totalPages) {
      _pageController.text = _currentPage.toString();
      return;
    }
    _loadPage(page);
  }

  // ==================== 分页控件（与 EMU 一致） ====================
  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 && !_loadingPage
                ? () => _goToPage(_currentPage - 1)
                : null,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _pageController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (v) {
                final p = int.tryParse(v);
                if (p != null) _goToPage(p);
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '/ $_totalPages 页（共 $_totalResults 条）',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages && !_loadingPage
                ? () => _goToPage(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  // ==================== 结果卡片（与 EMU 高度一致） ====================
  Widget _buildResultCard(LocoResult result) {
    final iconName = LocoDepotMapper.getIconName(result.depot);
    final settings = Provider.of<AppSettings>(context, listen: false);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 机车图标
                _buildLocoIcon(result.model),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${result.model}-${result.number}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (result.score != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: result.score!.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: result.score! >= 0.8
                                        ? Colors.green
                                        : result.score! >= 0.5
                                        ? Colors.orange
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(result.score! * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: result.score! >= 0.8
                                    ? Colors.green
                                    : result.score! >= 0.5
                                    ? Colors.orange
                                    : Colors.red,
                              ),
                            ),
                            if (result.rank != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${result.rank!}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // 路局图标
                if (settings.showBureauIcons && iconName != null)
                  _buildBureauIcon(iconName)
                else
                  const SizedBox(width: 32, height: 32),
              ],
            ),
            const SizedBox(height: 12),
            if (result.depot.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildInfoRow('配属段', result.depot)],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocoIcon(String model) {
    final assetPath = 'assets/icon/train/$model.png';
    return FutureBuilder<bool>(
      future: _checkAssetExists(assetPath),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.data == true) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              assetPath,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _fallbackTrainIcon(),
            ),
          );
        }
        return _fallbackTrainIcon();
      },
    );
  }

  Widget _fallbackTrainIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.directions_railway, size: 20, color: Colors.grey),
    );
  }

  Widget _buildBureauIcon(String iconName) {
    final assetPath = 'assets/icon/bureau/$iconName.png';
    return FutureBuilder<bool>(
      future: _checkAssetExists(assetPath),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.data == true) {
          return Image.asset(
            assetPath,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox(width: 32, height: 32),
          );
        }
        return const SizedBox(width: 32, height: 32);
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // ==================== 搜索类型选择器 ====================
  Widget _buildSearchTypeSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'locoId',
          label: Text('车号查询'),
          icon: Icon(Icons.confirmation_number),
        ),
        ButtonSegment(
          value: 'depot',
          label: Text('配属段查询'),
          icon: Icon(Icons.business),
        ),
        ButtonSegment(
          value: 'carType',
          label: Text('车型查询'),
          icon: Icon(Icons.category),
        ),
      ],
      selected: {_searchType},
      onSelectionChanged: (s) {
        setState(() {
          _searchType = s.first;
          _results.clear();
          _errorMsg = '';
          _resetPagination();
        });
      },
      style: SegmentedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        selectedBackgroundColor: Theme.of(context).colorScheme.primary,
        selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  // ==================== 空状态 ====================
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            _searchType == 'depot'
                ? Icons.business
                : _searchType == 'carType'
                ? Icons.category
                : Icons.train,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _searchType == 'locoId'
                ? '请输入机车车号进行查询\n（例如：DF11-0001 或 0001）'
                : _searchType == 'depot'
                ? '请输入配属段进行查询\n（例如：京局京段）'
                : '请输入车型进行查询（例如：DF11）',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          if (_searchType == 'carType') ...[
            const Text('所有可查车型:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: _getAllModels().map((model) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = model;
                    _performSearch();
                  },
                  child: Chip(label: Text(model)),
                );
              }).toList(),
            ),
          ],
          if (_searchType == 'depot') ...[
            const Text('所有配属段:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: _getAllDepots().map((depot) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = depot;
                    _performSearch();
                  },
                  child: Chip(label: Text(depot)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPaged = _searchType == 'depot' || _searchType == 'carType';
    final totalCount = _totalResults > 0 ? _totalResults : _results.length;
    final displayedCount = _results.length;

    return Scaffold(
      appBar: AppBar(title: const Text('机车查询')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 搜索框 + 查询按钮
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: _searchType == 'locoId'
                          ? '输入机车车号'
                          : _searchType == 'depot'
                          ? '输入配属段'
                          : '输入车型',
                      hintText: _searchType == 'locoId'
                          ? '如: DF11-0001 或 0001'
                          : _searchType == 'depot'
                          ? '如: 京局京段'
                          : '如: DF11',
                      border: const OutlineInputBorder(),
                      filled: true,
                    ),
                    onSubmitted: (_) => _performSearch(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _performSearch,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_isLoading ? '查询中...' : '查询'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 搜索类型选择器
            _buildSearchTypeSelector(),
            const SizedBox(height: 20),

            if (_isLoading && _results.isEmpty)
              const Center(child: CircularProgressIndicator()),

            if (_errorMsg.isNotEmpty)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_errorMsg)),
                      IconButton(
                        onPressed: () => setState(() => _errorMsg = ''),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),

            if (_results.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            isPaged
                                ? '$_currentSearchLabel 共 $totalCount 条（当前 $displayedCount 条）'
                                : '共找到 $totalCount 条结果',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '清除结果',
                    onPressed: () => setState(() {
                      _results.clear();
                      _controller.clear();
                      _errorMsg = '';
                      _resetPagination();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (isPaged) _buildPaginationControls(),

              for (final r in _results) _buildResultCard(r),

              if (_loadingPage)
                const Center(child: CircularProgressIndicator()),
            ],

            const SizedBox(height: 40),

            if (!_isLoading && _errorMsg.isEmpty && _results.isEmpty)
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }
}
