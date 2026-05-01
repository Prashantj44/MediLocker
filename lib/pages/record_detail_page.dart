import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/medical_record.dart';
import '../services/ai_summary_service.dart';
import '../services/encryption_service.dart';

class RecordDetailPage extends StatelessWidget {
  final MedicalRecord record;

  const RecordDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(record.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: DecryptedRecordDetailView(record: record),
    );
  }
}

class DecryptedRecordDetailView extends StatefulWidget {
  final MedicalRecord record;

  const DecryptedRecordDetailView({super.key, required this.record});

  @override
  State<DecryptedRecordDetailView> createState() => _DecryptedRecordDetailViewState();
}

class _DecryptedRecordDetailViewState extends State<DecryptedRecordDetailView> {
  final _encryptionService = EncryptionService();
  final _aiSummaryService = AiSummaryService();
  
  bool _isLoading = true;
  String? _decryptedTitle;
  String? _decryptedCategory;
  String? _decryptedDescription;
  
  bool _isSummarizing = false;
  String? _summary;

  Future<void> _openFile(String? filePath) async {
    if (filePath == null) return;
    try {
      final ref = FirebaseStorage.instance.ref().child(filePath);
      final url = await ref.getDownloadURL();
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }

  Future<void> _getAiSummary() async {
    if (widget.record.attachmentUrl == null) return;

    setState(() {
      _isSummarizing = true;
    });

    final summary = await _aiSummaryService.summarize(widget.record.attachmentUrl!);

    setState(() {
      _summary = summary;
      _isSummarizing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _encryptionService.decryptData(widget.record.description),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final decryptedDescription = snapshot.data ?? '';

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (decryptedDescription.isNotEmpty) ...[
                      _buildSectionTitle(context, 'Doctor\'s Notes'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: Text(
                          decryptedDescription,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, letterSpacing: 0.2),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    
                    _buildSectionTitle(context, 'Document Attachment'),
                    const SizedBox(height: 12),
                    _buildAttachmentCard(context),
                    const SizedBox(height: 32),
                    
                    _buildSectionTitle(context, 'AI Insights'),
                    const SizedBox(height: 12),
                    _buildAiSummarySection(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.record.category.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.record.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Recorded on ${widget.record.date}',
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildAttachmentCard(BuildContext context) {
    final isPdf = widget.record.attachmentType == 'pdf';
    return InkWell(
      onTap: () => _openFile(widget.record.attachmentUrl),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isPdf ? Colors.red : Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                color: isPdf ? Colors.red : Colors.blue,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPdf ? 'Medical Report (PDF)' : 'Medical Image',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  Text(
                    'Tap to view original document',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSummarySection(BuildContext context) {
    if (_summary == null && !_isSummarizing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.withOpacity(0.05), Colors.blue.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.purple.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.purple[300], size: 40),
            const SizedBox(height: 16),
            const Text(
              'Understand this record better',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Medi AI can summarize the key findings and results from this report for you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _getAiSummary,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate AI Summary'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ),
      );
    }

    if (_isSummarizing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: const Column(
          children: [
            CircularProgressIndicator(color: Colors.purple),
            SizedBox(height: 16),
            Text('Analyzing document...', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.purple[400], size: 20),
              const SizedBox(width: 8),
              Text(
                'AI SUMMARY',
                style: TextStyle(color: Colors.purple[400], fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _summary!,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Note: AI summaries are for informational purposes only. Please consult your doctor for medical advice.',
            style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
