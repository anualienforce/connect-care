import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const ConnectCareApp());
}

class ConnectCareApp extends StatelessWidget {
  const ConnectCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connect & Care',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  bool showSplash = true;
  bool hasError = false;
  String errorMessage = '';
  double loadingProgress = 0;

  final String websiteUrl = 'https://connect-care-44bd0220.base44.app';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _checkConnectivity();
  }

  Future<void> _requestPermissions() async {
    // Request necessary permissions only when needed
    await [Permission.storage, Permission.photos].request();
  }

  void _initializeWebView() {
    late final PlatformWebViewControllerCreationParams params;

    if (Platform.isAndroid) {
      params = AndroidWebViewControllerCreationParams();
    } else if (Platform.isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              loadingProgress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
              showSplash = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              hasError = true;
              isLoading = false;
              errorMessage = error.description;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/91.0.4472.120 Mobile Safari/537.36',
      )
      ..enableZoom(true);

    // --- ANDROID SPECIFIC ---
    if (Platform.isAndroid) {
      final androidController = controller.platform as AndroidWebViewController;

      androidController
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (request) async {
            final permissionStatus = await Permission.location.request();
            return GeolocationPermissionsResponse(
              allow: permissionStatus.isGranted,
              retain: true,
            );
          },
        )
        ..setOnShowFileSelector(_androidFilePicker)
        ..setOnConsoleMessage((JavaScriptConsoleMessage consoleMessage) {
          debugPrint(
            '🌐 JS console [${consoleMessage.level}]: ${consoleMessage.message}',
          );
        });
    }

    // --- iOS SPECIFIC ---
    if (Platform.isIOS) {
      (controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    controller.loadRequest(Uri.parse(websiteUrl));
  }

  // Add this inside _WebViewScreenState

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    debugPrint('🔥 onShowFileSelector called');
    debugPrint('  mode: ${params.mode}');
    debugPrint('  acceptTypes: ${params.acceptTypes}');
    debugPrint('  filenameHint: ${params.filenameHint}');

    // Request storage permission when file picker is opened
    final storagePermission = await Permission.storage.request();
    final photosPermission = await Permission.photos.request();

    if (!storagePermission.isGranted && !photosPermission.isGranted) {
      debugPrint('⚠️ Storage/Photos permission denied');
      return <String>[];
    }

    // Optional: restrict to images if site asks for image/*
    FileType fileType = FileType.any;
    if (params.acceptTypes.any((t) => t.startsWith('image/'))) {
      fileType = FileType.image;
    }

    final allowMultiple = params.mode == FileSelectorMode.openMultiple;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
      type: fileType,
    );

    if (result == null || result.files.isEmpty) {
      debugPrint('⚠️ User cancelled file picker or no files selected');
      return <String>[];
    }

    // 🔑 IMPORTANT: return *URI strings* (file://...), not plain paths
    final uris = <String>[];
    for (final picked in result.files) {
      if (picked.path != null) {
        final file = File(picked.path!);
        final uriString = file.uri.toString(); // e.g. file:///data/user/0/...
        uris.add(uriString);
        debugPrint('✅ Returning URI to WebView: $uriString');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected ${uris.length} file(s)')),
      );
    }

    return uris;
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reloadPage() async {
    setState(() {
      hasError = false;
      isLoading = true;
    });
    await controller.reload();
  }

  Future<bool> _onWillPop() async {
    if (await controller.canGoBack()) {
      controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: hasError
                    ? _buildErrorWidget()
                    : Column(
                        children: [
                          if (isLoading)
                            LinearProgressIndicator(
                              value: loadingProgress,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          Expanded(
                            child: WebViewWidget(controller: controller),
                          ),
                        ],
                      ),
              ),
              if (showSplash) Positioned.fill(child: _buildSplashOverlay()),
            ],
          ),
        ),
        floatingActionButton: hasError
            ? FloatingActionButton(
                onPressed: _reloadPage,
                child: const Icon(Icons.refresh),
              )
            : null,
      ),
    );
  }

  Widget _buildSplashOverlay() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 3),
              ),
              child: ClipOval(
                child: Image.asset('assets/icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'No internet connection',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reloadPage,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
