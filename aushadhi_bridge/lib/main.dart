import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const AushadhiApp());
}

class AushadhiApp extends StatelessWidget {
  const AushadhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aushadhi Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
           primary: Color(0xFF10B981),
           secondary: Color(0xFF0EA5E9),
           surface: Color(0xFF1E293B),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Get the Gemini API Key from environment variables (use --dart-define)
  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  final TextEditingController _symptomsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  File? _image;
  String _language = 'Hindi';
  bool _isLoading = false;
  Map<String, dynamic>? _results;
  Position? _location;

  final List<String> _languages = ['Hindi', 'Marathi', 'Tamil', 'Telugu', 'English'];

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _results = null;
      });
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    _location = await Geolocator.getCurrentPosition();
  }

  Future<void> _analyze() async {
    final apiKey = _geminiApiKey;
    if (apiKey.isEmpty) {
      _showError("Please configure your Gemini API Key using --dart-define.");
      return;
    }
    if (_image == null && _symptomsController.text.isEmpty) {
      _showError("Please upload an image or type symptoms.");
      return;
    }

    setState(() {
      _isLoading = true;
      _results = null;
    });

    await _getLocation();

    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
      
      final String prompt = '''
You are "Aushadhi Bridge", an AI designed to read messy handwritten prescriptions and convert them to affordable generic equivalents, translating dosage instructions so patients understand them.
        
Optional User Symptoms/Query: "${_symptomsController.text}"
Output Language Required: $_language

Respond ONLY with a valid JSON object matching this schema, completely without markdown formatting:
{
  "vernacular_instructions": "Detailed plain language advice and dosage instructions written IN EXACTLY THE SELECTED LANGUAGE ($_language). If the image is illegible, state that in $_language.",
  "medicines": [
    {
       "branded_name": "Name scrawled on prescription",
       "generic_equivalent": "The affordable pharmacological generic name (e.g. Paracetamol)",
       "purpose": "What this treats",
       "savings_percentage": "Estimated savings using generic (e.g. 60%)"
    }
  ]
}''';

      List<Map<String, dynamic>> parts = [
        {"text": prompt}
      ];

      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        final base64Image = base64Encode(bytes);
        parts.add({
          "inlineData": {
            "mimeType": "image/jpeg",
            "data": base64Image
          }
        });
      }

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [{"parts": parts}],
          "generationConfig": {"temperature": 0.2}
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Gemini API Error: ${response.statusCode} - ${response.body}");
      }

      final jsonResponse = jsonDecode(response.body);
      final rawText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
      final cleanText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      setState(() {
        _results = jsonDecode(cleanText);
      });

    } catch (e) {
      _showError("Failed to interpret prescription: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openGoogleMaps() async {
    String mapsUrl;
    if (_location != null) {
       mapsUrl = 'https://maps.google.com/maps?q=Jan+Aushadhi+Kendra@${_location!.latitude},${_location!.longitude}&z=14';
    } else {
       mapsUrl = 'https://maps.google.com/maps?q=Jan+Aushadhi+Kendra,India';
    }
    
    final Uri url = Uri.parse(mapsUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showError("Could not launch Google Maps.");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aushadhi Bridge'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Only show the APK download banner to Android users who are using the Web App.
            // iOS users will just see the regular Web App UI smoothly!
            if (kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Row(
                  children: [
                    const Icon(Icons.android, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text("Install the native Android APK for faster photo parsing and offline mapping capabilities!", style: TextStyle(fontSize: 13)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                      onPressed: () {
                        // Replace this URL when you upload your APK to Firebase Storage or Github Releases
                        launchUrl(Uri.parse("https://github.com/naagaaraajaan/h2s-warmup/releases/latest/download/AushadhiBridge.apk"), mode: LaunchMode.externalApplication);
                      },
                      child: const Text("Download"),
                    )
                  ],
                ),
              ),

            _buildCard(
              title: "1. Prescription Details",
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_image!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text("Tap to upload prescription photo", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _symptomsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Optional Voice/Text Symptoms",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _language,
                    decoration: InputDecoration(
                      labelText: "Translate to Vernacular",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _languages.map((lang) {
                      return DropdownMenuItem(value: lang, child: Text(lang));
                    }).toList(),
                    onChanged: (val) => setState(() => _language = val!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyze,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Icon(Icons.auto_awesome),
              label: Text(_isLoading ? "Analyzing..." : "Digitize & Find Generics"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),
            if (_results != null) _buildResultsView(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final instructions = _results!['vernacular_instructions'] ?? '';
    final medicines = _results!['medicines'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          title: "✅ Translated Instructions (\$_language)", // Safe encoding
          child: Text(instructions, style: const TextStyle(fontSize: 16, height: 1.5)),
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: "Generic Equivalents",
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: medicines.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final med = medicines[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("${med['generic_equivalent']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                subtitle: Text("Prescribed: ${med['branded_name']}\nPurpose: ${med['purpose']}"),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _openGoogleMaps,
          icon: const Icon(Icons.map),
          label: const Text("Launch Map to Nearest Jan Aushadhi Kendra"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
