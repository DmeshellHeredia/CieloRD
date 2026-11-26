import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../l10n/cielo_strings.dart';

/// Foto del observador o estado vacío accesible.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.photoMediaId,
    required this.resolve,
    this.size = 96,
  });

  final String? photoMediaId;
  final Future<Result<String>> Function(String mediaId)? resolve;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<Result<String>>? _path;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoMediaId != widget.photoMediaId) _load();
  }

  void _load() {
    final String? id = widget.photoMediaId;
    _path = id == null ? null : widget.resolve?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<String>>(
      key: ValueKey<String?>(widget.photoMediaId),
      future: _path,
      builder: (BuildContext context, AsyncSnapshot<Result<String>> snapshot) {
        final Result<String>? result = snapshot.data;
        if (result is! Success<String>) return _frame(context, null);
        return _frame(
          context,
          Image.file(
            File(result.value),
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            cacheWidth: (widget.size * 3).round(),
            gaplessPlayback: true,
            errorBuilder: (BuildContext context, Object error, StackTrace? s) =>
                _placeholder(context),
          ),
        );
      },
    );
  }

  Widget _frame(BuildContext context, Widget? photo) {
    final CieloColors c = CieloColors.of(context);
    Widget content = photo ?? _placeholder(context);
    if (photo != null && c.mediaFilter != null) {
      content = ColorFiltered(colorFilter: c.mediaFilter!, child: content);
    }
    return Semantics(
      container: true,
      image: true,
      label: photo == null
          ? CieloStrings.profilePhotoEmpty
          : CieloStrings.profilePhoto,
      excludeSemantics: true,
      child: Container(
        width: widget.size,
        height: widget.size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: CieloRadius.cardAll,
          border: Border.all(color: photo == null ? c.accent : c.outlineStrong),
        ),
        child: content,
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Center(
    child: Icon(
      Icons.person_outline_rounded,
      size: widget.size * 0.46,
      color: CieloColors.of(context).accent,
    ),
  );
}
