import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Converted': return Colors.green;
      case 'Not Converted': return Colors.orange;
      case 'Bad Lead': return Colors.red;
      case 'Uncontacted':
      default: return Colors.grey;
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
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLeads,
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
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: Name and Status Badge
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lead.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(lead.status).withAlpha(25),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: _getStatusColor(lead.status)),
                                        ),
                                        child: Text(
                                          lead.status,
                                          style: TextStyle(
                                            color: _getStatusColor(lead.status),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Details
                                  if (lead.phoneNumber != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone, size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Text(lead.phoneNumber!, style: const TextStyle(fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  if (lead.address != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(lead.address!, style: const TextStyle(fontSize: 14, color: Colors.grey))),
                                        ],
                                      ),
                                    ),
                                  if (lead.website != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.language, size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              lead.website!, 
                                              style: const TextStyle(fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline),
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          ),
                                        ],
                                      ),
                                    ),

                                  const Divider(),
                                  
                                  // Action Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      TextButton.icon(
                                        onPressed: lead.phoneNumber != null ? () => _callLead(lead.phoneNumber!) : null,
                                        icon: const Icon(Icons.call, color: Colors.green),
                                        label: const Text('Call'),
                                      ),
                                      TextButton.icon(
                                        onPressed: lead.phoneNumber != null ? () => _whatsappLead(lead) : null,
                                        icon: const Icon(Icons.message, color: Colors.teal),
                                        label: const Text('WhatsApp'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _showStatusDialog(lead),
                                        icon: const Icon(Icons.edit, color: Colors.orange),
                                        label: const Text('Status'),
                                      ),
                                    ],
                                  )
                                ],
                              ),
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
