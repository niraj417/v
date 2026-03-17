import 'package:flutter/material.dart';
import '../services/places_service.dart';
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
  final PlacesService _placesService = PlacesService();

  List<Lead> _searchResults = [];
  bool _isLoading = false;

  void _search() async {
    final keyword = _keywordController.text.trim();
    final location = _locationController.text.trim();

    if (keyword.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both keyword and location')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults.clear();
    });

    try {
      final results = await _placesService.searchPlaces(keyword, location);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addToLeads(Lead lead) async {
    try {
      // Fetch details (phone, website)
      final detailedLead = await _placesService.getPlaceDetails(lead);
      if (detailedLead != null) {
        await DatabaseService.instance.create(detailedLead);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('\${lead.name} added to My Leads!')),
          );
        }
      } else {
         throw Exception("Failed to get details");
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to add: \$e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Leads'),
      ),
      body: Padding(
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
                  onPressed: _isLoading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _isLoading ? 'Searching...' : 'No results to display.',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final lead = _searchResults[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
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
                                if (lead.address != null)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(lead.address!, style: const TextStyle(color: Colors.grey))),
                                    ],
                                  ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _addToLeads(lead),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add to Leads'),
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
      ),
    );
  }
}
