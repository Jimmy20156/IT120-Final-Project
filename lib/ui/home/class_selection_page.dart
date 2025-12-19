import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../app_theme.dart';
import '../../core/services/jersey_classifier_service.dart';
import '../camera/camera_detection_page.dart';

class ClassSelectionPage extends StatefulWidget {
  const ClassSelectionPage({super.key});

  @override
  State<ClassSelectionPage> createState() => _ClassSelectionPageState();
}

class _ClassSelectionPageState extends State<ClassSelectionPage> {
  final _classifier = JerseyClassifierService.instance;
  List<String> _labels = [];
  String _query = '';
  List<String> _assetImagePaths = [];
  final Map<String, String> _labelImageMap = {};
  final Map<String, String> _basenameMap = {};
  final Map<String, String> _normalizedBasenameMap = {};
  String _imagePathForLabel(String label) {
    final sanitized = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'assets/images/$sanitized.png';
  }
  Future<void> _loadAssetImages() async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = jsonDecode(manifestJson);
      final paths = manifest.keys.where((k) => k.startsWith('assets/images/')).toList();
      setState(() {
        _assetImagePaths = paths;
        for (final p in paths) {
          _basenameMap[_basenameNoExt(p)] = p;
          _normalizedBasenameMap[_normalizeId(_basenameNoExt(p))] = p;
        }
        _labelImageMap.clear();
      });
    } catch (_) {}
  }
  String _basenameNoExt(String path) {
    final file = path.split('/').last.toLowerCase();
    final dot = file.lastIndexOf('.');
    return dot > 0 ? file.substring(0, dot) : file;
  }
  String _normalizeId(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
  String _resolveAssetImage(String label) {
    if (_labelImageMap.containsKey(label)) return _labelImageMap[label]!;
    final candidates = _sanitizeCandidates(label);
    for (final c in candidates) {
      final hit = _basenameMap[c] ?? _normalizedBasenameMap[_normalizeId(c)];
      if (hit != null) {
        _labelImageMap[label] = hit;
        return hit;
      }
    }
    for (final c in candidates) {
      final normC = _normalizeId(c);
      final hit = _assetImagePaths.firstWhere(
        (p) {
          final bn = _basenameNoExt(p);
          return bn.contains(c) || _normalizeId(bn).contains(normC);
        },
        orElse: () => '',
      );
      if (hit.isNotEmpty) {
        _labelImageMap[label] = hit;
        return hit;
      }
    }
    // Do NOT cache fallback; allow future asset loads to resolve correctly
    return _imagePathForLabel(label);
  }
  List<String> _sanitizeCandidates(String label) {
    final lower = label.toLowerCase().trim();
    final compact = lower.replaceAll(RegExp(r'\s+'), ' ');
    final noNums = compact.replaceAll(RegExp(r'^\d+\s*'), '');
    final noFarm = noNums.replaceFirst(RegExp(r'^farm\s+'), '');
    final tokens = noFarm.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();
    final underscoredNoFarm = tokens.join('_');
    final hyphenedNoFarm = tokens.join('-');
    final collapsedNoFarm = tokens.join('');
    final lastToken = tokens.isNotEmpty ? tokens.last : '';
    final underscored = noNums.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    final hyphened = noNums.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final collapsed = noNums.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final set = <String>{
      underscoredNoFarm,
      hyphenedNoFarm,
      collapsedNoFarm,
      lastToken,
      underscored,
      hyphened,
      collapsed,
    };
    set.removeWhere((e) => e.isEmpty);
    return set.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadLabels();
    _loadAssetImages();
  }

  Future<void> _loadLabels() async {
    await _classifier.ensureModelLoaded();
    final raw = _classifier.labels;
    final cleaned = raw.map(_classifier.cleanLabel).toList();
    if (mounted) {
      setState(() => _labels = cleaned);
    }
  }

  List<String> get _filteredLabels {
    if (_query.isEmpty) return _labels;
    final q = _query.toLowerCase();
    return _labels.where((l) => l.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final classes = _filteredLabels.isNotEmpty ? _filteredLabels : _labels;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Farm Equipment',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose an equipment to start detection',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search classes...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 4 / 3,
            ),
            itemCount: classes.length,
            itemBuilder: (BuildContext context, int displayIdx) {
              final String name = classes[displayIdx];
              final int index = _labels.indexOf(name);
              final Color color =
                  AppColors.classColors[index % AppColors.classColors.length];
              final String imagePath = _resolveAssetImage(name);

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CameraDetectionPage(
                        selectedClassIndex: index,
                        selectedClassName: name,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            color.withOpacity(0.9),
                                            color.withOpacity(0.6),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'Equipment',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.5),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tap to detect',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: AppColors.textSecondary.withOpacity(0.7)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
