import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../models/lead.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final List<Lead> _leads = [];
  bool _isScraping = false;
  String? _keyword;
  String? _location;
  InAppWebViewController? webViewController;
  String _templateMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    _templateMessage = prefs.getString('whatsapp_template') ?? 'Hi [Name], we would love to connect with you!';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _keyword == null) {
      _keyword = args['keyword'];
      _location = args['location'];
      _startScraping();
    }
  }

  void _startScraping() {
    setState(() {
      _isScraping = true;
      _leads.clear();
    });
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

  void _injectScrapingScript() async {
    if (webViewController == null || !_isScraping) return;

    // A script to extract results from standard Google Maps search page
    final script = """
      (function() {
        var results = [];
        // The classes heavily rely on current maps structure, which is fragile
        // For standard local search page:
        var elements = document.querySelectorAll('div[role="feed"] > div > div > a');
        
        if (elements.length === 0) {
          // Alternative selector depending on view
          elements = document.querySelectorAll('.tIqj1b'); 
        }

        elements.forEach(function(el) {
           var parent = el.closest('div');
           if (!parent) return;
           var textContent = parent.innerText;
           if (!textContent) return;
           
           var nameMatch = textContent.split('\\n')[0];
           
           // Simple regex for phone numbers in the text block
           var phoneRegex = /\\+?\\d{1,4}?[-.\\s]?\\(?\\d{1,3}?\\)?[-.\\s]?\\d{1,4}[-.\\s]?\\d{1,4}[-.\\s]?\\d{1,9}/g;
           var phones = textContent.match(phoneRegex);
           
           var phoneStr = null;
           if (phones && phones.length > 0) {
             // Filter out obvious false positives like hours or short digits
             var filtered = phones.filter(p => p.length >= 10);
             if (filtered.length > 0) phoneStr = filtered[0].trim();
           }

           if (nameMatch && phoneStr && !results.some(r => r.name === nameMatch)) {
             results.push({ name: nameMatch, phoneNumber: phoneStr, address: textContent });
           }
        });
        
        // Scroll down to load more
        var feed = document.querySelector('div[role="feed"]');
        if (feed) {
          feed.scrollBy(0, 500);
        } else {
          window.scrollBy(0, 500);
        }

        return JSON.stringify(results);
      })();
    """;

    try {
      final result = await webViewController!.evaluateJavascript(source: script);
      if (result != null && result is String) {
        final List<dynamic> parsed = jsonDecode(result);
        
        int newLeads = 0;
        for (var item in parsed) {
          final lead = Lead.fromMap(item);
          if (!_leads.any((l) => l.phoneNumber == lead.phoneNumber)) {
             _leads.add(lead);
             newLeads++;
          }
        }
        
        if (newLeads > 0 && mounted) {
           setState(() {}); // Update UI
        }
      }
    } catch(e) {
      print("Scraping error: \$e");
    }

    // Keep scraping if active
    if (_isScraping) {
       Future.delayed(const Duration(seconds: 3), _injectScrapingScript);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Generate the URL for Google Maps search
    final query = Uri.encodeComponent("\$_keyword in \$_location");
    final searchUrl = 'https://www.google.com/maps/search/\$query';

    return Scaffold(
      appBar: AppBar(
        title: Text('Leads for "\$_keyword"'),
      ),
      body: Column(
        children: [
          // Hidden WebView for Scraping
          SizedBox(
            height: 1, 
            width: 1, 
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(searchUrl)),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onLoadStop: (controller, url) {
                if (_isScraping) {
                   Future.delayed(const Duration(seconds: 2), _injectScrapingScript);
                }
              },
            ),
          ),

          if (_isScraping) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Found: \${_leads.length} leads', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_isScraping)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isScraping = false;
                      });
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Scraping'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _leads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Searching Google Maps for "\$_keyword"...'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _leads.length,
                    itemBuilder: (context, index) {
                      final lead = _leads[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(lead.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(lead.phoneNumber ?? lead.address ?? 'No contact info'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.call, color: Colors.green),
                                onPressed: lead.phoneNumber != null 
                                    ? () => _callLead(lead.phoneNumber!)
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.message, color: Colors.teal),
                                onPressed: lead.phoneNumber != null
                                    ? () => _whatsappLead(lead)
                                    : null,
                              ),
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
