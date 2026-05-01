import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/encryption_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _encryptionService = EncryptionService();

  Future<void> _launchDialer(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $phoneNumber';
    }
  }

  ImageProvider _getProfileImage(Map<String, dynamic> userData) {
    final String? localPhotoPath = userData['photoUrl'];
    if (localPhotoPath != null && localPhotoPath.isNotEmpty) {
      final file = File(localPhotoPath);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return const AssetImage('assets/images/app_icon.jpg'); // Corrected asset path
  }

  Widget _buildDecryptedInfoRow(String label, String? encryptedValue) {
    if (encryptedValue == null || encryptedValue.isEmpty) {
      return _buildInfoRow(label, 'N/A');
    }
    return FutureBuilder<String?>(
      future: _encryptionService.decryptData(encryptedValue),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInfoRow(label, 'Decrypting...');
        }
        return _buildInfoRow(label, snapshot.data ?? '[Decryption Error]');
      },
    );
  }

  Widget _buildCallableInfoRow(String label, String? encryptedValue) {
    if (encryptedValue == null || encryptedValue.isEmpty) {
      return _buildInfoRow(label, 'N/A');
    }
    return FutureBuilder<String?>(
      future: _encryptionService.decryptData(encryptedValue),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInfoRow(label, 'Decrypting...');
        }
        final decryptedValue = snapshot.data ?? '[Decryption Error]';
        return _buildInfoRow(label, decryptedValue, isPhone: true, onPhoneTap: () => _launchDialer(decryptedValue));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return const Center(child: Text('Error fetching user data.'));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: _getProfileImage(userData),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Patient Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Your secure medical profile', style: Theme.of(context).textTheme.bodySmall),
                    const Divider(height: 32),
                    _buildInfoRow('Unique ID', user.uid.substring(0, 10).toUpperCase()),
                    _buildDecryptedInfoRow('Full Name', userData['fullName']),
                    _buildDecryptedInfoRow('Date of Birth', userData['dob']),
                    _buildInfoRow('Blood Group', userData['bloodGroup'] ?? 'N/A'),
                    _buildCallableInfoRow('Phone Number', userData['phone']),
                    _buildInfoRow('Email', user.email ?? 'N/A'),
                    const Divider(height: 32),
                    _buildEncryptionMessage('Your personal information is end-to-end encrypted.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildEmergencyContacts(context, userData),
            const SizedBox(height: 24),
            _buildAmbulanceContact(context),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPhone = false, VoidCallback? onPhoneTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 4),
          if (isPhone && value != 'N/A')
            InkWell(
              onTap: onPhoneTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Icon(Icons.call_outlined, size: 16, color: Theme.of(context).primaryColor),
                  ],
                ),
              ),
            )
          else
            Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmergencyContacts(BuildContext context, Map<String, dynamic> userData) {
    final contact1Name = userData['emergencyContact1_name'] as String?;
    final contact2Name = userData['emergencyContact2_name'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Emergency Contacts', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.pushNamed(context, '/emergency_info'),
                  tooltip: 'Edit Emergency Contacts',
                ),
              ],
            ),
            const Divider(height: 24),
            if ((contact1Name == null || contact1Name.isEmpty) && (contact2Name == null || contact2Name.isEmpty))
              const Center(child: Text('No emergency contacts added.', style: TextStyle(color: Colors.grey)))
            else ...[
              if (contact1Name != null && contact1Name.isNotEmpty)
                _buildContactRow(
                  nameFuture: _encryptionService.decryptData(contact1Name),
                  relationshipFuture: _encryptionService.decryptData(userData['emergencyContact1_relationship']),
                  phoneFuture: _encryptionService.decryptData(userData['emergencyContact1_phone']),
                ),
              if ((contact1Name != null && contact1Name.isNotEmpty) && (contact2Name != null && contact2Name.isNotEmpty)) const Divider(height: 24),
              if (contact2Name != null && contact2Name.isNotEmpty)
                _buildContactRow(
                  nameFuture: _encryptionService.decryptData(contact2Name),
                  relationshipFuture: _encryptionService.decryptData(userData['emergencyContact2_relationship']),
                  phoneFuture: _encryptionService.decryptData(userData['emergencyContact2_phone']),
                ),
            ],
             const Divider(height: 24),
            _buildEncryptionMessage('Emergency contacts are end-to-end encrypted.'),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow({required Future<String?> nameFuture, Future<String?>? relationshipFuture, Future<String?>? phoneFuture}) {
    return FutureBuilder<List<String?>>(
      future: Future.wait([nameFuture, relationshipFuture ?? Future.value(null), phoneFuture ?? Future.value(null)]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 20, child: LinearProgressIndicator());
        }

        final name = snapshot.data?[0];
        final relationship = snapshot.data?[1];
        final phone = snapshot.data?[2];

        if(name == null || name.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (relationship != null && relationship.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(relationship, style: TextStyle(color: Colors.grey[600])),
            ],
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _launchDialer(phone),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(phone, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(width: 8),
                      Icon(Icons.call_outlined, size: 16, color: Theme.of(context).primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
  
  Widget _buildEncryptionMessage(String message) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildAmbulanceContact(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _launchDialer('108'),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_hospital, color: Theme.of(context).primaryColor, size: 28),
              const SizedBox(width: 16),
              Text('Call Ambulance: 108', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
