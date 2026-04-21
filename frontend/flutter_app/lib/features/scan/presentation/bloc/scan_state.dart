// scan_state.dart
// States emitted by ScanBloc during the image-capture → detection flow.
// ScanInitial → ScanProcessing → ScanDetected | ScanError

import 'package:equatable/equatable.dart';
import '../../data/models/detection_result.dart';

abstract class ScanState extends Equatable {
  const ScanState();
  @override
  List<Object?> get props => [];
}

class ScanInitial extends ScanState {
  const ScanInitial();
}

class ScanProcessing extends ScanState {
  const ScanProcessing();
}

class ScanDetected extends ScanState {
  final DetectionResult result;
  const ScanDetected(this.result);
  @override
  List<Object?> get props => [result];
}

class ScanError extends ScanState {
  final String message;
  const ScanError(this.message);
  @override
  List<Object?> get props => [message];
}
