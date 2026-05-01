import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../services/encryption_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _encryptionService = EncryptionService();
  String? _selectedBloodGroup;
  bool _isSaving = false;
  bool _pageIsLoading = true; // New state for initial page load
  File? _profileImage;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadAndDecryptData();
  }

  Future<void> _loadAndDecryptData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData != null) {
        // Decrypt data before displaying
        _nameController.text = await _encryptionService.decryptData(userData['fullName'] ?? '') ?? '';
        _dobController.text = await _encryptionService.decryptData(userData['dob'] ?? '') ?? '';
        _phoneController.text = await _encryptionService.decryptData(userData['phone'] ?? '') ?? '';
        
        setState(() {
          _selectedBloodGroup = userData['bloodGroup'];
          _profileImagePath = userData['photoUrl'];
        });
      }
    }
    setState(() {
      _pageIsLoading = false;
    });
  }


  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (status.isGranted) {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo permission is permanently denied. Please enable it in settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo library permission is required.')),
        );
      }
    }
  }

  Future<String?> _saveImageLocally(File image, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final savedImage = await image.copy('${directory.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      print("Failed to save image locally: $e");
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      String? finalPhotoPath = _profileImagePath;

      if (_profileImage != null) {
        final newFileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newPhotoPath = await _saveImageLocally(_profileImage!, newFileName);

        if (newPhotoPath != null) {
          if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
            final oldFile = File(_profileImagePath!);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          }
          finalPhotoPath = newPhotoPath;
        }
      }

      // Encrypt data before saving
      final encryptedName = await _encryptionService.encryptData(_nameController.text.trim());
      final encryptedDob = await _encryptionService.encryptData(_dobController.text.trim());
      final encryptedPhone = await _encryptionService.encryptData(_phoneController.text.trim());

      await user.updateDisplayName(_nameController.text.trim());

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': encryptedName,
        'dob': encryptedDob,
        'phone': encryptedPhone,
        'bloodGroup': _selectedBloodGroup,
        'photoUrl': finalPhotoPath,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save profile: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
    ImageProvider _getImageProvider() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    } else if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
      final file = File(_profileImagePath!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return const AssetImage('assets/images/app_icon.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _pageIsLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : AbsorbPointer(
              absorbing: _isSaving,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            key: ValueKey(_profileImage?.path ?? _profileImagePath), // Force rebuild on image change
                            radius: 50,
                            backgroundImage: _getImageProvider(),
                            child: const Align(
                              alignment: Alignment.bottomRight,
                              child: Icon(Icons.camera_alt, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Full Name'),
                          validator: (value) => value!.isEmpty ? 'Please enter your full name' : null,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _selectedBloodGroup,
                          decoration: const InputDecoration(labelText: 'Blood Group'),
                          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((String value) {
                            return DropdownMenuItem<String>(value: value, child: Text(value));
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedBloodGroup = newValue;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _dobController,
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Date of Birth'),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _dobController.text.isNotEmpty ? DateTime.tryParse(_dobController.text) ?? DateTime.now() : DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (pickedDate != null) {
                              _dobController.text = pickedDate.toString().split(' ')[0];
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Phone Number'),
                          keyboardType: TextInputType.phone,
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
                                'Your information is end-to-end encrypted.',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isSaving)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            onPressed: _saveProfile,
                            child: const Text('Save Changes'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
