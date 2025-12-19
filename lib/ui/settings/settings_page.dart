import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../app_theme.dart';
import '../../core/services/detection_storage_service.dart';
import '../../core/services/firebase_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isClearingLocal = false;
  bool _isClearingFirebase = false;
  bool _isFirebaseConnected = false;

  @override
  void initState() {
    super.initState();
    _checkFirebaseConnection();
  }

  Future<void> _checkFirebaseConnection() async {
    final isConnected = await FirebaseService.instance.quickConnectionTest();
    setState(() {
      _isFirebaseConnected = isConnected;
    });
  }

  Future<void> _clearLocalData() async {
    final confirmed = await _showConfirmationDialog(
      'Clear Local Data',
      'This will permanently delete all detection records stored on this device. This action cannot be undone.',
    );

    if (!confirmed) return;

    setState(() => _isClearingLocal = true);

    try {
      await DetectionStorageService.instance.clearAllRecords();
      
      // Reload the storage to clear cached data
      await DetectionStorageService.instance.loadRecords();
      
      if (mounted) {
        _showSuccessDialog('Local data cleared successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to clear local data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingLocal = false);
      }
    }
  }

  Future<void> _clearFirebaseData() async {
    final confirmed = await _showConfirmationDialog(
      'Clear Firebase Data',
      'This will permanently delete all detection records from Firebase Realtime Database. This action cannot be undone and will affect all users of this app.',
    );



    if (!confirmed) return;

    setState(() => _isClearingFirebase = true);

    try {
      await FirebaseService.instance.clearAllDetections();
      
      if (mounted) {
        _showSuccessDialog('Firebase data cleared successfully!');
      }
      
      // Recheck connection after clearing
      await _checkFirebaseConnection();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to clear Firebase data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingFirebase = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Firebase Connection Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isFirebaseConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: _isFirebaseConnected ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Firebase Connection',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _isFirebaseConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 14,
                            color: _isFirebaseConnected ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _checkFirebaseConnection,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Clear Local Data
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storage, color: AppColors.primaryBlue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clear Local Data',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Remove all detection records from device storage',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isClearingLocal ? null : _clearLocalData,
                      icon: _isClearingLocal
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      label: Text(_isClearingLocal ? 'Clearing...' : 'Clear Local Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Clear Firebase Data
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud,
                        color: _isFirebaseConnected ? AppColors.primaryBlue : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clear Firebase Data',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Remove all detection records from Firebase',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (!_isFirebaseConnected || _isClearingFirebase) 
                          ? null 
                          : _clearFirebaseData,
                      icon: _isClearingFirebase
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      label: Text(_isClearingFirebase 
                          ? 'Clearing...' 
                          : _isFirebaseConnected 
                              ? 'Clear Firebase Data' 
                              : 'Firebase Not Connected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFirebaseConnected 
                            ? Colors.red.withOpacity(0.1) 
                            : Colors.grey.withOpacity(0.1),
                        foregroundColor: _isFirebaseConnected ? Colors.red : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (!_isFirebaseConnected) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Firebase is not connected. Check your internet connection.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Warning Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Warning',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Clearing data is permanent and cannot be undone. Local data affects only this device, while Firebase data affects all users of the app.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
