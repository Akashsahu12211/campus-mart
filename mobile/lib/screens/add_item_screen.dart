import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/image_service.dart';
import '../utils/listing_metadata.dart';
import '../utils/validators.dart';
import '../widgets/custom_button.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _reviewCommentCtrl = TextEditingController();
  final _bundleSizeCtrl = TextEditingController();
  final _bookAuthorCtrl = TextEditingController();
  final _bookEditionCtrl = TextEditingController();
  final _academicSubjectCtrl = TextEditingController();
  final _academicCourseCtrl = TextEditingController();
  final _academicLevelCtrl = TextEditingController();
  final _boardOrUniversityCtrl = TextEditingController();
  final _publisherCtrl = TextEditingController();
  final _isbnCtrl = TextEditingController();

  List<dynamic> _categories = [];
  int? _selectedCatId;
  String _condition = 'GOOD';
  bool _negotiable = false;
  bool _donation = false;
  bool _bundle = false;
  bool _loading = false;
  String? _error;
  final Set<int> _uploadingImageIndexes = <int>{};

  int _reviewRating = 5;
  List<String?> _images = [];
  static const int _maxImages = 20;

  static const _conditions = [
    {'val': 'NEW', 'label': 'New'},
    {'val': 'LIKE_NEW', 'label': 'Like New'},
    {'val': 'GOOD', 'label': 'Good'},
    {'val': 'FAIR', 'label': 'Fair'},
    {'val': 'POOR', 'label': 'Poor'},
  ];

  @override
  void initState() {
    super.initState();
    _images = List.filled(5, null);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.getCategories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (_) {
      if (!mounted) return;
      setState(() => _categories = []);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _reviewCommentCtrl.dispose();
    _bundleSizeCtrl.dispose();
    _bookAuthorCtrl.dispose();
    _bookEditionCtrl.dispose();
    _academicSubjectCtrl.dispose();
    _academicCourseCtrl.dispose();
    _academicLevelCtrl.dispose();
    _boardOrUniversityCtrl.dispose();
    _publisherCtrl.dispose();
    _isbnCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int idx) async {
    final pickedImage = await ImageService.showPickerDialog(context);
    if (pickedImage == null || !mounted) return;

    setState(() {
      _uploadingImageIndexes.add(idx);
      _error = null;
    });

    try {
      final uploadedUrl = await _api.uploadItemImage(
        pickedImage.path,
        fileName: pickedImage.name,
      );
      if (!mounted) return;
      setState(() {
        while (_images.length <= idx) {
          _images.add(null);
        }
        _images[idx] = uploadedUrl;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _uploadingImageIndexes.remove(idx));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCatId == null) {
      setState(() => _error = 'Please select a category.');
      return;
    }
    if (_uploadingImageIndexes.isNotEmpty) {
      setState(() => _error = 'Please wait for image uploads to finish.');
      return;
    }
    if (_bundle) {
      final bundleSize = int.tryParse(_bundleSizeCtrl.text);
      if (bundleSize == null || bundleSize < 2) {
        setState(() => _error = 'Bundle size should be at least 2.');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final user = context.read<AuthProvider>().user!;
    final validImages =
        _images.whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    final selectedCategory = _categories.cast<dynamic>().firstWhere(
          (category) => category?.id == _selectedCatId,
          orElse: () => null,
        );
    final isBookCategory =
        (selectedCategory?.name?.toString().toLowerCase().contains('book') ??
            false);
    final listingMetadata = buildListingMetadata(
      categoryName: selectedCategory?.name?.toString(),
      title: _titleCtrl.text,
      description: _descCtrl.text,
      donation: _donation,
      bundle: _bundle,
      bundleSize: _bundle ? int.tryParse(_bundleSizeCtrl.text) : null,
      bookAuthor: _bookAuthorCtrl.text,
      bookEdition: _bookEditionCtrl.text,
      academicSubject:
          _academicSubjectCtrl.text.isNotEmpty ? _academicSubjectCtrl.text : isBookCategory ? _titleCtrl.text : '',
      academicCourse: _academicCourseCtrl.text,
      academicLevel: _academicLevelCtrl.text,
      boardOrUniversity: _boardOrUniversityCtrl.text,
      publisher: _publisherCtrl.text,
      isbn: _isbnCtrl.text,
    );

    try {
      final itemResponse = await _api.addItem({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': _donation ? 0 : double.parse(_priceCtrl.text),
        'imageUrls': validImages,
        'condition': _condition,
        'negotiable': _donation ? false : _negotiable,
        'categoryId': _selectedCatId,
        ...listingMetadata.toJson(),
      });

      if (_reviewCommentCtrl.text.trim().isNotEmpty || _reviewRating > 0) {
        try {
          await _api.addReview({
            'rating': _reviewRating,
            'comment': _reviewCommentCtrl.text.trim(),
            'itemId': itemResponse.id,
            'sellerId': user.id,
          });
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item listed successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildImageSlot(int idx) {
    final img = idx < _images.length ? _images[idx] : null;
    return GestureDetector(
      onTap: () => _pickImage(idx),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: img != null ? AppTheme.accent : AppTheme.border2,
          ),
        ),
        child: _uploadingImageIndexes.contains(idx)
            ? const Center(
                child: Text(
                  'Uploading...',
                  style: TextStyle(
                    color: AppTheme.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : img != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: _buildImgWidget(img),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (idx < _images.length) {
                          _images.removeAt(idx);
                        }
                      }),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppTheme.danger,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_rounded,
                    color: AppTheme.muted,
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Photo ${idx + 1}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImgWidget(String data) {
    if (data.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(data.split(',').last),
          fit: BoxFit.cover,
        );
      } catch (_) {
        return const Icon(Icons.broken_image);
      }
    }
    return Image.network(data, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _categories.cast<dynamic>().firstWhere(
          (category) => category?.id == _selectedCatId,
          orElse: () => null,
        );
    final isBookCategory =
        (selectedCategory?.name?.toString().toLowerCase().contains('book') ??
            false);

    return Scaffold(
      appBar: AppBar(title: const Text('List an Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _SectionCard(
                title: 'Basic Info',
                icon: Icons.edit_note_rounded,
                children: [
                  AppTextField(
                    label: 'Title *',
                    hint: 'e.g. DBMS Textbook by Navathe',
                    controller: _titleCtrl,
                    validator: (v) => Validators.required(v, 'Title'),
                  ),
                  AppTextField(
                    label: 'Description',
                    hint: 'Condition, edition, reason for selling...',
                    controller: _descCtrl,
                    maxLines: 3,
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 620;
                      final priceField = AppTextField(
                        label: 'Price *',
                        hint: _donation ? '0' : '350',
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (_donation) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final value = double.tryParse(v);
                            return (value == null || value < 0)
                                ? 'Enter valid amount'
                                : null;
                          }
                          return Validators.price(v);
                        },
                      );
                      final categoryField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CATEGORY *',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.muted,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedCatId,
                            dropdownColor: AppTheme.surface2,
                            style: const TextStyle(color: AppTheme.textPrim),
                            hint: const Text(
                              'Select',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                            decoration: const InputDecoration(),
                            items: _categories
                                .map<DropdownMenuItem<int>>(
                                  (cat) => DropdownMenuItem(
                                    value: cat.id as int,
                                    child: Text(
                                      cat.name as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedCatId = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ],
                      );

                      if (compact) {
                        return Column(
                          children: [
                            priceField,
                            const SizedBox(height: 4),
                            categoryField,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: priceField),
                          const SizedBox(width: 14),
                          Expanded(child: categoryField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _donation,
                        activeColor: const Color(0xFFF59E0B),
                        onChanged: (v) => setState(() => _donation = v ?? false),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Donation / free giveaway',
                            style: TextStyle(color: AppTheme.textSec),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _negotiable,
                        activeColor: AppTheme.accent,
                        onChanged: _donation
                            ? null
                            : (v) => setState(() => _negotiable = v ?? false),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Price is negotiable',
                            style: TextStyle(color: AppTheme.textSec),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _bundle,
                        activeColor: AppTheme.success,
                        onChanged: (v) => setState(() => _bundle = v ?? false),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Selling as bundle / set',
                            style: TextStyle(color: AppTheme.textSec),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_bundle)
                    AppTextField(
                      label: 'Bundle Size *',
                      hint: '4',
                      controller: _bundleSizeCtrl,
                      keyboardType: TextInputType.number,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isBookCategory) ...[
                _SectionCard(
                  title: 'Book Details',
                  icon: Icons.menu_book_rounded,
                  children: [
                    AppTextField(
                        label: 'Subject',
                        hint: 'DBMS / Physics',
                        controller: _academicSubjectCtrl),
                    AppTextField(
                        label: 'Author',
                        hint: 'Author name',
                        controller: _bookAuthorCtrl),
                    AppTextField(
                        label: 'Edition',
                        hint: '7th Edition',
                        controller: _bookEditionCtrl),
                    AppTextField(
                        label: 'Course / Stream',
                        hint: 'B.Tech CSE / Class 10',
                        controller: _academicCourseCtrl),
                    AppTextField(
                        label: 'Class / Semester',
                        hint: 'Semester 4 / Class 12',
                        controller: _academicLevelCtrl),
                    AppTextField(
                        label: 'Board / University',
                        hint: 'CBSE / DU / AKTU',
                        controller: _boardOrUniversityCtrl),
                    AppTextField(
                        label: 'Publisher',
                        hint: 'NCERT / Pearson',
                        controller: _publisherCtrl),
                    AppTextField(
                        label: 'ISBN',
                        hint: 'Optional ISBN',
                        controller: _isbnCtrl),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _SectionCard(
                title: 'Condition',
                icon: Icons.bar_chart_rounded,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _conditions.map((c) {
                      final selected = _condition == c['val'];
                      return GestureDetector(
                        onTap: () => setState(() => _condition = c['val']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.accent.withValues(alpha: 0.1)
                                : AppTheme.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  selected ? AppTheme.accent : AppTheme.border2,
                            ),
                          ),
                          child: Text(
                            c['label']!,
                            style: TextStyle(
                              color:
                                  selected ? AppTheme.accentH : AppTheme.textSec,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Your Item Review (Optional)',
                icon: Icons.star_rounded,
                children: [
                  const Text(
                    'Share why you\'re selling this item',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Rating:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: List.generate(5, (i) {
                      final s = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _reviewRating = s),
                        child: Text(
                          _reviewRating >= s ? '★' : '☆',
                          style: TextStyle(
                            fontSize: 24,
                            color:
                                _reviewRating >= s ? AppTheme.warning : AppTheme.muted,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Comment',
                    hint: 'E.g., well-maintained, rarely used, new condition...',
                    controller: _reviewCommentCtrl,
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Photos (Unlimited)',
                icon: Icons.photo_camera_rounded,
                children: [
                  const Text(
                    'Tap a slot to take photo or pick from gallery',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount:
                        _images.length + (_images.length < _maxImages ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _images.length) {
                        return GestureDetector(
                          onTap: () => setState(() => _images.add(null)),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_circle_outline,
                                  color: AppTheme.accent,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add More',
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return _buildImageSlot(i);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_images.whereType<String>().length} photo${_images.whereType<String>().length != 1 ? 's' : ''} added (max $_maxImages)',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'List Item',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.textSec, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textSec,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
