// 添加药品页 —— 对应小程序 pages/add-medicine/add-medicine
// 含 AI 拍照录入、条码扫描、类型/有效期/库存/位置选择、提交

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/medicine.dart';
import '../services/ai_recognize_service.dart';
import '../services/medicine_storage.dart';
import '../theme.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final MedicineStorage _storage = MedicineStorage();
  final AiRecognizeService _ai = AiRecognizeService();
  final ImagePicker _picker = ImagePicker();

  // 表单字段
  String _barcode = '';
  String _name = '';
  String _spec = '';
  String _manufacturer = '';
  String _medType = '';
  int _stock = 30;
  String _stockUnit = '片';
  List<String> _stockUnits = ['片'];
  String? _location;

  // 图片
  String? _imagePreview; // AI 预览路径
  final List<String> _images = []; // 正式图片路径（支持多张）
  bool _recognizing = false;

  // 有效期
  String? _expireDate; // YYYY-MM-DD
  String _expireDateDisplay = '';
  List<int> _years = [];
  List<String> _months = [];
  int _yearIdx = 0;
  int _monthIdx = 0;

  // 提交状态
  bool _canSubmit = false;
  String _submitText = '请填写药品信息';

  @override
  void initState() {
    super.initState();
    _location = null;
    _initDatePicker();
    _updateSubmitState();
  }

  void _initDatePicker() {
    final currentYear = DateTime.now().year;
    _years = List.generate(10, (i) => currentYear + i);
    _months = List.generate(12, (i) => i < 9 ? '0${i + 1}' : '${i + 1}');
  }

  // ========== 提交状态 ==========
  void _updateSubmitState() {
    final s = AddMedicineLogic.updateSubmitState(name: _name, expireDate: _expireDate);
    setState(() {
      _canSubmit = s.canSubmit;
      _submitText = s.submitText;
    });
  }

  // ========== 药品类型选择 ==========
  int _typeSel = 0;

  Future<void> _showTypePicker() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SimplePicker(
        title: '选择药品类型',
        initial: _typeSel,
        items: AddMedicineLogic.medTypes,
      ),
    );
    if (sel == null) return;
    final idx = AddMedicineLogic.medTypes.indexOf(sel);
    final type = sel;
    final units = AddMedicineLogic.typeUnits[type] ?? ['片'];
    setState(() {
      _typeSel = idx < 0 ? 0 : idx;
      _medType = type;
      _stockUnits = units;
      _stockUnit = units.first;
    });
  }

  void _onUnitSelect() {
    if (_stockUnits.length <= 1) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final u in _stockUnits)
              ListTile(
                title: Text(u, textAlign: TextAlign.center),
                onTap: () {
                  setState(() => _stockUnit = u);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ========== 图片选择 ==========
  Future<void> _pickImage({required bool camera}) async {
    final XFile? file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    if (!mounted) return;
    setState(() => _images.add(file.path));
  }

  Future<void> _onPickMedImage() async {
    final source = await _chooseSource('添加图片');
    if (source == null) return;
    await _pickImage(camera: source == ImageSource.camera);
  }

  void _removeImageAt(int index) {
    setState(() => _images.removeAt(index));
  }

  // ========== AI 拍照录入 ==========
  Future<void> _onAiCapture() async {
    final source = await _chooseSource('拍照录入');
    if (source == null) return;
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (file == null) return;
    if (!mounted) return;
    setState(() {
      _imagePreview = file.path;
      _images.add(file.path);
      _recognizing = true;
      _name = '';
      _spec = '';
      _manufacturer = '';
      _expireDate = null;
      _expireDateDisplay = '';
    });
    await _uploadAndRecognize(file.path);
  }

  Future<ImageSource?> _chooseSource(String title) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('📷'),
              title: const Text('拍照', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Text('🖼'),
              title: const Text('从相册选择', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAndRecognize(String path) async {
    try {
      final result = await _ai.recognizeMedicine(path);
      if (!mounted) return;
      if (result.expireDate.isNotEmpty) {
        _expireDate = result.expireDate;
        _expireDateDisplay =
            result.expireDate.length >= 7 ? result.expireDate.substring(0, 7) : result.expireDate;
      }
      setState(() {
        _name = result.name;
        _spec = result.spec;
        _manufacturer = result.manufacturer;
      });
      _updateSubmitState();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('AI 识别完成，请确认')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }

  // ========== 条码扫描（Flutter 需插件；这里用输入占位） ==========
  void _onScan() {
    // 真实扫码需引入 mobile_scanner / barcode_scan 插件，此处保留输入方式。
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请直接输入条形码（扫码功能需接入移动端扫码插件）'),
      ),
    );
  }

  // ========== 有效期选择 ==========
  Future<void> _showDatePicker() async {
    final result = await showModalBottomSheet<(int, int)>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _YearMonthPicker(
        years: _years,
        months: _months,
        initialYearIdx: _yearIdx,
        initialMonthIdx: _monthIdx,
      ),
    );
    if (result == null) return;
    final (yearIdx, monthIdx) = result;
    final year = _years[yearIdx];
    final month = _months[monthIdx];
    setState(() {
      _yearIdx = yearIdx;
      _monthIdx = monthIdx;
      _expireDate = '$year-$month-01';
      _expireDateDisplay = '$year-$month';
    });
    _updateSubmitState();
  }

  // ========== 库存 ==========
  void _onStockPreset(int n) {
    setState(() => _stock = n);
  }

  void _onStockInput(String v) {
    var val = int.tryParse(v) ?? 0;
    if (val < 0) val = 0;
    if (val > 9999) val = 9999;
    setState(() => _stock = val);
  }

  // ========== 位置选择 ==========
  int _locSel = 0;

  Future<List<String>> _loadCustomLocations() =>
      _storage.loadCustomLocations();

  Future<void> _showLocationPicker() async {
    final custom = await _loadCustomLocations();
    if (!mounted) return;
    final locs = AddMedicineLogic.getLocations(custom: custom);
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SimplePicker(
        title: '选择存放位置',
        initial: _locSel,
        items: locs,
        allowCustom: true,
      ),
    );
    if (result == null) return;
    setState(() {
      _locSel = locs.indexOf(result);
      if (_locSel == -1) _locSel = 0;
      _location = result;
    });
    // 记忆自定义位置
    await _storage.addCustomLocation(result);
  }

  // ========== 提交 ==========
  Future<void> _onSubmit() async {
    if (_name.trim().isEmpty) {
      _toast('请输入药品名称');
      return;
    }
    if (_expireDate == null) {
      _toast('请选择有效期');
      return;
    }
    final medicine = Medicine(
      id: AddMedicineLogic.generateId(),
      barcode: _barcode.isEmpty ? null : _barcode,
      name: _name.trim(),
      spec: _spec.isEmpty ? null : _spec,
      manufacturer: _manufacturer.isEmpty ? null : _manufacturer,
      medType: _medType,
      expireDate: _expireDate,
      stock: _stock,
      unit: _stockUnit,
      location: _location,
      images: List.of(_images),
    );
    if (_location != null && _location!.trim().isNotEmpty) {
      await _storage.addCustomLocation(_location!);
    }
    await _storage.add(medicine);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('添加成功')));
    Navigator.pop(context, true);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ========== Build ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加药品'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAiSection(),
            if (_imagePreview != null && _imagePreview!.isNotEmpty) _buildImagePreview(),
            if (_recognizing) _buildRecognizingBar(),
            _buildSection(
              title: '药品图片',
              child: _buildMedImage(),
            ),
            _buildSection(
              title: '条形码',
              child: _buildBarcodeRow(),
            ),
            _section('药品名称', _buildTextField(_name, '请输入药品名称', (v) {
              _name = v;
              _updateSubmitState();
            })),
            _section('规格', _buildTextField(_spec, 'AI 识别后自动填入', (v) => _spec = v)),
            _section('生产厂家', _buildTextField(_manufacturer, 'AI 识别后自动填入', (v) => _manufacturer = v)),
            _section(
              '药品类型',
              _buildPickerField(
                value: _medType,
                placeholder: '请选择药品类型',
                onTap: _showTypePicker,
              ),
            ),
            _section(
              '有效期',
              _buildPickerField(
                value: _expireDateDisplay,
                placeholder: '请选择有效期',
                onTap: _showDatePicker,
              ),
            ),
            _buildSection(title: '', child: _buildStock()),
            _section(
              '存放位置',
              _buildPickerField(
                value: _location ?? '',
                placeholder: '请选择存放位置',
                onTap: _showLocationPicker,
              ),
            ),
            const SizedBox(height: 20),
            _buildSubmitRow(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String value, String hint, ValueChanged<String> onChanged) {
    return TextField(
      controller: TextEditingController(text: value),
      style: const TextStyle(fontSize: 16, color: AppColors.brandText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB9C6D2)),
        isDense: true,
        border: InputBorder.none,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildPickerField({
    required String value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              value.isEmpty ? placeholder : value,
              style: TextStyle(
                fontSize: 16,
                color: value.isEmpty ? const Color(0xFFB9C6D2) : AppColors.brandText,
              ),
            ),
          ),
          const Text('⌄', style: TextStyle(fontSize: 16, color: AppColors.brandTextSub)),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return _buildSection(title: title, child: child);
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
            ),
          child,
        ],
      ),
    );
  }

  Widget _buildAiSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [AppColors.brandBlue, AppColors.brandMint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: GestureDetector(
        onTap: _onAiCapture,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('AI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('拍照录入',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  SizedBox(height: 2),
                  Text('拍药盒照片，AI 自动识别药品信息',
                      style: TextStyle(fontSize: 12, color: Color(0xBFFFFFFF))),
                ],
              ),
            ),
            const Text('›', style: TextStyle(fontSize: 24, color: Color(0x99FFFFFF))),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildImage(_imagePreview!, height: 200),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _imagePreview = null),
            child: const Text('删除', style: TextStyle(color: AppColors.brandDanger)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizingBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text('AI 识别中...',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.brandBlue)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: const LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Color(0xFFEEEEEE),
              color: AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedImage() {
    const itemSize = 80.0;
    final children = <Widget>[];
    for (var i = 0; i < _images.length; i++) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildImage(_images[i], width: itemSize, height: itemSize),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _removeImageAt(i),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xCC000000),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('✕',
                        style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    // 添加按钮
    children.add(
      GestureDetector(
        onTap: _onPickMedImage,
        child: Container(
          width: itemSize,
          height: itemSize,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCCCCCC), width: 2),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFFAFAFA),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📷', style: TextStyle(fontSize: 24)),
              SizedBox(height: 4),
              Text('添加图片', style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
            ],
          ),
        ),
      ),
    );
    return Wrap(
      spacing: 0,
      runSpacing: 10,
      children: children,
    );
  }

  Widget _buildBarcodeRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: TextEditingController(text: _barcode),
            style: const TextStyle(fontSize: 16, color: AppColors.brandText),
            decoration: const InputDecoration(
              hintText: '请输入或扫描条形码',
              hintStyle: TextStyle(color: Color(0xFFB9C6D2)),
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (v) => _barcode = v,
          ),
        ),
        TextButton(
          onPressed: _onScan,
          child: const Text('扫码', style: TextStyle(fontSize: 14, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildStock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('库存量', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
            Row(
              children: [
                Container(
                  width: 70,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlueBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextField(
                    controller: TextEditingController(text: '$_stock'),
                    keyboardType: TextInputType.number,
                    onChanged: _onStockInput,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.brandBlue),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _onUnitSelect,
                  child: Text(
                    _stockUnit + (_stockUnits.length > 1 ? ' ▾' : ''),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.brandBlue),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 24,
              child: Text('0', textAlign: TextAlign.center,
                  style: _stockLabelStyle),
            ),
            Expanded(
              child: Slider(
                value: _stock.clamp(0, 200).toDouble(),
                min: 0,
                max: 200,
                divisions: 200,
                activeColor: AppColors.brandBlue,
                inactiveColor: const Color(0xFFE0E0E0),
                onChanged: (v) => setState(() => _stock = v.round()),
              ),
            ),
            SizedBox(
              width: 24,
              child: Text('200', textAlign: TextAlign.center,
                  style: _stockLabelStyle),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final n in const [10, 30, 60, 100])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _onStockPreset(n),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _stock == n ? AppColors.brandBlueBg : const Color(0xFFEEF3F8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$n$_stockUnit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _stock == n ? FontWeight.w500 : FontWeight.w400,
                          color: _stock == n ? AppColors.brandBlue : const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  TextStyle get _stockLabelStyle =>
      const TextStyle(fontSize: 12, color: Color(0xFF999999));

  Widget _buildSubmitRow() {
    return Column(
      children: [
        FilledButton(
          onPressed: _canSubmit ? _onSubmit : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandDanger,
            disabledBackgroundColor: const Color(0xFFF0D9D9),
          ),
          child: Text(_submitText),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, true),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.brandTextSub,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            side: const BorderSide(color: AppColors.brandBorder),
          ),
          child: const Text('药品盘点', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildImage(String path, {double? width, double? height}) {
    if (path.startsWith('assets/')) {
      return Image.asset(path,
          width: width, height: height, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink());
    }
    return Image.file(File(path),
        width: width, height: height, fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink());
  }
}

/// ����ѡ���������� / ���λ�ã�
class _SimplePicker extends StatefulWidget {
  final String title;
  final int initial;
  final List<String> items;
  final bool allowCustom;
  const _SimplePicker({
    required this.title,
    required this.initial,
    required this.items,
    this.allowCustom = false,
  });

  @override
  State<_SimplePicker> createState() => _SimplePickerState();
}

class _SimplePickerState extends State<_SimplePicker> {
  late int _sel;

  // 自定义位置的虚拟索引（放在 items 末尾）
  int get _customIdx => widget.items.length;

  @override
  void initState() {
    super.initState();
    _sel = widget.initial.clamp(0, _customIdx);
  }

  Future<void> _confirm() async {
    if (_sel == _customIdx && widget.allowCustom) {
      final controller = TextEditingController();
      final text = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('输入自定义位置'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '例如：床头柜'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('确定', style: TextStyle(color: AppColors.brandBlue)),
            ),
          ],
        ),
      );
      if (text == null || text.isEmpty) return;
      if (!mounted) return;
      Navigator.pop(context, text);
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, widget.items[_sel]);
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = widget.allowCustom
        ? <String>[...widget.items, '自定义位置…']
        : widget.items;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pickerHeader(context, widget.title, onConfirm: _confirm),
          SizedBox(
            height: 240,
            child: ListWheelScrollView.useDelegate(
              itemExtent: 44,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => _sel = i,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: displayItems.length,
                builder: (context, i) => Center(
                  child: Text(displayItems[i],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: i == _sel ? FontWeight.w600 : FontWeight.w400,
                        color: i == _sel ? AppColors.brandBlue : const Color(0xFF8A9BAD),
                      )),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// �� + �� ����ѡ����
class _YearMonthPicker extends StatefulWidget {
  final List<int> years;
  final List<String> months;
  final int initialYearIdx;
  final int initialMonthIdx;
  const _YearMonthPicker({
    required this.years,
    required this.months,
    required this.initialYearIdx,
    required this.initialMonthIdx,
  });

  @override
  State<_YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<_YearMonthPicker> {
  late int _yearIdx;
  late int _monthIdx;

  @override
  void initState() {
    super.initState();
    _yearIdx = widget.initialYearIdx;
    _monthIdx = widget.initialMonthIdx;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pickerHeader(context, 'ѡ����Ч��',
              onConfirm: () => Navigator.pop(context, (_yearIdx, _monthIdx))),
          SizedBox(
            height: 240,
            child: Row(
              children: [
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 44,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) => _yearIdx = i,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.years.length,
                      builder: (context, i) => Center(
                        child: Text('${widget.years[i]}��',
                            style: const TextStyle(fontSize: 20, color: AppColors.brandText)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 44,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) => _monthIdx = i,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.months.length,
                      builder: (context, i) => Center(
                        child: Text('${widget.months[i]}��',
                            style: const TextStyle(fontSize: 20, color: AppColors.brandText)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

Widget _pickerHeader(BuildContext context, String title, {required VoidCallback onConfirm}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text('ȡ��', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
        ),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.brandText)),
        GestureDetector(
          onTap: onConfirm,
          child: const Text('ȷ��', style: TextStyle(fontSize: 14, color: AppColors.brandBlue)),
        ),
      ],
    ),
  );
}
