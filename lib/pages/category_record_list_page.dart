import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medical_record.dart';
import '../services/encryption_service.dart';
import 'record_detail_page.dart';
import 'record_upload_page.dart';

class CategoryRecordListPage extends StatefulWidget {
  final String category;

  const CategoryRecordListPage({super.key, required this.category});

  @override
  State<CategoryRecordListPage> createState() => _CategoryRecordListPageState();
}

class _CategoryRecordListPageState extends State<CategoryRecordListPage> {
  final EncryptionService _encryptionService = EncryptionService();

  void _navigateAndUpload(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordUploadPage(initialCategory: widget.category),
      ),
    );
  }

  Future<void> _moveRecord(BuildContext context, MedicalRecord record) async {
    final allRecordsQuery = await FirebaseFirestore.instance.collection('records').where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid).get();
    final allRecords = allRecordsQuery.docs.map((doc) => MedicalRecord.fromFirestore(doc)).toList();
    final allCategories = allRecords.map((r) => r.category).toSet().toList();

    List<String> decryptedCategories = [];
    for (var category in allCategories) {
      final decrypted = await _encryptionService.decryptData(category);
      if (decrypted != null) {
        decryptedCategories.add(decrypted);
      }
    }
    decryptedCategories = decryptedCategories.toSet().toList(); // Make unique

    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => _MoveRecordDialog(existingCategories: decryptedCategories),
    );

    if (newCategory != null && newCategory.trim().isNotEmpty) {
      final encryptedNewCategory = await _encryptionService.encryptData(newCategory.trim());
      if (encryptedNewCategory == null) return;
      await FirebaseFirestore.instance.collection('records').doc(record.id).update({'category': encryptedNewCategory});
    }
  }

  Future<void> _deleteRecord(BuildContext context, MedicalRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('This will permanently delete this record and its attachment.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('records').doc(record.id).delete();
      if (record.attachmentUrl != null && record.attachmentUrl!.isNotEmpty) {
        final file = File(record.attachmentUrl!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
      ),
      body: FutureBuilder<String?>(
        future: _encryptionService.encryptData(widget.category),
        builder: (context, encryptedCategorySnapshot) {
          if (!encryptedCategorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final encryptedCategory = encryptedCategorySnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('records')
                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .where('category', isEqualTo: encryptedCategory)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No records in this folder yet.'));
              }

              final records = snapshot.data!.docs.map((doc) => MedicalRecord.fromFirestore(doc)).toList();

              return ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return DecryptedRecordTile(
                    record: record,
                    onMove: () => _moveRecord(context, record),
                    onDelete: () => _deleteRecord(context, record),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateAndUpload(context),
        label: const Text('Add New File'),
        icon: const Icon(Icons.add_outlined),
      ),
    );
  }
}

class _MoveRecordDialog extends StatefulWidget {
  final List<String> existingCategories;
  const _MoveRecordDialog({required this.existingCategories});

  @override
  State<_MoveRecordDialog> createState() => _MoveRecordDialogState();
}

class _MoveRecordDialogState extends State<_MoveRecordDialog> {
  final _newCategoryController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Move Record To...'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newCategoryController,
              decoration: const InputDecoration(hintText: "Or type a new folder name"),
            ),
            const SizedBox(height: 16),
            const Text('Existing Folders', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            SizedBox(
              height: 150,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.existingCategories.length,
                itemBuilder: (context, index) {
                  final category = widget.existingCategories[index];
                  return ListTile(
                    title: Text(category),
                    onTap: () => Navigator.of(context).pop(category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_newCategoryController.text),
          child: const Text('Move'),
        ),
      ],
    );
  }
}


class DecryptedRecordTile extends StatefulWidget {
  final MedicalRecord record;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const DecryptedRecordTile({super.key, required this.record, required this.onMove, required this.onDelete});

  @override
  State<DecryptedRecordTile> createState() => _DecryptedRecordTileState();
}

class _DecryptedRecordTileState extends State<DecryptedRecordTile> {
  final EncryptionService _encryptionService = EncryptionService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _encryptionService.decryptData(widget.record.title),
      builder: (context, snapshot) {
        final decryptedTitle = snapshot.data ?? '...';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(widget.record.attachmentType == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined, size: 40, color: Theme.of(context).primaryColor),
            title: Text(decryptedTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(widget.record.date, style: TextStyle(color: Colors.grey[600])),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'move', child: Text('Move')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (value) {
                if (value == 'move') {
                  widget.onMove();
                } else if (value == 'delete') {
                  widget.onDelete();
                }
              },
            ),
            onTap: () {
              if (snapshot.hasData) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecordDetailPage(
                      record: widget.record.copyWith(title: decryptedTitle),
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}
