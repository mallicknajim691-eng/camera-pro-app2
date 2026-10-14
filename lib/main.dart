import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lucide_icons/lucide_icons.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera Error: $e');
  }
  runApp(const ProCamApp());
}

class ProCamApp extends StatelessWidget {
  const ProCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProCam Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: CameraScreen(cameras: cameras),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  FlashMode _flashMode = FlashMode.off;
  int _selectedFilterIndex = 0;

  final List<Map<String, dynamic>> _filters = [
    {
      'name': 'NATURAL',
      'matrix': [1.0, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 1.0, 0]
    },
    {
      'name': 'CINEMATIC',
      'matrix': [0.9, 0.1, 0, 0, 10, 0, 0.85, 0.1, 0, 15, 0.1, 0.1, 0.9, 0, 20, 0, 0, 0, 1.0, 0]
    },
    {
      'name': 'WARM',
      'matrix': [1.2, 0.1, 0, 0, 10, 0.1, 1.0, 0, 0, 5, 0, 0, 0.8, 0, -10, 0, 0, 0, 1.0, 0]
    },
    {
      'name': 'MONO',
      'matrix': [0.33, 0.33, 0.33, 0, -20, 0.33, 0.33, 0.33, 0, -10, 0.33, 0.33, 0.33, 0, 10, 0, 0, 0, 1.0, 0]
    },
  ];

  String? _imagePath;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) _initCamera(0);
  }

  Future<void> _initCamera(int idx) async {
    _controller = CameraController(widget.cameras[idx], ResolutionPreset.max, enableAudio: false);
    try {
      await _controller.initialize();
      _maxZoom = await _controller.getMaxZoomLevel();
      _minZoom = await _controller.getMinZoomLevel();
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint("Init Error: $e");
    }
  }

  Future<void> _capture() async {
    if (!_controller.value.isInitialized || _controller.value.isTakingPicture) return;
    try {
      final file = await _controller.takePicture();
      setState(() => _imagePath = file.path);
    } catch (e) {
      debugPrint("Capture Error: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    }

    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onScaleUpdate: (d) async {
              double zoom = (_currentZoom * d.scale).clamp(_minZoom, _maxZoom);
              await _controller.setZoomLevel(zoom);
              setState(() => _currentZoom = zoom);
            },
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(_filters[_selectedFilterIndex]['matrix']),
              child: Center(child: CameraPreview(_controller)),
            ),
          ),
          Positioned(
            top: 40, left: 20, right: 20,
            child: GlassmorphicContainer(
              width: MediaQuery.of(context).size.width - 40, height: 60, borderRadius: 30, blur: 15,
              alignment: Alignment.center, border: 1,
              linearGradient: const LinearGradient(colors: [Colors.white12, Colors.white10]),
              borderGradient: const LinearGradient(colors: [Colors.white30, Colors.white10]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      _flashMode == FlashMode.always ? LucideIcons.zap : LucideIcons.slash,
                      color: _flashMode == FlashMode.always ? Colors.amber : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _flashMode = _flashMode == FlashMode.off ? FlashMode.always : FlashMode.off;
                        _controller.setFlashMode(_flashMode);
                      });
                    },
                  ),
                  Text('${_currentZoom.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
                    onPressed: () {
                      _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
                      _initCamera(_selectedCameraIndex);
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    itemBuilder: (context, i) {
                      bool sel = _selectedFilterIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilterIndex = i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? Colors.amber : Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? Colors.amber : Colors.white30),
                          ),
                          child: Text(_filters[i]['name'], style: TextStyle(color: sel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white54, width: 2)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _imagePath != null ? Image.file(File(_imagePath!), fit: BoxFit.cover) : const Icon(LucideIcons.image, color: Colors.white54),
                      ),
                    ),
                    GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 80, height: 80, padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber, width: 4)),
                        child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ),
                    ),
                    const SizedBox(width: 50),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
