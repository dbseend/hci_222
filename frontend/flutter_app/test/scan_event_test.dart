import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trueprice/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:trueprice/features/scan/presentation/bloc/scan_event.dart';
import 'package:trueprice/features/scan/presentation/bloc/scan_state.dart';

void main() {
  group('ScanImageCaptured', () {
    test('props does not touch deleted temporary image files', () async {
      final dir = await Directory.systemTemp.createTemp('scan-event-test-');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      final image = File('${dir.path}/scan.jpg');
      await image.writeAsBytes([1, 2, 3]);
      final event = ScanImageCaptured(image);
      await image.delete();

      expect(() => event.props, returnsNormally);
      expect(event.props, [image.path]);
    });
  });

  test('web mock is rejected when demo fallbacks are disabled', () async {
    final bloc = ScanBloc(allowDemoFallbacks: false);
    addTearDown(bloc.close);

    final states = expectLater(
      bloc.stream,
      emitsInOrder([isA<ScanProcessing>(), isA<ScanError>()]),
    );
    bloc.add(const ScanWebMockRequested());
    await states;
  });
}
