import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalRecord {
  final String id;
  final String userId;
  final String title;
  final String category;
  final String date;
  final String description;
  final String? attachmentUrl;
  final String? attachmentType;
  final bool? isLocal;

  MedicalRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.date,
    required this.description,
    this.attachmentUrl,
    this.attachmentType,
    this.isLocal,
  });

  // copyWith method to create a modified copy of a MedicalRecord
  MedicalRecord copyWith({
    String? id,
    String? userId,
    String? title,
    String? category,
    String? date,
    String? description,
    String? attachmentUrl,
    String? attachmentType,
    bool? isLocal,
  }) {
    return MedicalRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      description: description ?? this.description,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'category': category,
      'date': date,
      'description': description,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'isLocal': isLocal,
    };
  }

  factory MedicalRecord.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return MedicalRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      category: data['category'] ?? 'Uncategorized',
      date: data['date'] ?? '',
      description: data['description'] ?? '',
      attachmentUrl: data['attachmentUrl'],
      attachmentType: data['attachmentType'],
      isLocal: data['isLocal'] ?? false,
    );
  }
}
