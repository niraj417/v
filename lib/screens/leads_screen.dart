import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/lead.dart';
import '../services/database_service.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  List<Lead> _leads = [];
  String _selectedStatus = 'All';
  final List<String> _statusOptions = ['All', 'Uncontacted', 'Converted', 'Not Converted', 'Bad Lead'];
  String _templateMessage = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadTemplate();
    await _fetchLeads();
    setState(() => _isLoading = false);
  }

  Future<void> _loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    _templateMessage = prefs.getString('whatsapp_template') ?? 'Hi [Name], we would love to connect with you!';
  }

  Future<void> _fetchLeads() async {
    if (_selectedStatus == 'All') {
      _leads = await DatabaseService.instance.readAllLeads();
    } else {
      _leads = await DatabaseService.instance.readLeadsByStatus(_selectedStatus);
    }
    setState(() {});
  }

  Future<void> _updateLeadStatus(Lead lead, String newStatus) async {
    final updatedLead = lead.copyWith(status: newStatus);
    await DatabaseService.instance.update(updatedLead);
    _fetchLeads(); // Refresh list
  }

  Future<void> _callLead(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsappLead(Lead lead) async {
    if (lead.phoneNumber == null) return;
    
    final cleanPhone = lead.phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
    final message = _templateMessage.replaceAll('[Name]', lead.name);
    final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _exportLeads() async {
    if (_leads.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No leads to export.')),
      );
      return;
    }
    
    try {
      List<List<dynamic>> rows = [];
      // Header row
      rows.add(["Name", "Phone", "Address", "Website", "Status", "Rating"]);
      
      // Data rows
      for (var lead in _leads) {
        rows.add([
          lead.name,
          lead.phoneNumber ?? '',
          lead.address ?? '',
          lead.website ?? '',
          lead.status,
          lead.rating ?? ''
        ]);
      }
      
      String csvData = rows.map((row) {
        return row.map((field) {
          String stringField = field.toString();
          if (stringField.contains(',') || stringField.contains('"') || stringField.contains('\n')) {
            return '"${stringField.replaceAll('"', '""')}"';
          }
          return stringField;
        }).join(',');
      }).join('\n');
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/leads_export.csv';
      final file = File(path);
      await file.writeAsString(csvData);
      
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], text: 'Exported Leads');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export leads: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Converted': return const Color(0xFF10B981); // emerald-500
      case 'Not Converted': return const Color(0xFFF59E0B); // amber-500
      case 'Bad Lead': return const Color(0xFFEF4444); // red-500
      case 'Uncontacted':
      default: return const Color(0xFF1337EC); // primary
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Converted': return const Color(0xFF10B981).withAlpha(25);
      case 'Not Converted': return const Color(0xFFF59E0B).withAlpha(25);
      case 'Bad Lead': return const Color(0xFFEF4444).withAlpha(25);
      case 'Uncontacted':
      default: return const Color(0xFF1337EC).withAlpha(25);
    }
  }

  void _showStatusDialog(Lead lead) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _statusOptions
                .where((status) => status != 'All')
                .map((status) => ListTile(
                      title: Text(status),
                      leading: Icon(Icons.circle, color: _getStatusColor(status), size: 16),
                      onTap: () {
                        _updateLeadStatus(lead, status);
                        Navigator.of(context).pop();
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leads Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLeads,
            tooltip: 'Export CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLeads,
            tooltip: 'Refresh Leads',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: _statusOptions.map((status) {
                  final isSelected = _selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = status;
                        });
                        _fetchLeads();
                      },
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _leads.isEmpty
                    ? Center(
                        child: Text(
                          'No leads found for "\$_selectedStatus".\nGo to Discover to fetch new leads!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _leads.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          final lead = _leads[index];
                          final primaryColor = const Color(0xFF1337EC);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(10),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  height: 48,
                                                  width: 48,
                                                  decoration: BoxDecoration(
                                                    color: primaryColor.withAlpha(25),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(Icons.business, color: primaryColor),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        lead.name,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, height: 1.1),
                                                      ),
                                                      if (lead.website != null && lead.website!.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 4.0),
                                                          child: Text(
                                                            lead.website!,
                                                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusBgColor(lead.status),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              lead.status.toUpperCase(),
                                              style: TextStyle(
                                                color: _getStatusColor(lead.status),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Details
                                      if (lead.phoneNumber != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              Icon(Icons.call, size: 16, color: Colors.grey.shade600),
                                              const SizedBox(width: 8),
                                              Text(lead.phoneNumber!, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                                            ],
                                          ),
                                        ),
                                      if (lead.address != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                                              const SizedBox(width: 8),
                                              Expanded(child: Text(lead.address!, style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Action Buttons (Bottom Bar)
                                Container(
                                  decoration: BoxDecoration(
                                     border: Border(top: BorderSide(color: Colors.grey.shade200))
                                  ),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: lead.phoneNumber != null && lead.phoneNumber!.isNotEmpty ? () => _callLead(lead.phoneNumber!) : null,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                   Icon(Icons.call, color: primaryColor, size: 20),
                                                   const SizedBox(width: 8),
                                                   Text('Call', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                ],
                                              ),
                                            )
                                          ),
                                        ),
                                        VerticalDivider(width: 1, color: Colors.grey.shade200),
                                        Expanded(
                                          child: InkWell(
                                            onTap: lead.phoneNumber != null && lead.phoneNumber!.isNotEmpty ? () => _whatsappLead(lead) : null,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                   Icon(Icons.message, color: primaryColor, size: 20),
                                                   const SizedBox(width: 8),
                                                   Text('Message', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                ],
                                              ),
                                            )
                                          ),
                                        ),
                                        VerticalDivider(width: 1, color: Colors.grey.shade200),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _showStatusDialog(lead),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                   Icon(Icons.assignment, color: primaryColor, size: 20),
                                                   const SizedBox(width: 8),
                                                   Text('Status', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                ],
                                              ),
                                            )
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
