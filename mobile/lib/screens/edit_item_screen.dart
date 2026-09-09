import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/item_model.dart';
import '../services/api_service.dart';
import '../utils/listing_metadata.dart';

class EditItemScreen extends StatefulWidget {
  final Item item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;
  late TextEditingController _conditionController;
  late TextEditingController _bundleSizeController;
  late TextEditingController _bookAuthorController;
  late TextEditingController _bookEditionController;
  late TextEditingController _academicSubjectController;
  late TextEditingController _academicCourseController;
  late TextEditingController _academicLevelController;
  late TextEditingController _boardOrUniversityController;
  late TextEditingController _publisherController;
  late TextEditingController _isbnController;

  final ApiService _apiService = ApiService();

  List<String> _currentImages = [];
  final List<XFile> _newImages = [];
  bool _isLoading = false;
  bool _donation = false;
  bool _bundle = false;
  bool _negotiable = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController =
        TextEditingController(text: widget.item.description);
    _priceController =
        TextEditingController(text: widget.item.price.toStringAsFixed(0));
    _categoryController =
        TextEditingController(text: widget.item.category?.name ?? '');
    _conditionController =
        TextEditingController(text: widget.item.condition ?? '');
    _bundleSizeController =
        TextEditingController(text: widget.item.bundleSize?.toString() ?? '');
    _bookAuthorController =
        TextEditingController(text: widget.item.bookAuthor ?? '');
    _bookEditionController =
        TextEditingController(text: widget.item.bookEdition ?? '');
    _academicSubjectController =
        TextEditingController(text: widget.item.academicSubject ?? '');
    _academicCourseController =
        TextEditingController(text: widget.item.academicCourse ?? '');
    _academicLevelController =
        TextEditingController(text: widget.item.academicLevel ?? '');
    _boardOrUniversityController =
        TextEditingController(text: widget.item.boardOrUniversity ?? '');
    _publisherController =
        TextEditingController(text: widget.item.publisher ?? '');
    _isbnController = TextEditingController(text: widget.item.isbn ?? '');
    _currentImages = List.from(widget.item.imageUrls);
    _donation = widget.item.isDonationListing;
    _bundle = widget.item.bundle;
    _negotiable = widget.item.negotiable;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _conditionController.dispose();
    _bundleSizeController.dispose();
    _bookAuthorController.dispose();
    _bookEditionController.dispose();
    _academicSubjectController.dispose();
    _academicCourseController.dispose();
    _academicLevelController.dispose();
    _boardOrUniversityController.dispose();
    _publisherController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await ImagePicker().pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newImages.addAll(pickedFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  void _removeCurrentImage(int index) {
    setState(() {
      _currentImages.removeAt(index);
    });
  }

  Future<void> _updateItem() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price cannot be empty')),
      );
      return;
    }

    if (_bundle) {
      final bundleSize = int.tryParse(_bundleSizeController.text);
      if (bundleSize == null || bundleSize < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bundle size should be at least 2')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final allImages = List<String>.from(_currentImages);
      for (final xfile in _newImages) {
        final uploadedUrl = await _apiService.uploadItemImage(
          xfile.path,
          fileName: xfile.name,
        );
        allImages.add(uploadedUrl);
      }

      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'price': _donation ? 0 : double.parse(_priceController.text),
        'categoryId': widget.item.category?.id,
        'condition': _conditionController.text,
        'imageUrls': allImages,
        'negotiable': _donation ? false : _negotiable,
        ...buildListingMetadata(
          categoryName: widget.item.category?.name,
          title: _titleController.text,
          description: _descriptionController.text,
          donation: _donation,
          bundle: _bundle,
          bundleSize: _bundle ? int.tryParse(_bundleSizeController.text) : null,
          bookAuthor: _bookAuthorController.text,
          bookEdition: _bookEditionController.text,
          academicSubject: _academicSubjectController.text,
          academicCourse: _academicCourseController.text,
          academicLevel: _academicLevelController.text,
          boardOrUniversity: _boardOrUniversityController.text,
          publisher: _publisherController.text,
          isbn: _isbnController.text,
        ).toJson(),
      };

      await _apiService.updateItem(widget.item.id, data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBookListing = widget.item.isBookListing ||
        (widget.item.category?.name.toLowerCase().contains('book') ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Item'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: _decoration('Title'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration:
                  _decoration(_donation ? 'Price (free)' : 'Price (INR)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              readOnly: true,
              decoration: _decoration('Category'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _conditionController,
              decoration: _decoration('Condition',
                  hint: 'Like New, Good, Fair, Poor'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Donation / free giveaway'),
              value: _donation,
              onChanged: (value) => setState(() => _donation = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Price is negotiable'),
              value: _negotiable,
              onChanged:
                  _donation ? null : (value) => setState(() => _negotiable = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Selling as bundle / set'),
              value: _bundle,
              onChanged: (value) => setState(() => _bundle = value),
            ),
            if (_bundle) ...[
              TextField(
                controller: _bundleSizeController,
                keyboardType: TextInputType.number,
                decoration: _decoration('Bundle Size'),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: _decoration('Description'),
            ),
            const SizedBox(height: 24),
            if (isBookListing) ...[
              const Text(
                'Book Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _academicSubjectController,
                  decoration: _decoration('Subject')),
              const SizedBox(height: 12),
              TextField(
                  controller: _bookAuthorController,
                  decoration: _decoration('Author')),
              const SizedBox(height: 12),
              TextField(
                  controller: _bookEditionController,
                  decoration: _decoration('Edition')),
              const SizedBox(height: 12),
              TextField(
                  controller: _academicCourseController,
                  decoration: _decoration('Course / Stream')),
              const SizedBox(height: 12),
              TextField(
                  controller: _academicLevelController,
                  decoration: _decoration('Class / Semester')),
              const SizedBox(height: 12),
              TextField(
                  controller: _boardOrUniversityController,
                  decoration: _decoration('Board / University')),
              const SizedBox(height: 12),
              TextField(
                  controller: _publisherController,
                  decoration: _decoration('Publisher')),
              const SizedBox(height: 12),
              TextField(
                  controller: _isbnController,
                  decoration: _decoration('ISBN')),
              const SizedBox(height: 24),
            ],
            if (_currentImages.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Images',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _currentImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _currentImages[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey,
                                child:
                                    const Icon(Icons.image_not_supported),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeCurrentImage(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            if (_newImages.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Images',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _newImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_newImages[index].path),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeNewImage(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add More Images'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateItem,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.green,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text('Update Item'),
            ),
          ],
        ),
      ),
    );
  }
}
