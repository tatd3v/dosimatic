import 'package:shared_preferences/shared_preferences.dart';
import '../global/global_constantes.dart';
import '../models/contact_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ContactService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static String get baseUrl => '${Constants.serverapp}/api';

  static const String token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwiaWF0IjoxNzUxODI3MDYwLCJleHAiOjE3NTE5MTM0NjB9.4qMiJhSnSpKEuhoEcqDtxjK2UKX6DltuBQHymF9NqMA';

  //static const String token =
  //  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwiaWF0IjoxNzQ1MzQ3MzQxLCJleHAiOjE3NDU0MzM3NDF9.lOJ2idj8kniCAhvB2IvVwEyNwYS3e5xfrlm2Wui6SDg';

  //'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwiaWF0IjoxNzQ0NjQ3MjE0LCJleHAiOjE3NDQ3MzM2MTR9.UhS4FUusUIYtySz7nYMa0UFxRuD5Xn90QP7h5W2AswE';
  static Future<List<Contact>> getContacts({
    int page = 1,
    int limit = 10,
    int status = 1,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'status': status.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final tokenrecuprado = await getToken();
      print('tokenrecuprado: $tokenrecuprado');

      final response = await http.get(
        Uri.parse('$baseUrl/contacts').replace(queryParameters: queryParams),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $tokenrecuprado',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> contactsJson = data['data'] ?? [];
        return contactsJson.map((json) => Contact.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load contacts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load contacts: $e');
    }
  }

  static final List<String> _firstNames = [
    'John',
    'Mary',
    'James',
    'Patricia',
    'Robert',
    'Jennifer',
    'Michael',
    'Linda',
    'William',
    'Elizabeth',
    'David',
    'Barbara',
    'Richard',
    'Susan',
    'Joseph',
    'Jessica',
    'Felipe',
  ];

  static final List<String> _lastNames = [
    'Smith',
    'Johnson',
    'Williams',
    'Brown',
    'Jones',
    'Garcia',
    'Miller',
    'Davis',
    'Rodriguez',
    'Martinez',
    'Hernandez',
    'Lopez',
    'Gonzalez',
    'Wilson',
    'Anderson',
    'Escalada'
  ];

  static final List<String> _companies = [
    'Dynabox',
    'Rooxo',
    'Agivu',
    'Twitterbridge',
    'Ozu',
    'Quimm',
    'Gigabox',
    'Technica',
    'Innovate',
    'DataFlow',
    'WebSys',
    'CloudNet',
    'SmartTech',
    'CoreSys'
  ];

  static final List<String> _domains = [
    'gmail.com',
    'yahoo.com',
    'hotmail.com',
    'outlook.com',
    'company.com',
    'business.net',
    'corporate.org',
    'enterprise.com'
  ];

  static String _generatePhoneNumber() {
    return '91+ ${(1000000000 + DateTime.now().millisecondsSinceEpoch % 9000000000).toString()}';
  }

  static String _generateEmail(String firstName, String lastName) {
    return '${firstName.toLowerCase()}${lastName.toLowerCase()}@${_domains[DateTime.now().millisecondsSinceEpoch % _domains.length]}';
  }

  static DateTime _generateDate() {
    final random =
        DateTime.now().millisecondsSinceEpoch % (365 * 24 * 60 * 60 * 1000);
    return DateTime.now().subtract(Duration(milliseconds: random));
  }

  // Simulated data
  static String generateId([int? index]) {
    if (index != null) {
      return 'CONT${index.toString().padLeft(6, '0')}';
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp % 1000000;
    return 'CONT${random.toString().padLeft(6, '0')}';
  }

  static List<Contact> getMockContacts() {
    final List<Contact> contacts = [];
    for (int i = 0; i < 500; i++) {
      final firstName = _firstNames[i % _firstNames.length];
      final lastName = _lastNames[i % _lastNames.length];
      contacts.add(
        Contact(
          idContact: generateId(i + 1),
          firstName: firstName,
          lastName: lastName,
          businessName: _companies[i % _companies.length],
          email: _generateEmail(firstName, lastName),
          phoneNumber: _generatePhoneNumber(),
          country: 1,
          city: 1,
          zipCode: '${10000 + i}',
          frontPartUrl: '',
          backPartUrl: '',
          createdAt: _generateDate(),
        ),
      );
    }
    return contacts;
  }
}
