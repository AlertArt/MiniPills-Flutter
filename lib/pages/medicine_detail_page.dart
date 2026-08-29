// 药品详情页 —— 对应小程序 pages/med-detail/med-detail
// 查看 / 编辑药品，含图片、库存增减、保存、删除

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/med_list.dart';
import '../models/medicine.dart';
import '../services/medicine_storage.dart';
import '../theme.dart';

class MedicineDetailPage extends StatefulWidget {
  final Medicine medicine;
  final bool editing;
  const MedicineDetailPage({super.key, required this.medicine, this.editing = false});

  @override
  State<MedicineDetailPage> createState() => _MedicineDetailPageState();
}

class _MedicineDetailPageState extends State<MedicineDetailPage> {
  final MedicineStorage _storage = MedicineStorage();
  final ImagePicker _picker = ImagePicker();

  late bool _editing;
  late String _id;
  late String _name;
  late String _spec;
  late String _manufacturer;
  late String _expireDate;
  late int _stock;
  late String _unit;
  late String _location;
  late String _barcode;
  late String _medType;
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _editing = widget.editing;
    _id = m.id;
    _name = m.name;
    _spec = m.spec ?? '';
    _manufacturer = m.manufacturer ?? '';
    _expireDate = m.expireDate ?? '';
    _stock = m.stock;
    _unit = m.unit ?? '片';
    _location = m.location ?? '';
    _barcode = m.barcode ?? '';
    _medType = m.medType ?? '';
    _images = List.of(m.images);
  }

  void _setField(String field, String value) {
    setState(() {
      switch (field) {
        case 'name':
          _name = value;
          break;
        case 'spec':
          _spec = value;
          break;
        case 'manufacturer':
          _manufacturer = value;
          break;
        case 'location':
          _location = value;
          break;
      }
    });
  }

  Future<void> _pickImage({required bool camera}) async {
    final XFile? file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    if (!mounted) return;
    setState(() => _images.add(file.path));
  }

  void _removeImageAt(int index) {
    setState(() => _images.removeAt(index));
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

  Future<void> _onAddImage() async {
    final source = await _chooseSource('添加图片');
    if (source == null) return;
    await _pickImage(camera: source == ImageSource.camera);
  }

  void _onPreviewImage(int index) {
    if (_images.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Dialog(
          backgroundColor: Colors.black,
          child: _buildImage(_images[index], fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _onStepper(int delta) async {
    if (!_editing) return;
    setState(() => _stock = (_stock + delta).clamp(0, 9999));
  }

  // ========== 有效期编辑 ==========
  Future<void> _onEditExpire() async {
    if (!_editing) return;
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (i) => currentYear + i);
    final months = List.generate(12, (i) => i < 9 ? '0${i + 1}' : '${i + 1}');

    int yearIdx = 0;
    int monthIdx = 0;
    if (_expireDate.isNotEmpty) {
      final parts = _expireDate.split('-');
      if (parts.length >= 2) {
        final y = int.tryParse(parts[0]);
        final mo = int.tryParse(parts[1]);
        if (y != null) {
          final i = years.indexOf(y);
          if (i >= 0) yearIdx = i;
        }
        if (mo != null) {
          final i = months.indexOf('$mo'.padLeft(2, '0'));
          if (i >= 0) monthIdx = i;
        }
      }
    }
    final result = await showModalBottomSheet<(int, int)>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _DetailYearMonthPicker(
        years: years,
        months: months,
        initialYearIdx: yearIdx,
        initialMonthIdx: monthIdx,
      ),
    );
    if (result == null) return;
    final (yIdx, mIdx) = result;
    final year = years[yIdx];
    final month = months[mIdx];
    setState(() => _expireDate = '$year-$month-01');
  }

  // ========== 存放位置编辑 ==========
  Future<void> _onEditLocation() async {
    if (!_editing) return;
    final custom = await _storage.loadCustomLocations();
    if (!mounted) return;
    final locs = AddMedicineLogic.getLocations(custom: custom);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _DetailLocationPicker(
        title: '选择存放位置',
        items: locs,
        initial: _location.isEmpty ? 0 : locs.indexOf(_location),
      ),
    );
    if (result == null) return;
    setState(() => _location = result);
    await _storage.addCustomLocation(result);
  }

  Future<void> _onSave() async {
    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('药品名称不能为空')));
      return;
    }
    final updated = widget.medicine.copyWith(
      name: _name.trim(),
      spec: _spec,
      manufacturer: _manufacturer,
      expireDate: _expireDate,
      stock: _stock,
      location: _location,
      images: List.of(_images),
    );
    if (_location.trim().isNotEmpty) {
      await _storage.addCustomLocation(_location);
    }
    final saved = await _storage.update(_id, updated);
    if (saved == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('药品不存在')));
      return;
    }
    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('保存成功')));
  }

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"$_name"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppColors.brandDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.delete(_id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final info = computeStatus(_expireDate.isEmpty ? null : _expireDate, null);
    return Scaffold(
      appBar: AppBar(
        title: const Text('药品详情'),
        automaticallyImplyLeading: true,
        actions: [
          TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            child: Text(_editing ? '取消' : '编辑',
                style: TextStyle(
                  fontSize: 14,
                  color: _editing ? AppColors.brandTextSub : AppColors.brandBlue,
                )),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDetailCard(info),
            if (_editing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brandBlue),
                  onPressed: _onSave,
                  child: const Text('保存修改'),
                ),
              ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.brandDanger,
                side: const BorderSide(color: AppColors.brandDanger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _onDelete,
              child: const Text('删除药品',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
      ({int daysLeft, String status, String stage, String stageText}) info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          const SizedBox(height: 16),
          _fieldGroup(label: '药品名称', child: _editableField('name', _name, textInput: true)),
          _fieldGroup(label: '规格', child: _editableField('spec', _spec, textInput: true)),
          _fieldGroup(
              label: '生产厂商', child: _editableField('manufacturer', _manufacturer, textInput: true)),
          _fieldGroup(label: '药品类型', child: _valueText(_medType.isEmpty ? '未设置' : _medType)),
          _fieldGroup(label: '有效期', child: _selectableField(
            value: _expireDate.isEmpty ? '未设置' : _expireDate,
            onTap: _onEditExpire,
          )),
          _fieldGroup(label: '库存', child: _stockRow()),
          _fieldGroup(label: '存放位置', child: _selectableField(
            value: _location.isEmpty ? '未设置' : _location,
            onTap: _onEditLocation,
          )),
          _fieldGroup(label: '条形码', child: _valueText(_barcode.isEmpty ? '无' : _barcode)),
          _fieldGroup(
            label: '状态',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusBg(info.stage),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_statusText(info.stage, info.daysLeft),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: stageColor(info.stage).foreground,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusBg(String stage) => stageColor(stage).background;

  String _statusText(String stage, int daysLeft) {
    if (stage == 'expired') return '已过期';
    if (stage == 'normal') return '正常';
    return '还剩$daysLeft天';
  }

  Widget _buildImageSection() {
    const itemSize = 100.0;
    final children = <Widget>[];
    for (var i = 0; i < _images.length; i++) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(right: 10, bottom: 10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: _editing ? null : () => _onPreviewImage(i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImage(_images[i], width: itemSize, height: itemSize),
                ),
              ),
              if (_editing)
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
    if (_editing) {
      children.add(
        GestureDetector(
          onTap: _onAddImage,
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
                Text('添加图片', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
              ],
            ),
          ),
        ),
      );
    }
    if (_images.isEmpty && !_editing) {
      return Center(
        child: Container(
          width: 160,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text('暂无图片', style: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB))),
        ),
      );
    }
    return Wrap(
      children: children,
    );
  }

  Widget _editableField(String field, String value, {required bool textInput}) {
    if (!_editing) {
      return _valueText(value.isEmpty ? '-' : value);
    }
    return TextField(
      controller: TextEditingController(text: value),
      enabled: _editing,
      style: const TextStyle(fontSize: 20, color: AppColors.brandText),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.brandBlue),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.brandBlue, width: 2),
        ),
      ),
      onChanged: (v) => _setField(field, v),
    );
  }

  Widget _valueText(String v) => Text(v,
      style: const TextStyle(fontSize: 20, color: AppColors.brandText));

  /// 选择型字段：编辑模式下可点击打开选择器，非编辑模式显示普通文本
  Widget _selectableField({required String value, required VoidCallback onTap}) {
    if (!_editing) {
      return _valueText(value);
    }
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 20, color: AppColors.brandText)),
          ),
          const Text('⌄', style: TextStyle(fontSize: 20, color: AppColors.brandBlue)),
        ],
      ),
    );
  }

  Widget _stockRow() {
    if (!_editing) {
      return Row(
        children: [
          Text('$_stock', style: const TextStyle(fontSize: 20, color: AppColors.brandText)),
          const SizedBox(width: 8),
          Text(_unit, style: const TextStyle(fontSize: 16, color: AppColors.brandTextSub)),
        ],
      );
    }
    return Row(
      children: [
        _stepperBtn('-', () => _onStepper(-1)),
        const SizedBox(width: 12),
        Text('$_stock', style: const TextStyle(fontSize: 20, color: AppColors.brandText)),
        const SizedBox(width: 12),
        _stepperBtn('+', () => _onStepper(1)),
        const SizedBox(width: 8),
        Text(_unit, style: const TextStyle(fontSize: 16, color: AppColors.brandTextSub)),
      ],
    );
  }

  Widget _stepperBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandBlueBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 24, color: AppColors.brandBlue)),
      ),
    );
  }

  Widget _fieldGroup({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.brandBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: AppColors.brandTextSub)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildImage(String path,
      {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('assets/')) {
      return Image.asset(path,
          width: width, height: height, fit: fit,
          errorBuilder: (_, _, _) => const SizedBox.shrink());
    }
    return Image.file(File(path),
        width: width, height: height, fit: fit,
        errorBuilder: (_, _, _) => const SizedBox.shrink());
  }
}

