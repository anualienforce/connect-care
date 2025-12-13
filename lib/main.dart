import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

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
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: false,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Connect & Care',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          debugShowCheckedModeBanner: false,
          builder: (context, widget) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaleFactor: 1.0, // 🔒 ignore system font size
              ),
              child: widget!,
            );
          },
          home: const WebViewScreen(),
        );
      },
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
    _checkAndRequestPermissions();
    _initializeWebView();
  }

  Future<void> _checkAndRequestPermissions() async {
    debugPrint('🔐 Starting permission check...');
    // Check and request all necessary permissions every time
    final permissions = [
      Permission.storage,
      Permission.photos,
      Permission.location,
    ];

    for (var permission in permissions) {
      final status = await permission.status;
      debugPrint('🔐 ${permission.toString()}: $status');
      if (!status.isGranted) {
        debugPrint('🔐 Requesting ${permission.toString()}...');
        final result = await permission.request();
        debugPrint('🔐 ${permission.toString()} after request: $result');
      }
    }
    debugPrint('🔐 Permission check complete');
  }

  Future<void> _getAndInjectLocation() async {
    try {
      debugPrint('📍 Getting current location using geolocator...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      debugPrint(
        '📍 Got position: ${position.latitude}, ${position.longitude}',
      );

      // Inject the location into the JavaScript context
      final locationJson =
          '''{
        "coords": {
          "latitude": ${position.latitude},
          "longitude": ${position.longitude},
          "accuracy": ${position.accuracy},
          "altitude": ${position.altitude},
          "altitudeAccuracy": 0,
          "heading": ${position.heading},
          "speed": ${position.speed}
        },
        "timestamp": ${DateTime.now().millisecondsSinceEpoch}
      }''';

      await controller.runJavaScript('''
        (function() {
          window._flutterLocationData = $locationJson;
          console.log("WebView: Injected location data:", window._flutterLocationData);
        })();
      ''');

      debugPrint('📍 Location data injected into WebView');
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
    }
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
      ..addJavaScriptChannel(
        'flutter',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('📱 JavaScript Channel Message: ${message.message}');
        },
      )
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

            // Check location permission and get/inject location if granted
            debugPrint('📍 Page started, checking location permission...');
            Permission.location.status.then((status) {
              debugPrint('📍 Location permission status on page load: $status');
              // If permission already granted, get the actual location and inject it
              if (status.isGranted) {
                debugPrint(
                  '📍 Location permission granted, getting position...',
                );
                _getAndInjectLocation();
              }
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
              showSplash = false;
            });

            // Inject viewport meta tag to disable text scaling
            controller.runJavaScript(
              'var meta = document.querySelector("meta[name=viewport]"); '
              'if(!meta) { meta = document.createElement("meta"); meta.name = "viewport"; document.head.appendChild(meta); } '
              'meta.content = "width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, viewport-fit=cover"; '
              'window.scrollX=0; window.scrollY=0; '
              'document.body.style.display="block"; '
              'document.documentElement.style.display="block"; '
              'var css = "html, body { -webkit-text-size-adjust: 100% !important; font-size: 16px !important; } * { -webkit-text-size-adjust: 100% !important; }"; '
              'var style = document.createElement("style"); '
              'style.textContent = css; '
              'document.head.appendChild(style);',
            );

            controller.runJavaScript('''
    (function() {
      if (!navigator.geolocation) {
        console.log("WebView: geolocation NOT supported");
        window.geolocationSupported = false;
        return;
      }
      window.geolocationSupported = true;
      console.log("WebView: geolocation supported");

      const originalGetCurrentPosition =
        navigator.geolocation.getCurrentPosition.bind(navigator.geolocation);

      navigator.geolocation.getCurrentPosition = function(success, error, options) {
        console.log("WebView: getCurrentPosition CALLED with options:", JSON.stringify(options || {}));
        
        return originalGetCurrentPosition(
          function(position) {
            console.log("WebView: SUCCESS - Got position!", position.coords);
            success(position);
          },
          function(err) {
            console.error("WebView: ERROR -", err.code, err.message);
            // If permission denied, try using injected Flutter location data
            if (err.code === 1 && window._flutterLocationData) {
              console.log("WebView: Permission denied in WebView, using Flutter location data...");
              success(window._flutterLocationData);
            } else {
              error(err);
            }
          },
          options
        );
      };
    })();
    
    // Also log if geolocation.watchPosition is called
    (function() {
      if (!navigator.geolocation || !navigator.geolocation.watchPosition) {
        return;
      }
      const originalWatchPosition =
        navigator.geolocation.watchPosition.bind(navigator.geolocation);

      navigator.geolocation.watchPosition = function(success, error, options) {
        console.log("WebView: watchPosition CALLED");
        if (window._flutterLocationData) {
          console.log("WebView: Using Flutter location data for watchPosition...");
          // Return a watch ID (positive integer)
          success(window._flutterLocationData);
          return 1;
        }
        return originalWatchPosition(success, error, options);
      };
    })();
  ''');
            ;
            ;

            // Allow document to load fully before showing
            Future.delayed(const Duration(milliseconds: 500), () {
              controller.runJavaScript(
                'document.documentElement.style.opacity="1";',
              );
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              '❌ WebResourceError: ${error.description}, url: ${error.url}',
            );

            // Only show error if it's a main frame error (actual page load)
            // Ignore sub-resource errors like Google signaler, analytics, etc.
            final isMainFrameError =
                error.url == websiteUrl ||
                (error.url?.contains('connect-care') ?? false);

            if (isMainFrameError) {
              setState(() {
                hasError = true;
                isLoading = false;
                errorMessage = error.description;
              });
            } else {
              debugPrint(
                '⚠️ Ignoring non-critical sub-resource error: ${error.url}',
              );
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint(
              '🔗 Navigation request: ${request.url}, isMainFrame: ${request.isMainFrame}',
            );
            // Allow all navigations (including Google auth) to load in WebView
            // WebView will handle auth with proper headers
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/91.0.4472.120 Mobile Safari/537.36',
      )
      ..enableZoom(false);

    // --- ANDROID SPECIFIC ---
    if (Platform.isAndroid) {
      final androidController = controller.platform as AndroidWebViewController;

      androidController
        ..setTextZoom(100)
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (request) async {
            debugPrint('🌍🌍🌍 GEOLOCATION PROMPT TRIGGERED 🌍🌍🌍');
            debugPrint('🌍 Geolocation permission requested by WebView');
            debugPrint('📍 Request origin: ${request.origin}');
            debugPrint('📍 Request resources: ${request.toString()}');

            // Request location permission with explicit prompts
            final locationStatus = await Permission.location.request();
            debugPrint(
              '📍 Location permission status after request: $locationStatus',
            );
            debugPrint('📍 Is location granted: ${locationStatus.isGranted}');
            debugPrint('📍 Is location denied: ${locationStatus.isDenied}');
            debugPrint(
              '📍 Is location restricted: ${locationStatus.isRestricted}',
            );
            debugPrint(
              '📍 Is location provisional: ${locationStatus.isProvisional}',
            );

            // Show error if permission is denied
            if (locationStatus.isDenied || locationStatus.isRestricted) {
              debugPrint('⚠️ Location permission denied or restricted');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Location permission is required. Please enable it in settings.',
                    ),
                    action: SnackBarAction(
                      label: 'Settings',
                      onPressed: () => openAppSettings(),
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }

            final response = GeolocationPermissionsResponse(
              allow: locationStatus.isGranted,
              retain: true,
            );
            debugPrint(
              '📍 Geolocation response: allow=${response.allow}, retain=${response.retain}',
            );

            return response;
          },
          onHidePrompt: () {
            debugPrint('📍 Geolocation prompt hidden');
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
      final webKitController = controller.platform as WebKitWebViewController;
      webKitController.setAllowsBackForwardNavigationGestures(true);

      // Use Safari-compatible User-Agent
      webKitController.setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
      );
    }

    controller.loadRequest(Uri.parse(websiteUrl));
  }

  // Add this inside _WebViewScreenState

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    debugPrint('🔥 onShowFileSelector called');
    debugPrint('  mode: ${params.mode}');
    debugPrint('  acceptTypes: ${params.acceptTypes}');
    debugPrint('  filenameHint: ${params.filenameHint}');

    // Always check and request storage permission when file picker is opened
    var storagePermission = await Permission.storage.status;
    var photosPermission = await Permission.photos.status;

    // If permissions are denied, request them again
    if (!storagePermission.isGranted) {
      storagePermission = await Permission.storage.request();
    }
    if (!photosPermission.isGranted) {
      photosPermission = await Permission.photos.request();
    }

    // If still not granted after request, show message and open settings
    if (!storagePermission.isGranted && !photosPermission.isGranted) {
      debugPrint('⚠️ Storage/Photos permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Storage permission is required to upload files. Please enable it in settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
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
                child: Image.asset('assets/icon.jpeg', fit: BoxFit.cover),
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
            Text(
              'Please check your internet connection and try again. $errorMessage',
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
