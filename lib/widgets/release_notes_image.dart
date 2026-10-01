import 'package:flutter/material.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'release_image_loader.dart';

class ReleaseNotesImage extends StatefulWidget {
  const ReleaseNotesImage({
    super.key,
    required this.uri,
    required this.loader,
    this.alt,
    this.expanded = false,
    this.initialImage,
  });
  final Uri uri;
  final ReleaseImageLoader loader;
  final String? alt;
  final bool expanded;
  final ReleaseImageData? initialImage;
  @override
  State<ReleaseNotesImage> createState() => _ReleaseNotesImageState();
}

class _ReleaseNotesImageState extends State<ReleaseNotesImage> {
  late Future<ReleaseImageData> _image = widget.loader.load(widget.uri);

  Widget _retry(BuildContext context) => SizedBox(
    height: 100,
    child: Center(
      child: TextButton.icon(
        onPressed: () {
          widget.loader.evict(widget.uri);
          setState(() => _image = widget.loader.load(widget.uri));
        },
        icon: const Icon(Icons.refresh_rounded),
        label: Text(AppLocalizations.of(context).updatesRetryAction),
      ),
    ),
  );

  @override
  void didUpdateWidget(ReleaseNotesImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri || oldWidget.loader != widget.loader) {
      _image = widget.loader.load(widget.uri);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ReleaseImageData>(
    future: _image,
    initialData: widget.initialImage,
    builder: (context, snapshot) {
      final image = snapshot.data;
      if (snapshot.connectionState != ConnectionState.done && image == null) {
        return const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      if (image == null) {
        return _retry(context);
      }
      return Semantics(
        label: widget.alt,
        button: !widget.expanded,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: InkWell(
              key: widget.expanded
                  ? null
                  : const ValueKey('release-image-preview'),
              onTap: widget.expanded
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _ReleaseImageViewer(
                          image: image,
                          uri: widget.uri,
                          loader: widget.loader,
                          alt: widget.alt,
                        ),
                      ),
                    ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.expanded ? double.infinity : 360,
                ),
                child: Image(
                  image: image.provider(
                    maxDimension: widget.expanded ? 1920 : 960,
                  ),
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, _, _) => _retry(context),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ReleaseImageViewer extends StatelessWidget {
  const _ReleaseImageViewer({
    required this.image,
    required this.uri,
    required this.loader,
    this.alt,
  });
  final ReleaseImageData image;
  final String? alt;
  final Uri uri;
  final ReleaseImageLoader loader;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: AppLocalizations.of(context).close,
        icon: const Icon(Icons.close_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(alt ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: SafeArea(
      child: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: ReleaseNotesImage(
            uri: uri,
            loader: loader,
            alt: alt,
            expanded: true,
            initialImage: image,
          ),
        ),
      ),
    ),
  );
}
