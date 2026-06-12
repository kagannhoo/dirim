import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../services/api_config_service.dart';
import '../widgets/emergency_contacts_sheet.dart';
import 'dart:math' as math;

// --- Analiz Sonuç Ekranı ---
class FaceAnalysisResultScreen extends StatefulWidget {
  final Map<String, dynamic> aiData;
  final String? bpm;
  final String? spo2;

  const FaceAnalysisResultScreen({
    super.key,
    required this.aiData,
    this.bpm,
    this.spo2,
  });

  @override
  State<FaceAnalysisResultScreen> createState() =>
      _FaceAnalysisResultScreenState();
}

class _FaceAnalysisResultScreenState extends State<FaceAnalysisResultScreen> {
  @override
  void initState() {
    super.initState();
    _saveToSupabase();
  }

  Future<void> _saveToSupabase() async {
    try {
      final supabase = Supabase.instance.client;
      final clinical = widget.aiData['clinical_analysis'];
      final psych = clinical['psychological'];
      final neuro = clinical['neurological'];
      final ophthalmic = clinical['ophthalmic'];
      final systemic = clinical['systemic_dermatological'];

      String currentBpm = widget.bpm ?? "0";
      String currentSpo2 = widget.spo2 ?? "0";

      // ÇÖZÜM: Python'dan gelen "%45.0" metnini temizleyip saf sayıya (double) çeviriyoruz
      String stressRaw = psych['stress_level'].toString().replaceAll('%', '');
      double stressValue = double.tryParse(stressRaw) ?? 0.0;

      await supabase.from('health_history').insert({
        'user_id': supabase.auth.currentUser?.id,
        'emotion': psych['dominant_emotion'],
        'stress_score':
            stressValue, // <-- DÜZELTİLDİ: Artık metin değil, saf float4 gidiyor
        'fatigue': psych['fatigue_status'],
        'ai_recommendation': psych['ai_recommendation'],
        'bpm': currentBpm,
        'spo2': currentSpo2,
        'facial_palsy': neuro['facial_palsy_stroke_risk'],
        'ptosis': ophthalmic['ptosis_eyelid_drop'],
        'strabismus': ophthalmic['strabismus_eye_alignment'],
        'jaundice': ophthalmic['sclera_jaundice'],
        'conjunctivitis':
            ophthalmic['conjunctivitis_redness'], // Resimde bu sütun da var, eşleşiyor
        'cyanosis': systemic['cyanosis_oxygen_deprivation'],
        'anemia': systemic['anemia_pallor_index'],
        // created_at'i göndermene gerek yok, Supabase resimde gördüğüm kadarıyla bunu otomatik atıyor.
      });
      debugPrint("✅ Supabase'e başarıyla kaydedildi.");
    } catch (e) {
      debugPrint("❌ Supabase kayıt hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinical = widget.aiData['clinical_analysis'];
    final neuro = clinical['neurological'];
    final ophthalmic = clinical['ophthalmic'];
    final systemic = clinical['systemic_dermatological'];
    final psych = clinical['psychological'];

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        leading: BackButton(color: AppColors.textDarkGrey),
        title: Text(
          "Biyometrik Rapor",
          style: TextStyle(
            color: AppColors.textDarkGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: AppColors.primaryBlue,
                    size: 60,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Analiz Raporu Hazır",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDarkGrey,
                    ),
                  ),
                  Text(
                    "OpenCV & DeepFace motorları tarafından onaylandı.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            _buildSectionTitle("Mental & Psikolojik Durum"),
            _buildResultCard(
              "Dominant Duygu",
              psych['dominant_emotion'].toString(),
              Icons.psychology,
              Colors.purple,
            ),
            _buildResultCard(
              "Stres Seviyesi",
              psych['stress_level'].toString(),
              Icons.warning_amber_rounded,
              Colors.orange,
            ),
            _buildResultCard(
              "Yorgunluk Durumu",
              psych['fatigue_status'].toString(),
              Icons.battery_charging_full,
              Colors.blue,
            ),
            SizedBox(height: 12),
            Card(
              margin: EdgeInsets.only(bottom: 12),
              color: Colors.blue.withValues(alpha: 0.05),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Yapay Zeka Önerisi",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      psych['ai_recommendation']?.toString() ??
                          "Öneri bekleniyor...",
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textDarkGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            _buildSectionTitle("Oftalmolojik & Nörolojik Tarama"),
            _buildResultCard(
              "Yüz Felci / İnme Kontrolü",
              neuro['facial_palsy_stroke_risk'].toString(),
              Icons.accessibility,
              Colors.red,
            ),
            _buildResultCard(
              "Göz Kapağı Düşüklüğü (Ptosis)",
              ophthalmic['ptosis_eyelid_drop'].toString(),
              Icons.remove_red_eye,
              Colors.orange,
            ),
            _buildResultCard(
              "Şaşılık / Göz Kayması",
              ophthalmic['strabismus_eye_alignment'].toString(),
              Icons.remove_red_eye_outlined,
              Colors.teal,
            ),
            _buildResultCard(
              "Göz Akı Sarılığı (İkter)",
              ophthalmic['sclera_jaundice'].toString(),
              Icons.visibility,
              Colors.amber,
            ),
            _buildResultCard(
              "Konjonktivit (Kanlanma)",
              ophthalmic['conjunctivitis_redness'].toString(),
              Icons.blur_on,
              Colors.redAccent,
            ),
            SizedBox(height: 24),
            _buildSectionTitle("Sistemik Sağlık Endeksleri"),
            _buildResultCard(
              "Dudak Siyanozu (Oksijen)",
              systemic['cyanosis_oxygen_deprivation'].toString(),
              Icons.waves,
              Colors.blue,
            ),
            _buildResultCard(
              "Anemi (Solukluk İndeksi)",
              systemic['anemia_pallor_index'].toString(),
              Icons.bloodtype,
              Colors.red,
            ),
            SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                onPressed: () => EmergencyContactsSheet.show(context),
                icon: const Icon(Icons.emergency_outlined),
                label: const Text(
                  "Tıbbi Yardım Al",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Acil durum kişilerinizi anında arayın",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textDarkGrey,
      ),
    ),
  );

  Widget _buildResultCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    bool isRisk =
        value.contains("Risk") ||
        value.contains("Bitkin") ||
        value.contains("Yoğun") ||
        value.contains("Yüksek");

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isRisk
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isRisk ? Colors.red : color).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isRisk ? Colors.red : color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isRisk ? Colors.red : AppColors.textDarkGrey,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Ana Tarama Ekranı ---
class FaceAnalysisScreen extends StatefulWidget {
  final String currentBpm;
  final String currentSpo2;

  const FaceAnalysisScreen({
    super.key,
    this.currentBpm = "0",
    this.currentSpo2 = "0",
  });

  @override
  _FaceAnalysisScreenState createState() => _FaceAnalysisScreenState();
}

class _FaceAnalysisScreenState extends State<FaceAnalysisScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _canProcess = true;
  bool _isBusy = false;
  bool _isScanFinishing = false;
  int _frameCount = 0;

  String _scanStatusText = "Kamera başlatılıyor...";
  bool _isFaceCentered = false;

  // Yükleniyor ekranı için
  bool _isProcessing = false;
  String _processingText = "Biyometrik veriler işleniyor...";

  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _initCamera();

    _progressController =
        AnimationController(vsync: this, duration: Duration(seconds: 4))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && !_isScanFinishing) {
              _isScanFinishing = true;
              _finishScan();
            }
          });

    _progressController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _scanStatusText = "Yüzünüzü çerçeveye yerleştirin";
        });
        _cameraController!.startImageStream(_processCameraImage);
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _frameCount++;
    if (_frameCount % 5 != 0) return;
    if (!_canProcess || _isBusy || _isScanFinishing) return;
    _isBusy = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    final faces = await _faceDetector.processImage(inputImage);

    if (mounted) {
      if (faces.isEmpty) {
        _handleFaceLost("Yüz bulunamadı, çerçeveye bakın");
      } else {
        final face = faces.first;
        final imageSize = inputImage.metadata!.size;
        final faceCenter = face.boundingBox.center;

        bool isCenteredX =
            (faceCenter.dx - (imageSize.width / 2)).abs() <
            (imageSize.width * 0.30);
        bool isCenteredY =
            (faceCenter.dy - (imageSize.height / 2)).abs() <
            (imageSize.height * 0.30);
        double rotY = face.headEulerAngleY ?? 100;
        double rotZ = face.headEulerAngleZ ?? 100;
        bool isLookingStraight = rotY.abs() < 20 && rotZ.abs() < 15;
        bool isGoodSize = face.boundingBox.width > (imageSize.width * 0.25);

        if (isCenteredX && isCenteredY && isLookingStraight && isGoodSize) {
          if (!_isFaceCentered) {
            setState(() {
              _isFaceCentered = true;
              _scanStatusText = "Harika! Sabit durun...";
            });
          }
          _progressController.forward();
        } else {
          String hint = "Yüzünüzü çerçeveye ortalayın";
          if (!isLookingStraight)
            hint = "Kameraya düz bakın";
          else if (!isGoodSize)
            hint = "Telefonu biraz yaklaştırın";
          _handleFaceLost(hint);
        }
      }
    }
    _isBusy = false;
  }

  void _handleFaceLost(String message) {
    if (_isScanFinishing) return;
    if (mounted) {
      setState(() {
        _isFaceCentered = false;
        _scanStatusText = message;
      });
      _progressController.reverse(from: _progressController.value);
    }
  }

  void _finishScan() async {
    _canProcess = false;

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _processingText = "Fotoğraf çekiliyor..."; // Metni anında güncelledik
      });
    }

    // 1. Görüntü akışını durdur
    try {
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } catch (e) {
      debugPrint("stopImageStream: $e");
    }

    // DİKKAT: future.delayed(1200) beklemesini tamamen kaldırdık!
    // Progress %100 olduğu o an, saniyesinde kameradan fotoğrafı alıyoruz.

    // 2. Anında Fotoğraf Çek
    XFile? file;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        file = await _cameraController!.takePicture();
        debugPrint("📸 Şipşak fotoğraf çekildi: ${file.path}");
        break;
      } catch (e) {
        debugPrint("❌ takePicture denemesi $attempt başarısız: $e");
        if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 300));
        } else {
          _resetScan("Fotoğraf çekilemedi, tekrar deneyin.");
          return;
        }
      }
    }

    // 3. Sunucuya Gönder (VDS DeepFace 1-2 dk sürebilir — tüm istek timeout'lu)
    try {
      if (mounted) {
        setState(() => _processingText = "Sunucuya gönderiliyor...");
      }

      final url = ApiConfigService.instance.analyzeFaceUri;
      var request = http.MultipartRequest('POST', url);
      request.headers['x-session-id'] =
          '${DateTime.now().millisecondsSinceEpoch}';
      request.files.add(await http.MultipartFile.fromPath('file', file!.path));

      if (mounted) {
        setState(
          () => _processingText = "AI analiz ediyor...\n(1-2 dk sürebilir)",
        );
      }

      final response = await (() async {
        final streamedResponse = await request.send();
        return http.Response.fromStream(streamedResponse);
      })().timeout(const Duration(seconds: 120));

      debugPrint("📡 Sunucu yanıtı: ${response.statusCode}");
      debugPrint("📡 Body: ${response.body.length} karakter");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          if (!mounted) return;
          await Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(
              builder: (_) => FaceAnalysisResultScreen(
                aiData: responseData,
                bpm: widget.currentBpm,
                spo2: widget.currentSpo2,
              ),
            ),
          );
          return;
        }
        _resetScan(
          "Analiz başarısız: ${responseData['message'] ?? 'Bilinmeyen hata'}",
        );
      } else {
        _resetScan("Sunucu hatası: ${response.statusCode}");
      }
    } on TimeoutException {
      _resetScan(
        "Analiz zaman aşımı (2 dk). Sunucu yoğun olabilir, tekrar deneyin.",
      );
    } catch (e) {
      debugPrint("❌ Finish scan hatası: $e");
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection')) {
        _resetScan("Sunucuya bağlanılamadı. Ayarlardan AI adresini kontrol edin.");
      } else {
        _resetScan(
          "Hata: ${e.toString().substring(0, math.min(80, e.toString().length))}",
        );
      }
    }
  }

  void _resetScan(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
    setState(() {
      _isProcessing = false;
      _scanStatusText = message;
      _isFaceCentered = false;
      _isScanFinishing = false;
    });
    _canProcess = true;
    _progressController.reset();
    _restartCameraStream();
  }

  Future<void> _restartCameraStream() async {
    try {
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) return;
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && controller.value.isInitialized) {
        await controller.startImageStream(_processCameraImage);
      }
    } catch (e) {
      debugPrint("startImageStream hatası: $e — kamera yeniden başlatılıyor");
      if (mounted) await _initCamera();
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameras?.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    if (camera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21))
      return null;
    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _canProcess = false;
    _isScanFinishing = true;
    _faceDetector.close();
    _cameraController?.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    // İşleniyor ekranı — kamera yerine yükleme göster
    if (_isProcessing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.greenAccent,
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                _processingText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Lütfen bekleyin...",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CameraPreview(_cameraController!)),

          // Oval maske
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.85),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 280,
                    height: 380,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(280, 380),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress oval
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 280,
              height: 380,
              child: CustomPaint(
                painter: OvalProgressPainter(
                  progress: _progressController.value,
                  color: _isFaceCentered ? Colors.greenAccent : Colors.white24,
                ),
              ),
            ),
          ),

          // Durum mesajı
          Positioned(
            top: 100,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _isFaceCentered
                    ? Colors.greenAccent.withValues(alpha: 0.15)
                    : Colors.black54,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _isFaceCentered
                      ? Colors.greenAccent
                      : Colors.transparent,
                ),
              ),
              child: Text(
                _scanStatusText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Yüzde ve progress bar
          Positioned(
            bottom: 80,
            left: 40,
            right: 40,
            child: Column(
              children: [
                Text(
                  "%${(_progressController.value * 100).toInt()}",
                  style: TextStyle(
                    color: _isFaceCentered ? Colors.greenAccent : Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: _progressController.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isFaceCentered
                                ? Colors.greenAccent
                                : AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(top: 50, left: 16, child: BackButton(color: Colors.white)),
        ],
      ),
    );
  }
}

class OvalProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  OvalProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final paintBackground = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(rect, paintBackground);

    if (progress > 0) {
      final paintProgress = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final startAngle = -math.pi / 2;
      final sweepAngle = progress * 2 * math.pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paintProgress);
    }
  }

  @override
  bool shouldRepaint(covariant OvalProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