/// 详情页有效期选择器（年 + 月）
class _DetailYearMonthPicker extends StatefulWidget {
  final List<int> years;
  final List<String> months;
  final int initialYearIdx;
  final int initialMonthIdx;
  const _DetailYearMonthPicker({
    required this.years,
    required this.months,
    required this.initialYearIdx,
    required this.initialMonthIdx,
  });

  @override
  State<_DetailYearMonthPicker> createState() => _DetailYearMonthPickerState();
}

class _DetailYearMonthPickerState extends State<_DetailYearMonthPicker> {
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
          _detailPickerHeader(context, '选择有效期',
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
                        child: Text('${widget.years[i]}年',
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
                        child: Text('${widget.months[i]}月',
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

/// 详情页位置选择器（支持自定义输入）
class _DetailLocationPicker extends StatefulWidget {
  final String title;
  final List<String> items;
  final int initial;
  const _DetailLocationPicker({
    required this.title,
    required this.items,
    required this.initial,
  });

  @override
  State<_DetailLocationPicker> createState() => _DetailLocationPickerState();
}

class _DetailLocationPickerState extends State<_DetailLocationPicker> {
  late int _sel;
  int get _customIdx => widget.items.length;

  @override
  void initState() {
    super.initState();
    _sel = widget.initial.clamp(0, _customIdx);
  }

  Future<void> _confirm() async {
    if (_sel == _customIdx) {
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
    final displayItems = <String>[...widget.items, '自定义位置…'];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _detailPickerHeader(context, widget.title, onConfirm: _confirm),
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

Widget _detailPickerHeader(BuildContext context, String title, {required VoidCallback onConfirm}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
        ),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.brandText)),
        GestureDetector(
          onTap: onConfirm,
          child: const Text('确定', style: TextStyle(fontSize: 14, color: AppColors.brandBlue)),
        ),
      ],
    ),
  );
}
