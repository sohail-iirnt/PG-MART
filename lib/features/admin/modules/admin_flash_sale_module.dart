import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminFlashSaleModule extends StatefulWidget {
  const AdminFlashSaleModule({super.key});

  @override
  State<AdminFlashSaleModule> createState() => _AdminFlashSaleModuleState();
}

class _AdminFlashSaleModuleState extends State<AdminFlashSaleModule> {
  bool _isActive = false;
  final _titleController = TextEditingController();
  DateTime? _deadline;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final doc = await FirebaseFirestore.instance.collection('store_settings').doc('flash_sale').get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      setState(() {
        _isActive = data['isActive'] ?? false;
        _titleController.text = data['title'] ?? 'PG MART FLASH SALE';
        if (data['deadline'] != null) {
          _deadline = (data['deadline'] as Timestamp).toDate();
        }
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    // === FIX 1: Prevent Date Picker Crash ===
    // If the saved deadline is in the past, reset the calendar to 'today' so it doesn't crash
    DateTime startingDate = _deadline ?? now.add(const Duration(days: 1));
    if (startingDate.isBefore(now)) {
      startingDate = now;
    }

    final date = await showDatePicker(
        context: context,
        initialDate: startingDate,
        // === FIX 2: Added a 1-day buffer to prevent micro-second timing crashes ===
        firstDate: now.subtract(const Duration(days: 1)),
        lastDate: DateTime(2030)
    );

    // === FIX 3: Safely check for mounted state across the async gap ===
    if (date == null || !mounted) return;

    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(startingDate)
    );

    if (time == null || !mounted) return;

    setState(() {
      _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _saveSettings() async {
    if (_isActive && _deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a deadline!')));
      return;
    }

    setState(() => _isLoading = true);
    await FirebaseFirestore.instance.collection('store_settings').doc('flash_sale').set({
      'isActive': _isActive,
      'title': _titleController.text.trim(),
      'deadline': _deadline != null ? Timestamp.fromDate(_deadline!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() => _isLoading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flash Sale Updated!'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash Sale Manager'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[200]!)),
              child: SwitchListTile(
                title: const Text('Enable Flash Sale Banner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Shows the red countdown timer on the Home Screen.'),
                value: _isActive,
                activeColor: Colors.red,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ),
            const SizedBox(height: 24),

            if (_isActive) ...[
              const Text('Banner Title', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), hintText: 'e.g., DIWALI MEGA SALE'),
              ),
              const SizedBox(height: 24),

              const Text('Sale Deadline', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_deadline == null ? 'Tap to select Date & Time' : DateFormat('dd MMM yyyy, hh:mm a').format(_deadline!), style: TextStyle(fontSize: 16, color: _deadline == null ? Colors.grey : Colors.black)),
                      const Icon(Icons.calendar_month, color: Colors.red),
                    ],
                  ),
                ),
              ),
            ],

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isLoading ? null : _saveSettings,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE SETTINGS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}