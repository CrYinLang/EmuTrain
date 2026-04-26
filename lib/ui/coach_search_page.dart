// coach_search_page.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

// ==================== 数据模型 ====================

class CoachRecord {
  final String model;
  final String number;
  final String depot;
  final String? capacity;
  final String? bogie;
  final String? manufacturer;

  CoachRecord({
    required this.model,
    required this.number,
    required this.depot,
    this.capacity,
    this.bogie,
    this.manufacturer,
  });

  factory CoachRecord.fromJson(Map<String, dynamic> json) {
    return CoachRecord(
      model: json['型号']?.toString() ?? '',
      number: json['车号']?.toString() ?? '',
      depot: json['现配属']?.toString() ?? '',
      capacity: json['定员']?.toString(),
      bogie: json['转向架']?.toString(),
      manufacturer: json['制造厂']?.toString(),
    );
  }
}

class CoachSearchResult {
  final CoachRecord record;
  final double? score;
  final int? rank;
  final String queryTime;

  CoachSearchResult({
    required this.record,
    this.score,
    this.rank,
    required this.queryTime,
  });
}

// ==================== 主页面 ====================

class CoachSearchPage extends StatefulWidget {
  const CoachSearchPage({super.key});

  @override
  State<CoachSearchPage> createState() => _CoachSearchPageState();
}

class _CoachSearchPageState extends State<CoachSearchPage> {
  final TextEditingController _controller = TextEditingController();
  late TextEditingController _pageController;

  String _searchType = 'number'; // 'number' | 'depot' | 'model'
  bool _isLoading = false;
  String _errorMsg = '';

  // 原始数据
  List<CoachRecord> _allRecords = [];

  // 搜索结果
  final List<CoachSearchResult> _searchResults = [];

  // 分页（配属段/车型查询用）
  List<CoachRecord> _pagedSource = [];
  int _currentPage = 1;
  final int _pageSize = 7;
  int _totalResults = 0;
  bool _loadingPage = false;
  String? _currentSearchLabel;

  int get _totalPages => (_totalResults / _pageSize).ceil();

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(text: '1');
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ==================== 数据加载 ====================

