import 'dart:math';
import '../data/document_store.dart';

bool validContactAddress(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value) ||
    RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value);

String newContactId() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class ContactInput {
  final String name, contact, details, language;
  final Map<String, String> project;
  const ContactInput({
    required this.name,
    required this.contact,
    required this.details,
    required this.language,
    this.project = const {'id': '', 'nameAr': '', 'nameEn': ''},
  });
  Map<String, Object?> toMap() => {
    'name': name,
    'contact': contact,
    'details': details,
    'language': language,
    'project': project,
  };
  factory ContactInput.fromMap(Map<String, dynamic> v) => ContactInput(
    name: v['name'] as String,
    contact: v['contact'] as String,
    details: v['details'] as String,
    language: v['language'] as String,
    project: Map<String, String>.from(v['project'] as Map),
  );
  void validate() {
    if (name.trim().isEmpty ||
        name.length > 120 ||
        contact.length > 254 ||
        !validContactAddress(contact) ||
        details.trim().length < 10 ||
        details.length > 5000 ||
        !['ar', 'en'].contains(language) ||
        project.keys.toSet().difference({
          'id',
          'nameAr',
          'nameEn',
        }).isNotEmpty ||
        project.length != 3 ||
        project['id']!.length > 70 ||
        (project['id']!.isNotEmpty &&
            !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(project['id']!)) ||
        project['nameAr']!.length > 30000 ||
        project['nameEn']!.length > 30000) {
      throw const DataFailure('invalid_contact_input');
    }
  }
}

class ContactRequest {
  final String id, status, note;
  final ContactInput input;
  final DateTime createdAt;
  const ContactRequest(
    this.id,
    this.input,
    this.status,
    this.note,
    this.createdAt,
  );
  factory ContactRequest.fromDocument(StoredDocument doc) => ContactRequest(
    doc.path.split('/').last,
    ContactInput.fromMap(doc.data),
    doc.data['status'] as String,
    doc.data['note'] as String,
    doc.data['createdAt'] as DateTime,
  );
}
