import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../utils/image_utils.dart';
import '../providers/fashion_providers.dart';

const _categories = [
  'Tops', 'Bottoms', 'Dresses', 'Outerwear',
  'Shoes', 'Accessories', 'Activewear', 'Underwear',
];
const _seasons = ['spring', 'summer', 'autumn', 'winter', 'all-season'];

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  String _category = _categories.first;
  final Set<String> _selectedSeasons = {'all-season'};
  File? _imageFile;
  bool _isSaving = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked != null) {
      // Compress before storing — gallery images are typically much
      // larger than we need for a garment card preview. Falls back to
      // the original file if compression fails.
      final compressed = await ImageUtils.compressImage(File(picked.path)) ??
          File(picked.path);
      setState(() => _imageFile = compressed);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final api = ref.read(fashionApiClientProvider);

      final String? imageUrl;
      if (_imageFile != null) {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            _imageFile!.path,
            filename: 'garment.jpg',
          ),
        });
        final uploadResponse =
            await ref.read(authDioProvider).post('/upload/photo', data: formData);
        imageUrl = uploadResponse.data['url'] as String?;
      } else {
        imageUrl = null;
      }

      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'season_tags': _selectedSeasons.toList(),
        'original_image_url': imageUrl,
        'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        'cost': double.tryParse(_costCtrl.text.trim()),
        'times_worn': 0,
        'dominant_colors': <Map<String, dynamic>>[],
      };

      await api.createItem(payload);
      if (mounted) context.go(AppRoutes.fashion);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const GlassAppBar(title: 'Add Item'),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // â”€â”€ Photo picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  GlassBox(
                    radius: 16,
                    padding: const EdgeInsets.all(16),
                    child: _PhotoSection(
                      imageFile: _imageFile,
                      onPickCamera: () => _pickImage(ImageSource.camera),
                      onPickGallery: () => _pickImage(ImageSource.gallery),
                      onClear: () => setState(() => _imageFile = null),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // â”€â”€ Form fields â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  GlassBox(
                    radius: 16,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const GlassFieldLabel('ITEM DETAILS'),
                        const SizedBox(height: 14),

                        GlassTextField(
                          controller: _nameCtrl,
                          hintText: 'Item name',
                          prefixIcon: Icons.label_outline,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),

                        _CategoryDropdown(
                          value: _category,
                          items: _categories,
                          onChanged: (v) => setState(() => _category = v!),
                        ),
                        const SizedBox(height: 12),

                        GlassTextField(
                          controller: _brandCtrl,
                          hintText: 'Brand (optional)',
                          prefixIcon: Icons.sell_outlined,
                        ),
                        const SizedBox(height: 12),
                        GlassTextField(
                          controller: _costCtrl,
                          hintText: 'Cost (\$)',
                          prefixIcon: Icons.attach_money,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // â”€â”€ Season chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  GlassBox(
                    radius: 16,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GlassFieldLabel('SEASON'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _seasons.map((s) {
                            final selected = _selectedSeasons.contains(s);
                            return _SeasonChip(
                              label: s,
                              selected: selected,
                              onTap: () => setState(() {
                                if (selected) {
                                  _selectedSeasons.remove(s);
                                } else {
                                  _selectedSeasons.add(s);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  GlassButton(
                    label: 'Save to Wardrobe',
                    onPressed: _save,
                    isLoading: _isSaving,
                    icon: Icons.save_outlined,
                  ),
                ],
              ),
            ),
          ),
          // â”€â”€ Loading overlay â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: Center(
                child: GlassBox(
                  radius: 16,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 16),
                      Text('Savingâ€¦', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// â”€â”€ Components â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: AppTextStyles.body.copyWith(color: AppColors.ink),
          dropdownColor: AppColors.elevated,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.hint, size: 20),
          items: items
              .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.ink))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.50)
                : AppColors.border,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.accent : AppColors.stone,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.imageFile,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onClear,
  });

  final File? imageFile;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (imageFile != null) {
      preview = Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              imageFile!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.canvas.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 18, color: AppColors.ink),
              ),
            ),
          ),
        ],
      );
    } else {
      preview = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.10),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.20)),
            ),
            child: const Icon(Icons.add_photo_alternate_outlined,
                size: 26, color: AppColors.accent),
          ),
          const SizedBox(height: 12),
          Text('Tap below to add a photo',
              style: AppTextStyles.caption),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(child: preview),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: GlassButton(
                label: 'Camera',
                onPressed: onPickCamera,
                variant: GlassButtonVariant.secondary,
                icon: Icons.camera_alt_outlined,
                small: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GlassButton(
                label: 'Gallery',
                onPressed: onPickGallery,
                variant: GlassButtonVariant.secondary,
                icon: Icons.photo_library_outlined,
                small: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