  Future<void> _loadData() async {
    try {
      final records = await DataFileHelper.loadCoaches();
      if (mounted) {
        setState(() => _allRecords = records);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = '加载数据失败: $e');
      }
    }
  }

  // ==================== 工具函数 ====================

  String _cleanString(String input) =>
      input.replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fff]'), '').toUpperCase();

  List<String> _getAllModels() {
    final models = _allRecords
        .map((r) => r.model)
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    models.sort();
    return models;
  }

  List<String> _getAllDepots() {
    final depots = _allRecords
        .map((r) => r.depot)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();
    depots.sort();
    return depots;
  }

  void _resetPagination() {
    _currentPage = 1;
    _totalResults = 0;
    _currentSearchLabel = null;
    _pagedSource = [];
    _loadingPage = false;
    _pageController.text = '1';
  }

  // ==================== 搜索逻辑 ====================

  void _performSearch() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMsg = '请输入查询内容');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _searchResults.clear();
      _resetPagination();
    });

    try {
      if (_searchType == 'number') {
        _searchByNumber(input);
      } else if (_searchType == 'depot') {
        _searchByDepot(input);
      } else if (_searchType == 'model') {
        _searchByModel(input);
      }
    } catch (e) {
      setState(() => _errorMsg = '查询失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---- 车号查询 ----
  void _searchByNumber(String input) {
    final cleaned = _cleanString(input);
    if (cleaned.length < 4) {
      setState(() {
        _isLoading = false;
        _errorMsg = '请输入至少4位有效字符';
      });
      return;
    }

    final queryTime = DateTime.now().toLocal().toString().substring(0, 19);

    // 精确匹配：车号完全包含输入，或输入完全包含车号
    final Map<CoachRecord, double> scored = {};
    for (final record in _allRecords) {
      final cleanNum = _cleanString(record.number);
      final cleanModel = _cleanString(record.model);
      final full = '$cleanModel$cleanNum';

      double score = 0.0;
      if (full == cleaned || cleanNum == cleaned) {
        score = 1.0;
      } else if (cleanNum.endsWith(cleaned) || cleaned.endsWith(cleanNum)) {
        score = 0.9;
      } else if (cleanNum.contains(cleaned) || cleaned.contains(cleanNum)) {
        score = 0.7;
      } else {
        // 末四位匹配
        final inputDigits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
        final numDigits = cleanNum.replaceAll(RegExp(r'[^0-9]'), '');
        if (inputDigits.length >= 4 && numDigits.length >= 4) {
          final inputLast4 = inputDigits.substring(inputDigits.length - 4);
          final numLast4 = numDigits.substring(numDigits.length - 4);
          if (inputLast4 == numLast4) score = 0.6;
        }
      }

      if (score > 0) scored[record] = score;
    }

    if (scored.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = '未找到匹配车号「$input」';
      });
      return;
    }

    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topScore = sorted.first.value;
    final best = topScore >= 0.9
        ? sorted.where((e) => e.value >= topScore - 0.05).toList()
        : sorted.take(5).toList();

    setState(() {
      for (int i = 0; i < best.length; i++) {
        _searchResults.add(
          CoachSearchResult(
            record: best[i].key,
            score: best[i].value,
            rank: i + 1,
            queryTime: queryTime,
          ),
        );
      }
      _isLoading = false;
    });
  }

  // ---- 配属段查询 ----
  void _searchByDepot(String input) {
    final pattern = input.trim().toLowerCase();
    final matches = _allRecords
        .where((r) => r.depot.toLowerCase().contains(pattern))
        .toList();

    if (matches.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = '未找到配属段「$input」';
      });
      return;
    }

    matches.sort((a, b) {
      final mc = a.model.compareTo(b.model);
      return mc != 0 ? mc : a.number.compareTo(b.number);
    });

    _pagedSource = matches;
    _totalResults = matches.length;
    _currentSearchLabel = input;
    _loadPage(1);
  }

  // ---- 型号查询 ----
  void _searchByModel(String input) {
    final pattern = input.trim().toUpperCase();
    final matches = _allRecords
        .where((r) => r.model.toUpperCase() == pattern)
        .toList();

    if (matches.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = '未找到车型「$input」，请检查输入是否正确';
      });
      return;
    }

    matches.sort((a, b) => a.number.compareTo(b.number));

    _pagedSource = matches;
    _totalResults = matches.length;
    _currentSearchLabel = pattern;
    _loadPage(1);
  }

  // ---- 分页 ----
  void _loadPage(int page) {
    if (_pagedSource.isEmpty || page < 1 || page > _totalPages) return;

    setState(() => _loadingPage = true);

    final start = (page - 1) * _pageSize;
    final end = min(page * _pageSize, _pagedSource.length);
    final pageRecords = _pagedSource.sublist(start, end);

    final queryTime = DateTime.now().toLocal().toString().substring(0, 19);
    final newResults = pageRecords
        .map((r) => CoachSearchResult(record: r, queryTime: queryTime))
        .toList();

    setState(() {
      _searchResults
        ..clear()
        ..addAll(newResults);
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

  // ==================== UI 组件 ====================

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
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

  Widget _buildResultCard(CoachSearchResult result) {
    final record = result.record;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 车型徽章
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.model,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.number,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_searchType == 'depot' || _searchType == 'model')
                        Text(
                          record.depot,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                    ],
                  ),
                ),
                // 匹配分数（车号查询才显示）
                if (result.score != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            height: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: result.score!.clamp(0.0, 1.0),
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  result.score! >= 0.8
                                      ? Colors.green
                                      : result.score! >= 0.5
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                        ],
                      ),
                      if (result.rank != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
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
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // 详细信息
            if (record.depot.isNotEmpty && _searchType == 'number')
              _buildInfoRow('现配属', record.depot),
            if (record.capacity != null && record.capacity!.isNotEmpty)
              _buildInfoRow('定员', '${record.capacity}人'),
            if (record.bogie != null && record.bogie!.isNotEmpty)
              _buildInfoRow('转向架', record.bogie!),
            if (record.manufacturer != null && record.manufacturer!.isNotEmpty)
              _buildInfoRow('制造厂', record.manufacturer!),

            const SizedBox(height: 6),
            Text(
              '查询时间: ${result.queryTime}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 && !_loadingPage
                ? () => _goToPage(_currentPage - 1)
                : null,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
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
                if (p != null && p >= 1 && p <= _totalPages) {
                  _goToPage(p);
                } else {
                  _pageController.text = _currentPage.toString();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '/ $_totalPages 页（共 $_totalResults 条）',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 8),
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.directions_railway_filled_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
          ),
          const SizedBox(height: 16),
          Text(
            _searchType == 'number'
                ? '请输入车号进行查询\n（例如：080003 或 892151）'
                : _searchType == 'depot'
                ? '请输入配属段名称进行查询\n（例如：广铁 或 成局）'
                : '请输入车型代号进行查询',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),

          // 车型查询：显示所有可查车型
          if (_searchType == 'model') ...[
            const Text('所有可查车型:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: _getAllModels().map((m) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = m;
                    _performSearch();
                  },
                  child: Chip(label: Text(m)),
                );
              }).toList(),
            ),
          ],

          // 配属段查询：显示常见配属段
          if (_searchType == 'depot') ...[
            const Text('所有配属段:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: _getAllDepots().map((d) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = d;
                    _performSearch();
                  },
                  child: Chip(label: Text(d)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== build ====================

  @override
  Widget build(BuildContext context) {
    final displayedCount = _searchResults.length;
    final totalCount = (_searchType == 'depot' || _searchType == 'model')
        ? _totalResults
        : displayedCount;

    return Scaffold(
      appBar: AppBar(title: const Text('客车查询')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- 搜索栏 ----
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: _searchType == 'number'
                          ? '输入车号'
                          : _searchType == 'depot'
                          ? '输入配属段名称'
                          : '输入车型代号',
                      hintText: _searchType == 'number'
                          ? '如: 080003'
                          : _searchType == 'depot'
                          ? '如: 广铁 或 成局贵段'
                          : '如: CA25G',
                      border: const OutlineInputBorder(),
                      filled: true,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _performSearch(),
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
            const SizedBox(height: 16),

            // ---- 查询类型切换 ----
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'number',
                  label: Text('车号'),
                  icon: Icon(Icons.confirmation_number),
                ),
                ButtonSegment(
                  value: 'depot',
                  label: Text('配属段'),
                  icon: Icon(Icons.location_city),
                ),
                ButtonSegment(
                  value: 'model',
                  label: Text('车型'),
                  icon: Icon(Icons.card_travel_rounded),
                ),
              ],
              selected: {_searchType},
              onSelectionChanged: (s) => setState(() {
                _searchType = s.first;
                _controller.clear();
                _searchResults.clear();
                _errorMsg = '';
                _resetPagination();
              }),
              style: SegmentedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                selectedForegroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary,
              ),
            ),

            const SizedBox(height: 20),

            // ---- 加载中 ----
            if (_isLoading && _searchResults.isEmpty)
              const Center(child: CircularProgressIndicator()),

            // ---- 错误信息 ----
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

            // ---- 结果区域 ----
            if (_searchResults.isNotEmpty) ...[
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
                            (_searchType == 'depot' || _searchType == 'model')
                                ? '「$_currentSearchLabel」共 $totalCount 条（当前 $displayedCount 条）'
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
                    onPressed: () {
                      setState(() {
                        _searchResults.clear();
                        _controller.clear();
                        _errorMsg = '';
                        _resetPagination();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_searchType == 'depot' || _searchType == 'model')
                _buildPaginationControls(),

              for (final result in _searchResults) _buildResultCard(result),

              if (_loadingPage)
                const Center(child: CircularProgressIndicator()),
            ],

            // ---- 空状态 ----
            if (!_isLoading && _errorMsg.isEmpty && _searchResults.isEmpty)
              _buildEmptyState(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
