import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

class EtonifyLogoBadge extends StatelessWidget {
  const EtonifyLogoBadge({
    super.key,
    this.size = 112,
    this.logoSize,
    this.innerScale = .58,
  });

  final double size;
  final double? logoSize;
  final double innerScale;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedLogoSize = logoSize ?? size * .5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: .18),
            blurRadius: size * .26,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * innerScale,
          height: size * innerScale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withValues(alpha: .10),
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/images/logo.svg',
              width: resolvedLogoSize,
              height: resolvedLogoSize,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
