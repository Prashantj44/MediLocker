import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart'; // Import the collection package
import '../models/medical_record.dart';
import '../services/encryption_service.dart';
import 'category_record_list_page.dart';

class CategoryListPage extends StatefulWidget {
  const CategoryListPage({super.key});

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  final EncryptionService _encryptionService = EncryptionService();

  Future<Map<String, List<MedicalRecord>>> _getGroupedRecords(List<MedicalRecord> records) async {
    final Map<String, List<MedicalRecord>> grouped = {};
    for (var record in records) {
      final decryptedCategory = await _encryptionService.decryptData(record.category) ?? 'Uncategorized';
      if (grouped.containsKey(decryptedCategory)) {
        grouped[decryptedCategory]!.add(record);
      } else {
        grouped[decryptedCategory] = [record];
      }
    }
    return grouped;
  }

    Future<void> _renameCategory(BuildContext context, String oldCategory, List<MedicalRecord> records) async {
    final newNameController = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: newNameController,
          decoration: const InputDecoration(hintText: "Enter new folder name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(newNameController.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      final encryptedNewName = await _encryptionService.encryptData(newName.trim());
      if (encryptedNewName == null) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final record in records) {
        final docRef = FirebaseFirestore.instance.collection('records').doc(record.id);
        batch.update(docRef, {'category': encryptedNewName});
      }
      await batch.commit();
    }
  }

  Future<void> _deleteCategory(BuildContext context, List<MedicalRecord> records) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete Folder?'),
              content: Text('This will permanently delete this folder and all ${records.length} of its records.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ));

    if (confirmed == true) {
      final batch = FirebaseFirestore.instance.batch();
      for (final record in records) {
        batch.delete(FirebaseFirestore.instance.collection('records').doc(record.id));
        if (record.attachmentUrl != null) {
          final file = File(record.attachmentUrl!);
          if (await file.exists()) {
            file.delete(); 
          }
        }
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('records').where('userId', isEqualTo: user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No records found. Upload one to see your folders.'));
                }

                final records = snapshot.data!.docs.map((doc) => MedicalRecord.fromFirestore(doc)).toList();

                return FutureBuilder<Map<String, List<MedicalRecord>>>(
                  future: _getGroupedRecords(records),
                  builder: (context, groupSnapshot) {
                    if (!groupSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final groupedRecords = groupSnapshot.data!;
                    final categories = groupedRecords.keys.toList();

                    return ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final categoryRecords = groupedRecords[category]!;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.folder_outlined, size: 40),
                            title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${categoryRecords.length} record(s)'),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                              onSelected: (value) {
                                if (value == 'rename') {
                                  _renameCategory(context, category, categoryRecords);
                                } else if (value == 'delete') {
                                  _deleteCategory(context, categoryRecords);
                                }
                              },
                            ),
                            onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CategoryRecordListPage(category: category), // Corrected: Removed 'records' parameter
                                  ),
                                );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Your records are end-to-end encrypted.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
