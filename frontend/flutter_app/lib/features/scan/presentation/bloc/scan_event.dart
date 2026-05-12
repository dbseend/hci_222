import 'dart:io';
import 'package:equatable/equatable.dart';

abstract class ScanEvent extends Equatable {
  const ScanEvent();
  @override
  List<Object?> get props => [];
}

class ScanImageCaptured extends ScanEvent {
  final File image;
  const ScanImageCaptured(this.image);

  // Avoid sync file metadata reads here: camera/gallery temp files can disappear
  // before bloc observers or tests read props.
  @override
  List<Object?> get props => [image.path];
}

class ScanReset extends ScanEvent {
  const ScanReset();
}

/// Used on web where File access is unavailable — skips detection and returns a mock result directly.
class ScanWebMockRequested extends ScanEvent {
  const ScanWebMockRequested();
}
