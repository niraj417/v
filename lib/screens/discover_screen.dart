import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../models/lead.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  InAppWebViewController? _webViewController;
  final List<Lead> _searchResults = [];
  bool _isScraping = false;
  String? _searchUrl;

  @override
  void dispose() {
    _keywordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _startSearch() {
    final keyword = _keywordController.text.trim();
    final location = _locationController.text.trim();

    if (keyword.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both keyword and location')),
      );
      return;
    }
    
    setState(() {
      _isScraping = true;
      _searchResults.clear();
      _searchUrl = 'https://www.google.com/maps/search/\${Uri.encodeComponent("\$keyword in \$location")}';
    });
    
    // If controller is already available, load the URL directly
    if (_webViewController != null && _searchUrl != null) {
      _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(_searchUrl!)));
    }
  }

  void _stopScraping() {
    setState(() {
       _isScraping = false;
    });
  }

  void _injectScrapingScript() async {
    if (_webViewController == null || !_isScraping) return;

    final script = """
      (function() {
        var results = [];
        
        // Google Maps Standard Results Feed
        var elements = document.querySelectorAll('div[role="feed"] > div > div > a');
        
        if (elements.length === 0) {
           elements = document.querySelectorAll('.tIqj1b'); // Alternative class used occasionally
        }

        elements.forEach(function(el) {
           var parent = el.closest('div');
           if (!parent) return;
           var textContent = parent.innerText;
           if (!textContent) return;
           
           var nameMatch = textContent.split('\\n')[0];
           
           // Simple regex for phone numbers in the text block (e.g. +1 555-123-4567, (123) 456-7890)
           var phoneRegex = /\\+?\\d{1,4}?[-.\\s]?\\(?\\d{1,3}?\\)?[-.\\s]?\\d{1,4}[-.\\s]?\\d{1,4}[-.\\s]?\\d{1,9}/g;
           var phones = textContent.match(phoneRegex);
           
           var phoneStr = null;
           if (phones && phones.length > 0) {
             // Filter out obvious false positives like hours or short digits
             var filtered = phones.filter(p => p.length >= 10);
             if (filtered.length > 0) phoneStr = filtered[0].trim();
           }
           
           // Try to parse rating
           var ratingMatch = textContent.match(/(\\d\\.\\d)\\s*\\(\\d+\\)/);
           var rating = ratingMatch ? parseFloat(ratingMatch[1]) : null;

           if (nameMatch && phoneStr && !results.some(r => r.name === nameMatch)) {
             // Using phone number + name hash as a simple placeId since we don't have the real API one
             var uniqueId = nameMatch.replace(/[^a-zA-Z0-9]/g, '') + '_' + phoneStr.replace(/[^0-9]/g, '');
             results.push({ 
                placeId: uniqueId,
                name: nameMatch, 
                phoneNumber: phoneStr, 
                address: textContent.substring(0, Math.min(textContent.length, 100)) + '...', // Store raw text snippet
                rating: rating
             });
           }
        });
        
        // Scroll down to load more maps results automatically
        var feed = document.querySelector('div[role="feed"]');
        if (feed) {
          feed.scrollBy(0, 800);
        } else {
          window.scrollBy(0, 800);
        }

        return JSON.stringify(results);
      })();
    """;

    try {
      final result = await _webViewController!.evaluateJavascript(source: script);
      
      if (result != null && result is String && mounted) {
        final List<dynamic> parsed = jsonDecode(result);
        
        bool hasNew = false;
        for (var item in parsed) {
          final lead = Lead.fromMap(item);
          if (!_searchResults.any((l) => l.placeId == lead.placeId)) {
             _searchResults.add(lead);
             hasNew = true;
          }
        }
        
        if (hasNew) {
           setState(() {}); // Update the UI with new drops
        }
      }
    } catch(e) {
      debugPrint("Scraping error: \$e");
    }

    // Keep pulsing the scraper script if active
    if (_isScraping && mounted) {
       Future.delayed(const Duration(seconds: 4), _injectScrapingScript);
    }
  }

  void _addToLeads(Lead lead) async {
    try {
      await DatabaseService.instance.create(lead);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\${lead.name} added to My Leads!')),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to add (Might be duplicate).')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Leads'),
      ),
      body: Column(
        children: [
          // Invisible WebView to handle the scraping workload
          SizedBox(
            height: 1, 
            width: 1, 
            child: _searchUrl == null ? const SizedBox() : InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_searchUrl!)),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStop: (controller, url) {
                if (_isScraping) {
                   // Add a delay to let the map feed load completely
                   Future.delayed(const Duration(seconds: 4), _injectScrapingScript);
                }
              },
            ),
          ),
          
          if (_isScraping) const LinearProgressIndicator(),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: 'Keyword (e.g., Plumbers)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location (e.g., New York)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isScraping ? _stopScraping : _startSearch,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _isScraping ? Colors.red.withAlpha(200) : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white
                      ),
                      child: _isScraping 
                          ? const Text('Stop')
                          : const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text('Found: \${_searchResults.length} leads', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
               ],
            ),
          ),

          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Text(
                      _isScraping ? 'Scraping Google Maps, please wait...' : 'Search to start discovering leads.',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final lead = _searchResults[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      lead.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                  if (lead.rating != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 20),
                                        const SizedBox(width: 4),
                                        Text(lead.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (lead.phoneNumber != null)
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(lead.phoneNumber!, style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _addToLeads(lead),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Save Lead'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
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
