import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lead.dart';

class PlacesService {
  // Replace with your actual Google Places API Key
  static const String apiKey = 'AIzaSyD3XRcQKptSnMpy-GaVXnlXoqo6SSmjEYQ';

  Future<List<Lead>> searchPlaces(String query, String location) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=\$query+in+\$location&key=\$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] as List;

      List<Lead> leads = [];
      for (var result in results) {
        final placeId = result['place_id'];
        final name = result['name'];
        final rating = result['rating']?.toDouble();
        final address = result['formatted_address'];

        leads.add(Lead(
          placeId: placeId,
          name: name,
          address: address,
          rating: rating,
        ));
      }
      return leads;
    } else {
      throw Exception('Failed to load places');
    }
  }

  Future<Lead?> getPlaceDetails(Lead lead) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=\${lead.placeId}&fields=formatted_phone_number,website&key=\$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final result = data['result'];

      if (result != null) {
        return lead.copyWith(
          phoneNumber: result['formatted_phone_number'],
          website: result['website'],
        );
      }
    }
    return null;
  }
}
