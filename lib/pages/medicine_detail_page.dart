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
  String? _image;

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
    _image = m.image;
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
    setState(() => _image = file.path);
  }

  void _onPickImage() {
    _pickImage(camera: false);
  }

  void _onPreviewImage() {
    if (_image == null || _image!.isEmpty) return;
    // 简单放大预览：全屏对话框显示图片
    showDialog<void>(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Dialog(
          backgroundColor: Colors.black,
          child: _buildImage(_image!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _onStepper(int delta) async {
    if (!_editing) return;
    setState(() => _stock = (_stock + delta).clamp(0, 9999));
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
      stock: _stock,
      location: _location,
      image: _image,
    );
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
          _fieldGroup(label: '有效期', child: _valueText(_expireDate.isEmpty ? '未设置' : _expireDate)),
          _fieldGroup(label: '库存', child: _stockRow()),
          _fieldGroup(label: '存放位置', child: _editableField('location', _location, textInput: true)),
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
    if (_image != null && _image!.isNotEmpty) {
      return Center(
        child: Stack(
          children: [
            GestureDetector(
              onTap: _editing ? _onPickImage : _onPreviewImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildImage(_image!, width: 160, height: 160, fit: BoxFit.cover),
              ),
            ),
            if (_editing)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => setState(() => _image = null),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0x80000000),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('✕', style: TextStyle(fontSize: 14, color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (_editing) {
      return Center(
        child: GestureDetector(
          onTap: _onPickImage,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCCCCCC), width: 2),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFFAFAFA),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📷', style: TextStyle(fontSize: 32)),
                SizedBox(height: 8),
                Text('添加图片', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
              ],
            ),
          ),
        ),
      );
    }
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Text('暂无图片', style: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB))),
      ),
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
