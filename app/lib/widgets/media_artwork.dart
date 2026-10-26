import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/launcher_theme.dart';
import 'uni_icon.dart';

class MediaArtwork extends StatefulWidget {
  final Map<String, dynamic> media;
  final bool demo;
  final double fallbackSize;
  const MediaArtwork(
      {super.key,
      required this.media,
      required this.demo,
      this.fallbackSize = 48});
  @override
  State<MediaArtwork> createState() => _MediaArtworkState();
}

class _MediaArtworkState extends State<MediaArtwork> {
  String encoded = '';
  Uint8List? bytes;

  void evictArtwork() {
    final previous = bytes;
    if (previous != null) {
      PaintingBinding.instance.imageCache
          .evict(MemoryImage(previous), includeLive: false);
    }
  }

  @override
  void dispose() {
    evictArtwork();
    bytes = null;
    encoded = '';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = !widget.demo && widget.media['artwork'] is String
        ? widget.media['artwork'] as String
        : '';
    if (value != encoded) {
      evictArtwork();
      encoded = value;
      try {
        bytes = value.length < 1000000 ? base64Decode(value) : null;
      } catch (_) {
        bytes = null;
      }
    }
    if (widget.demo)
      return SvgPicture.asset('assets/art/cover.svg', fit: BoxFit.cover);
    Widget fallback() => Center(
        child: UniIcon('music',
            color: SurfaceStyle.of(context).accent, size: widget.fallbackSize));
    if (bytes == null || bytes!.isEmpty) return fallback();
    return Image.memory(bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, error, stack) => fallback());
  }
}
