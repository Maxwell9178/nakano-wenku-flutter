import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'platform_store.dart';

/// 跨平台图片：既能显示原生文件路径，也能显示 `nwstore://` 存储 token。
///
/// 网页版没有文件系统，`Image.file` 无法使用，所以统一走「读字节 → Image.memory」。
class PlatformImage extends StatefulWidget {
  const PlatformImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
    this.frameBuilder,
  });

  final String? path;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageFrameBuilder? frameBuilder;

  @override
  State<PlatformImage> createState() => _PlatformImageState();
}

class _PlatformImageState extends State<PlatformImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlatformImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _load();
    }
  }

  Future<void> _load() async {
    final String? path = widget.path;
    if (path == null || path.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bytes = null;
        _loading = false;
      });
      return;
    }
    final Uint8List? bytes = await PlatformStore.readBytes(path);
    if (!mounted) {
      return;
    }
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        alignment: widget.alignment,
        filterQuality: widget.filterQuality,
        gaplessPlayback: true,
        errorBuilder: widget.errorBuilder,
        frameBuilder: widget.frameBuilder,
      );
    }
    if (_loading) {
      return const SizedBox.shrink();
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final ImageErrorWidgetBuilder? builder = widget.errorBuilder;
    if (builder != null) {
      return builder(
        context,
        StateError('image not found'),
        StackTrace.current,
      );
    }
    return const SizedBox.shrink();
  }
}
