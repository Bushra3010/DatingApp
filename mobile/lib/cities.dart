import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// An Indian city with its state and rough centre, for the city field's
/// suggestions and for turning a location into a city name on the device
/// (no geocoding service is called).
class City {
  const City(this.name, this.state, this.lat, this.lng, [this.aliases = const []]);
  final String name, state;
  final double lat, lng;

  /// Old or other names people type, e.g. Bombay for Mumbai.
  final List<String> aliases;

  String get label => '$name, $state';

  double kmTo(double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat), dLng = rad(lng2 - lng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}

/// "Aurangabad, Maharashtra" -> "aurangabad", for comparing cities typed
/// with or without the state.
String cityKey(String city) => city.split(',').first.trim().toLowerCase();

/// Up to [limit] cities for what's been typed: names starting with it
/// first, then other names, then names or states containing it.
List<City> suggestCities(String query, {int limit = 6}) {
  final q = cityKey(query);
  if (q.length < 2) return const [];
  final starts = <City>[], aliasStarts = <City>[], contains = <City>[];
  for (final c in indianCities) {
    final name = c.name.toLowerCase();
    if (name.startsWith(q)) {
      starts.add(c);
    } else if (c.aliases.any((a) => a.toLowerCase().startsWith(q))) {
      aliasStarts.add(c);
    } else if (name.contains(q) || c.state.toLowerCase().startsWith(q)) {
      contains.add(c);
    }
  }
  return [...starts, ...aliasStarts, ...contains].take(limit).toList();
}

/// The listed city nearest to a point, if one is within [maxKm].
City? nearestCity(double lat, double lng, {double maxKm = 60}) {
  City? best;
  var bestKm = double.infinity;
  for (final c in indianCities) {
    final km = c.kmTo(lat, lng);
    if (km < bestKm) {
      best = c;
      bestKm = km;
    }
  }
  return bestKm <= maxKm ? best : null;
}

/// Finds the member's city from their current location, once, at low
/// accuracy. Returns the city, or throws a message to show.
Future<City> detectCity() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw 'Turn on location services, or type your city.';
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw 'Allow location access, or type your city.';
  }
  final Position at;
  try {
    at = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)));
  } catch (_) {
    throw 'Couldn’t find your location. Type your city instead.';
  }
  final city = nearestCity(at.latitude, at.longitude);
  if (city == null) throw 'Couldn’t match your location to a city. Type it instead.';
  return city;
}

/// A city text field that suggests "City, State" as you type, with a
/// button to fill it from your current location.
class CityField extends StatefulWidget {
  const CityField(
      {super.key,
      required this.controller,
      this.hintText = 'Start typing your city',
      this.labelText});
  final TextEditingController controller;
  final String hintText;
  final String? labelText;

  @override
  State<CityField> createState() => _CityFieldState();
}

class _CityFieldState extends State<CityField> {
  final focus = FocusNode();
  bool locating = false;
  String? error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    focus.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    focus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _pick(City c) {
    widget.controller.value = TextEditingValue(
        text: c.label, selection: TextSelection.collapsed(offset: c.label.length));
    focus.unfocus();
    setState(() => error = null);
  }

  Future<void> _locate() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      _pick(await detectCity());
    } catch (e) {
      setState(() => error = e is String ? e : 'Couldn’t find your location.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = widget.controller.text;
    final matches = focus.hasFocus
        ? suggestCities(text).where((c) => c.label != text.trim()).toList()
        : const <City>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
          controller: widget.controller,
          focusNode: focus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (matches.isNotEmpty) _pick(matches.first);
          },
          decoration: InputDecoration(
              hintText: widget.hintText,
              labelText: widget.labelText,
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: IconButton(
                  tooltip: 'Use my current location',
                  onPressed: locating ? null : _locate,
                  icon: locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded)))),
      if (matches.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final c in matches)
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 20),
                  title: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(c.state),
                  onTap: () => _pick(c)),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
            onPressed: locating ? null : _locate,
            icon: const Icon(Icons.near_me_outlined, size: 18),
            label: Text(locating ? 'Finding your city…' : 'Use my current location')),
      ),
      if (error != null)
        Text(error!, style: TextStyle(color: scheme.error, fontSize: 13)),
    ]);
  }
}

