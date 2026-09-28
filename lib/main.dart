import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSA Palwal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() { isLoading = false; });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://your-website.com')); // Yahan apni website daal

    // Tera wala logic yahan call hoga
    checkForUpdate();
  }

  // Tera wala code - Flutter version
  Future<void> checkForUpdate() async {
    try {
      // App start hone par current version check hoga
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentVersion = int.parse(packageInfo.buildNumber); // Example: 2

      // Server se fetch kiya hua current server version
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/dhruvichaudhary76-source/dsa-palwal-app/main/version.json'));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        int serverVersion = data['latestVersion']; // Server se milega, e.g., 3

        if (serverVersion > currentVersion) {
          // Tabhi Update ka dialog show hoga
          showUpdateDialog(data['message'], data['apkUrl']);
        }
      }
    } catch (e) {
      debugPrint("Update check error: $e");
    }
  }

  void showUpdateDialog(String message, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Naya Update! 🚀"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Baad me"),
          ),
          ElevatedButton(
            onPressed: () async {
              final Uri url = Uri.parse(apkUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text("Update Karo"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DSA Palwal App")),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
