import 'package:flutter/material.dart';

import '../constants/app_branding.dart';

class DirimLogo extends StatelessWidget {
  final double size;
  final bool rounded;

  const DirimLogo({super.key, this.size = 80, this.rounded = true});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      AppBranding.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );

    if (!rounded) return image;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: image,
    );
  }
}