const indianCities = <City>[
  // Maharashtra
  City('Mumbai', 'Maharashtra', 19.076, 72.8777, ['Bombay']),
  City('Pune', 'Maharashtra', 18.5204, 73.8567, ['Poona']),
  City('Nagpur', 'Maharashtra', 21.1458, 79.0882),
  City('Thane', 'Maharashtra', 19.2183, 72.9781),
  City('Navi Mumbai', 'Maharashtra', 19.033, 73.0297),
  City('Nashik', 'Maharashtra', 19.9975, 73.7898),
  City('Aurangabad', 'Maharashtra', 19.8762, 75.3433, ['Chhatrapati Sambhajinagar', 'Sambhajinagar']),
  City('Solapur', 'Maharashtra', 17.6599, 75.9064),
  City('Kolhapur', 'Maharashtra', 16.705, 74.2433),
  City('Amravati', 'Maharashtra', 20.9374, 77.7796),
  City('Nanded', 'Maharashtra', 19.1383, 77.321),
  City('Sangli', 'Maharashtra', 16.8524, 74.5815),
  City('Jalgaon', 'Maharashtra', 21.0077, 75.5626),
  City('Akola', 'Maharashtra', 20.7002, 77.0082),
  City('Latur', 'Maharashtra', 18.4088, 76.5604),
  City('Ahmednagar', 'Maharashtra', 19.0948, 74.748, ['Ahilyanagar']),
  City('Dhule', 'Maharashtra', 20.9042, 74.7749),
  City('Satara', 'Maharashtra', 17.6805, 74.0183),
  City('Chandrapur', 'Maharashtra', 19.9615, 79.2961),
  City('Parbhani', 'Maharashtra', 19.2608, 76.7748),
  City('Jalna', 'Maharashtra', 19.8347, 75.8816),
  City('Ratnagiri', 'Maharashtra', 16.9902, 73.312),
  City('Beed', 'Maharashtra', 18.9891, 75.756),
  City('Wardha', 'Maharashtra', 20.7453, 78.6022),
  City('Yavatmal', 'Maharashtra', 20.3888, 78.1204),
  City('Osmanabad', 'Maharashtra', 18.186, 76.0419, ['Dharashiv']),
  City('Lonavala', 'Maharashtra', 18.7546, 73.4062),
  // Delhi NCR
  City('New Delhi', 'Delhi', 28.6139, 77.209, ['Delhi']),
  City('Gurugram', 'Haryana', 28.4595, 77.0266, ['Gurgaon']),
  City('Noida', 'Uttar Pradesh', 28.5355, 77.391),
  City('Greater Noida', 'Uttar Pradesh', 28.4744, 77.504),
  City('Ghaziabad', 'Uttar Pradesh', 28.6692, 77.4538),
  City('Faridabad', 'Haryana', 28.4089, 77.3178),
  // Karnataka
  City('Bengaluru', 'Karnataka', 12.9716, 77.5946, ['Bangalore']),
  City('Mysuru', 'Karnataka', 12.2958, 76.6394, ['Mysore']),
  City('Mangaluru', 'Karnataka', 12.9141, 74.856, ['Mangalore']),
  City('Hubballi', 'Karnataka', 15.3647, 75.124, ['Hubli', 'Dharwad']),
  City('Belagavi', 'Karnataka', 15.8497, 74.4977, ['Belgaum']),
  City('Kalaburagi', 'Karnataka', 17.3297, 76.8343, ['Gulbarga']),
  City('Davanagere', 'Karnataka', 14.4644, 75.9218),
  City('Ballari', 'Karnataka', 15.1394, 76.9214, ['Bellary']),
  City('Shivamogga', 'Karnataka', 13.9299, 75.5681, ['Shimoga']),
  City('Tumakuru', 'Karnataka', 13.3379, 77.1173, ['Tumkur']),
  City('Udupi', 'Karnataka', 13.3409, 74.7421, ['Manipal']),
  // Tamil Nadu
  City('Chennai', 'Tamil Nadu', 13.0827, 80.2707, ['Madras']),
  City('Coimbatore', 'Tamil Nadu', 11.0168, 76.9558),
  City('Madurai', 'Tamil Nadu', 9.9252, 78.1198),
  City('Tiruchirappalli', 'Tamil Nadu', 10.7905, 78.7047, ['Trichy']),
  City('Salem', 'Tamil Nadu', 11.6643, 78.146),
  City('Tirunelveli', 'Tamil Nadu', 8.7139, 77.7567),
  City('Tiruppur', 'Tamil Nadu', 11.1085, 77.3411),
  City('Vellore', 'Tamil Nadu', 12.9165, 79.1325),
  City('Erode', 'Tamil Nadu', 11.341, 77.7172),
  City('Thoothukudi', 'Tamil Nadu', 8.7642, 78.1348, ['Tuticorin']),
  City('Thanjavur', 'Tamil Nadu', 10.787, 79.1378, ['Tanjore']),
  City('Ooty', 'Tamil Nadu', 11.4102, 76.695, ['Udhagamandalam']),
  City('Kanchipuram', 'Tamil Nadu', 12.8342, 79.7036),
  // Telangana & Andhra Pradesh
  City('Hyderabad', 'Telangana', 17.385, 78.4867, ['Secunderabad', 'Cyberabad']),
  City('Warangal', 'Telangana', 17.9689, 79.5941),
  City('Karimnagar', 'Telangana', 18.4386, 79.1288),
  City('Nizamabad', 'Telangana', 18.6725, 78.094),
  City('Khammam', 'Telangana', 17.2473, 80.1514),
  City('Visakhapatnam', 'Andhra Pradesh', 17.6868, 83.2185, ['Vizag']),
  City('Vijayawada', 'Andhra Pradesh', 16.5062, 80.648),
  City('Guntur', 'Andhra Pradesh', 16.3067, 80.4365),
  City('Nellore', 'Andhra Pradesh', 14.4426, 79.9865),
  City('Tirupati', 'Andhra Pradesh', 13.6288, 79.4192),
  City('Kurnool', 'Andhra Pradesh', 15.8281, 78.0373),
  City('Kakinada', 'Andhra Pradesh', 16.9891, 82.2475),
  City('Rajahmundry', 'Andhra Pradesh', 17.0005, 81.804, ['Rajamahendravaram']),
  City('Anantapur', 'Andhra Pradesh', 14.6819, 77.6006),
  City('Amaravati', 'Andhra Pradesh', 16.5131, 80.5165),
  // Kerala
  City('Kochi', 'Kerala', 9.9312, 76.2673, ['Cochin', 'Ernakulam']),
  City('Thiruvananthapuram', 'Kerala', 8.5241, 76.9366, ['Trivandrum']),
  City('Kozhikode', 'Kerala', 11.2588, 75.7804, ['Calicut']),
  City('Thrissur', 'Kerala', 10.5276, 76.2144, ['Trichur']),
  City('Kollam', 'Kerala', 8.8932, 76.6141, ['Quilon']),
  City('Kannur', 'Kerala', 11.8745, 75.3704, ['Cannanore']),
  City('Alappuzha', 'Kerala', 9.4981, 76.3388, ['Alleppey']),
  City('Palakkad', 'Kerala', 10.7867, 76.6548, ['Palghat']),
  City('Kottayam', 'Kerala', 9.5916, 76.5222),
  City('Malappuram', 'Kerala', 11.051, 76.0711),
  // West Bengal & East
  City('Kolkata', 'West Bengal', 22.5726, 88.3639, ['Calcutta']),
  City('Howrah', 'West Bengal', 22.5958, 88.2636),
  City('Durgapur', 'West Bengal', 23.5204, 87.3119),
  City('Asansol', 'West Bengal', 23.6739, 86.9524),
  City('Siliguri', 'West Bengal', 26.7271, 88.3953),
  City('Darjeeling', 'West Bengal', 27.041, 88.2663),
  City('Bhubaneswar', 'Odisha', 20.2961, 85.8245),
  City('Cuttack', 'Odisha', 20.4625, 85.883),
  City('Rourkela', 'Odisha', 22.2604, 84.8536),
  City('Puri', 'Odisha', 19.8135, 85.8312),
  City('Sambalpur', 'Odisha', 21.4669, 83.9812),
  City('Berhampur', 'Odisha', 19.3149, 84.7941, ['Brahmapur']),
  City('Patna', 'Bihar', 25.5941, 85.1376),
  City('Gaya', 'Bihar', 24.7914, 85.0002),
  City('Bhagalpur', 'Bihar', 25.2425, 86.9842),
  City('Muzaffarpur', 'Bihar', 26.1209, 85.3647),
  City('Darbhanga', 'Bihar', 26.1542, 85.8918),
  City('Purnia', 'Bihar', 25.7771, 87.4753),
  City('Aurangabad', 'Bihar', 24.7521, 84.3742),
  City('Ranchi', 'Jharkhand', 23.3441, 85.3096),
  City('Jamshedpur', 'Jharkhand', 22.8046, 86.2029),
  City('Dhanbad', 'Jharkhand', 23.7957, 86.4304),
  City('Bokaro', 'Jharkhand', 23.6693, 86.1511),
  City('Hazaribagh', 'Jharkhand', 23.9925, 85.3637),
  // North East
  City('Guwahati', 'Assam', 26.1445, 91.7362),
  City('Dibrugarh', 'Assam', 27.4728, 94.912),
  City('Silchar', 'Assam', 24.8333, 92.7789),
  City('Jorhat', 'Assam', 26.7509, 94.2037),
  City('Shillong', 'Meghalaya', 25.5788, 91.8933),
  City('Imphal', 'Manipur', 24.817, 93.9368),
  City('Agartala', 'Tripura', 23.8315, 91.2868),
  City('Aizawl', 'Mizoram', 23.7271, 92.7176),
  City('Kohima', 'Nagaland', 25.6751, 94.1086),
  City('Dimapur', 'Nagaland', 25.9091, 93.7266),
  City('Itanagar', 'Arunachal Pradesh', 27.0844, 93.6053),
  City('Gangtok', 'Sikkim', 27.3389, 88.6065),
  // Gujarat
  City('Ahmedabad', 'Gujarat', 23.0225, 72.5714),
  City('Surat', 'Gujarat', 21.1702, 72.8311),
  City('Vadodara', 'Gujarat', 22.3072, 73.1812, ['Baroda']),
  City('Rajkot', 'Gujarat', 22.3039, 70.8022),
  City('Gandhinagar', 'Gujarat', 23.2156, 72.6369),
  City('Bhavnagar', 'Gujarat', 21.7645, 72.1519),
  City('Jamnagar', 'Gujarat', 22.4707, 70.0577),
  City('Junagadh', 'Gujarat', 21.5222, 70.4579),
  City('Anand', 'Gujarat', 22.5645, 72.9289),
  City('Bhuj', 'Gujarat', 23.242, 69.6669),
  City('Vapi', 'Gujarat', 20.3893, 72.9106),
  City('Navsari', 'Gujarat', 20.9467, 72.952),
  // Rajasthan
  City('Jaipur', 'Rajasthan', 26.9124, 75.7873),
  City('Jodhpur', 'Rajasthan', 26.2389, 73.0243),
  City('Udaipur', 'Rajasthan', 24.5854, 73.7125),
  City('Kota', 'Rajasthan', 25.2138, 75.8648),
  City('Ajmer', 'Rajasthan', 26.4499, 74.6399),
  City('Bikaner', 'Rajasthan', 28.0229, 73.3119),
  City('Alwar', 'Rajasthan', 27.553, 76.6346),
  City('Bhilwara', 'Rajasthan', 25.3463, 74.6364),
  City('Sikar', 'Rajasthan', 27.6094, 75.1399),
  City('Jaisalmer', 'Rajasthan', 26.9157, 70.9083),
  City('Pushkar', 'Rajasthan', 26.4897, 74.5511),
  // Madhya Pradesh & Chhattisgarh
  City('Indore', 'Madhya Pradesh', 22.7196, 75.8577),
  City('Bhopal', 'Madhya Pradesh', 23.2599, 77.4126),
  City('Jabalpur', 'Madhya Pradesh', 23.1815, 79.9864),
  City('Gwalior', 'Madhya Pradesh', 26.2183, 78.1828),
  City('Ujjain', 'Madhya Pradesh', 23.1765, 75.7885),
  City('Sagar', 'Madhya Pradesh', 23.8388, 78.7378),
  City('Satna', 'Madhya Pradesh', 24.6005, 80.8322),
  City('Rewa', 'Madhya Pradesh', 24.5362, 81.3037),
  City('Ratlam', 'Madhya Pradesh', 23.3315, 75.0367),
  City('Raipur', 'Chhattisgarh', 21.2514, 81.6296),
  City('Bhilai', 'Chhattisgarh', 21.1938, 81.3509, ['Durg']),
  City('Bilaspur', 'Chhattisgarh', 22.0797, 82.1409),
  City('Korba', 'Chhattisgarh', 22.3595, 82.7501),
  // Uttar Pradesh & Uttarakhand
  City('Lucknow', 'Uttar Pradesh', 26.8467, 80.9462),
  City('Kanpur', 'Uttar Pradesh', 26.4499, 80.3319),
  City('Agra', 'Uttar Pradesh', 27.1767, 78.0081),
  City('Varanasi', 'Uttar Pradesh', 25.3176, 82.9739, ['Banaras', 'Benares', 'Kashi']),
  City('Prayagraj', 'Uttar Pradesh', 25.4358, 81.8463, ['Allahabad']),
  City('Meerut', 'Uttar Pradesh', 28.9845, 77.7064),
  City('Bareilly', 'Uttar Pradesh', 28.367, 79.4304),
  City('Aligarh', 'Uttar Pradesh', 27.8974, 78.088),
  City('Moradabad', 'Uttar Pradesh', 28.8386, 78.7733),
  City('Gorakhpur', 'Uttar Pradesh', 26.7606, 83.3732),
  City('Saharanpur', 'Uttar Pradesh', 29.968, 77.5552),
  City('Jhansi', 'Uttar Pradesh', 25.4484, 78.5685),
  City('Mathura', 'Uttar Pradesh', 27.4924, 77.6737, ['Vrindavan']),
  City('Ayodhya', 'Uttar Pradesh', 26.7922, 82.1998, ['Faizabad']),
  City('Dehradun', 'Uttarakhand', 30.3165, 78.0322),
  City('Haridwar', 'Uttarakhand', 29.9457, 78.1642),
  City('Rishikesh', 'Uttarakhand', 30.0869, 78.2676),
  City('Haldwani', 'Uttarakhand', 29.2183, 79.513),
  City('Nainital', 'Uttarakhand', 29.3919, 79.4542),
  City('Roorkee', 'Uttarakhand', 29.8543, 77.888),
  // Punjab, Haryana, Himachal, J&K
  City('Chandigarh', 'Chandigarh', 30.7333, 76.7794),
  City('Mohali', 'Punjab', 30.7046, 76.7179, ['SAS Nagar']),
  City('Ludhiana', 'Punjab', 30.901, 75.8573),
  City('Amritsar', 'Punjab', 31.634, 74.8723),
  City('Jalandhar', 'Punjab', 31.326, 75.5762),
  City('Patiala', 'Punjab', 30.3398, 76.3869),
  City('Bathinda', 'Punjab', 30.211, 74.9455),
  City('Panchkula', 'Haryana', 30.6942, 76.8606),
  City('Ambala', 'Haryana', 30.3782, 76.7767),
  City('Panipat', 'Haryana', 29.3909, 76.9635),
  City('Karnal', 'Haryana', 29.6857, 76.9905),
  City('Rohtak', 'Haryana', 28.8955, 76.6066),
  City('Hisar', 'Haryana', 29.1492, 75.7217),
  City('Sonipat', 'Haryana', 28.9931, 77.0151),
  City('Shimla', 'Himachal Pradesh', 31.1048, 77.1734),
  City('Manali', 'Himachal Pradesh', 32.2432, 77.1892),
  City('Dharamshala', 'Himachal Pradesh', 32.219, 76.3234, ['McLeod Ganj']),
  City('Solan', 'Himachal Pradesh', 30.9045, 77.0967),
  City('Mandi', 'Himachal Pradesh', 31.7084, 76.9318),
  City('Srinagar', 'Jammu and Kashmir', 34.0837, 74.7973),
  City('Jammu', 'Jammu and Kashmir', 32.7266, 74.857),
  City('Leh', 'Ladakh', 34.1526, 77.5771),
  // Goa & union territories
  City('Panaji', 'Goa', 15.4909, 73.8278, ['Panjim', 'Goa']),
  City('Margao', 'Goa', 15.2832, 73.9862, ['Madgaon']),
  City('Vasco da Gama', 'Goa', 15.3982, 73.8113),
  City('Mapusa', 'Goa', 15.5937, 73.8142),
  City('Puducherry', 'Puducherry', 11.9416, 79.8083, ['Pondicherry', 'Pondy']),
  City('Port Blair', 'Andaman and Nicobar Islands', 11.6234, 92.7265, ['Sri Vijaya Puram']),
  City('Daman', 'Dadra and Nagar Haveli and Daman and Diu', 20.3974, 72.8328),
  City('Silvassa', 'Dadra and Nagar Haveli and Daman and Diu', 20.2766, 73.0169),
  City('Kavaratti', 'Lakshadweep', 10.5669, 72.642),
];
