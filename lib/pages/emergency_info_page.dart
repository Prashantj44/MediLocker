import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/encryption_service.dart';

class EmergencyInfoPage extends StatefulWidget {
  const EmergencyInfoPage({super.key});

  @override
  State<EmergencyInfoPage> createState() => _EmergencyInfoPageState();
}

class _EmergencyInfoPageState extends State<EmergencyInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _contact1NameController = TextEditingController();
  final _contact1RelationshipController = TextEditingController();
  final _contact1PhoneController = TextEditingController();
  final _contact2NameController = TextEditingController();
  final _contact2RelationshipController = TextEditingController();
  final _contact2PhoneController = TextEditingController();
  final _encryptionService = EncryptionService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData != null) {
        // Decrypt data before displaying
        _contact1NameController.text = await _encryptionService.decryptData(userData['emergencyContact1_name'] ?? '') ?? '';
        _contact1RelationshipController.text = await _encryptionService.decryptData(userData['emergencyContact1_relationship'] ?? '') ?? '';
        _contact1PhoneController.text = await _encryptionService.decryptData(userData['emergencyContact1_phone'] ?? '') ?? '';
        _contact2NameController.text = await _encryptionService.decryptData(userData['emergencyContact2_name'] ?? '') ?? '';
        _contact2RelationshipController.text = await _encryptionService.decryptData(userData['emergencyContact2_relationship'] ?? '') ?? '';
        _contact2PhoneController.text = await _encryptionService.decryptData(userData['emergencyContact2_phone'] ?? '') ?? '';
        setState(() {});
      }
    }
  }

  Future<void> _saveEmergencyContacts() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Encrypt all fields before saving
      final dataToSave = {
        'emergencyContact1_name': await _encryptionService.encryptData(_contact1NameController.text.trim()),
        'emergencyContact1_relationship': await _encryptionService.encryptData(_contact1RelationshipController.text.trim()),
        'emergencyContact1_phone': await _encryptionService.encryptData(_contact1PhoneController.text.trim()),
        'emergencyContact2_name': await _encryptionService.encryptData(_contact2NameController.text.trim()),
        'emergencyContact2_relationship': await _encryptionService.encryptData(_contact2RelationshipController.text.trim()),
        'emergencyContact2_phone': await _encryptionService.encryptData(_contact2PhoneController.text.trim()),
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(dataToSave, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency contacts saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save contacts: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Information'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildContactCard(
                  title: 'Emergency Contact 1',
                  nameController: _contact1NameController,
                  relationshipController: _contact1RelationshipController,
                  phoneController: _contact1PhoneController,
                  isPrimary: true,
                ),
                const SizedBox(height: 24),
                _buildContactCard(
                  title: 'Emergency Contact 2',
                  nameController: _contact2NameController,
                  relationshipController: _contact2RelationshipController,
                  phoneController: _contact2PhoneController,
                ),
                const SizedBox(height: 16),
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Your emergency contacts are end-to-end encrypted.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _saveEmergencyContacts,
                    child: const Text('Save Contacts'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String title,
    required TextEditingController nameController,
    required TextEditingController relationshipController,
    required TextEditingController phoneController,
    bool isPrimary = false,
  }) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
              validator: isPrimary ? (value) => value!.isEmpty ? 'Please enter a name' : null : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: relationshipController,
              decoration: const InputDecoration(labelText: 'Relationship', prefixIcon: Icon(Icons.people_outline)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }
}
