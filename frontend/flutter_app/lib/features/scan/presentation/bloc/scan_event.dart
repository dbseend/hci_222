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

  // File itself is not equatable — use path + lastModified for identity
  @override
  List<Object?> get props => [image.path, image.lastModifiedSync()];
}

class ScanReset extends ScanEvent {
  const ScanReset();
}

/// Used on web where File access is unavailable — skips detection and returns a mock result directly.
class ScanWebMockRequested extends ScanEvent {
  const ScanWebMockRequested();
}
