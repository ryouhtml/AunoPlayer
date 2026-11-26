import 'dart:async';
import 'dart:typed_data';

import 'package:auno_player/features/player/widgets/audio_analysis_sheet.dart';
import 'package:auno_player/l10n/english_l10n.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/src/rust/api/audio_analysis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _song = Song(
  id: 'local-1',
  title: 'Test Track',
  artist: 'Test Artist',
  album: 'Test Album',
  filePath: '/tmp/auno-test.flac',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
);

AudioSourceAnalysis _analysis({
  AudioSourceAnalysisStatus status = AudioSourceAnalysisStatus.ok,
  String? codec = 'FLAC',
  String? container = 'FLAC',
  int? sampleRate = 44100,
  int? bitDepth = 16,
  int? channels = 2,
  String? dsdVariant,
  double? sideMidDb = -18.0,
}) {
  return AudioSourceAnalysis(
    status: status,
    fileSizeBytes: BigInt.from(1234567),
    durationSeconds: 180.5,
    sampleRate: sampleRate,
    channels: channels,
    bitDepth: bitDepth,
    channelPeakDb: Float64List.fromList(const [-1.0, -1.2]),
    channelRmsDb: Float64List.fromList(const [-14.0, -14.5]),
    balanceDb: 0.2,
    sideMidDb: sideMidDb,
    leadingSilenceSeconds: 0.1,
    trailingSilenceSeconds: 0.2,
    silent: false,
    lufs: -14.2,
    lra: 7.5,
    truePeakDb: -0.8,
    dr: 10.2,
    clipping: false,
    clippedSamples: BigInt.zero,
    codec: codec,
    container: container,
    bitrateBps: BigInt.from(900000),
    channelLayout: 'stereo',
    dsdVariant: dsdVariant,
    dopCapable: dsdVariant != null,
    tagCompleteness: 0.85,
    integrityOk: true,
    bitPerfectPath: true,
  );
}

class _FakeJob implements AudioSourceAnalysisJob {
  _FakeJob(this.decode, {this.progressValue = 1});

  final Future<AudioSourceAnalysis> decode;
  final double progressValue;
  int cancelCalls = 0;

  @override
  Future<AudioSourceAnalysis> analyze({required String path}) => decode;

  @override
  void cancel() => cancelCalls++;

  @override
  double progress() => progressValue;

  @override
  void dispose() {}

  @override
  bool get isDisposed => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Song song, AudioAnalysisJobFactory factory) {
  return MaterialApp(
    home: Scaffold(
      body: AudioAnalysisSheet(song: song, jobFactory: factory),
    ),
  );
}

void main() {
  testWidgets('shows a complete analysis without hiding any section',
      (tester) async {
    await tester.pumpWidget(
      _app(
        _song,
        () => _FakeJob(Future.value(_analysis(dsdVariant: 'DSD64'))),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.audioAnalysisFileSection), findsOneWidget);
    expect(find.text(l10n.audioAnalysisHiResSection), findsOneWidget);
    expect(find.text(l10n.audioAnalysisLevelsSection), findsOneWidget);
    expect(find.text(l10n.audioAnalysisLoudnessSection), findsOneWidget);
    expect(find.text(l10n.audioAnalysisSilenceSection), findsOneWidget);
    // The section title and its "no tag" row share the ReplayGain label.
    expect(find.text(l10n.audioAnalysisReplayGainSection), findsNWidgets(2));
    expect(find.text(l10n.audioAnalysisIntegritySection), findsOneWidget);
    expect(find.text(l10n.audioAnalysisOutputSection), findsOneWidget);
    expect(find.text(l10n.audioAnalysisSpectrogramSection), findsOneWidget);
    expect(find.text('FLAC'), findsWidgets);
    expect(find.text(l10n.audioAnalysisIntegrityOk), findsWidgets);
  });

  testWidgets('renders partial metadata without failing', (tester) async {
    await tester.pumpWidget(
      _app(
        _song,
        () => _FakeJob(
          Future.value(
            _analysis(
              codec: null,
              container: null,
              sampleRate: null,
              bitDepth: null,
              channels: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.audioAnalysisFileSection), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null test shows the real residual and a mono verdict',
      (tester) async {
    await tester.pumpWidget(
      _app(
        _song,
        () => _FakeJob(Future.value(_analysis(sideMidDb: -55.0))),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.audioAnalysisNullTestSection), findsOneWidget);
    expect(find.text(l10n.audioAnalysisNullTestResidual), findsOneWidget);
    expect(find.text(l10n.audioAnalysisNullTestVerdict), findsOneWidget);
    expect(find.text(l10n.audioAnalysisNullTestNote), findsOneWidget);
    expect(find.text('-55.0 dB'), findsOneWidget);
    expect(find.text(l10n.audioAnalysisNullTestMono), findsOneWidget);
  });

  testWidgets('null test warns when the side image is very wide',
      (tester) async {
    await tester.pumpWidget(
      _app(
        _song,
        () => _FakeJob(Future.value(_analysis(sideMidDb: -3.0))),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('-3.0 dB'), findsOneWidget);
    expect(find.text(l10n.audioAnalysisNullTestWide), findsOneWidget);
  });

  testWidgets('busy analysis offers a retry', (tester) async {
    await tester.pumpWidget(
      _app(
        _song,
        () => _FakeJob(
          Future.value(_analysis(status: AudioSourceAnalysisStatus.busy)),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.audioAnalysisBusy), findsOneWidget);
    expect(find.text(l10n.audioAnalysisRetry), findsOneWidget);
  });

  testWidgets('cancelled analysis offers a retry and retry reruns the job',
      (tester) async {
    var runs = 0;
    await tester.pumpWidget(
      _app(_song, () {
        runs++;
        return _FakeJob(
          Future.value(
            runs == 1
                ? _analysis(status: AudioSourceAnalysisStatus.cancelled)
                : _analysis(),
          ),
        );
      }),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.audioAnalysisCancelled), findsOneWidget);
    await tester.tap(find.text(l10n.audioAnalysisRetry));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(runs, 2);
    expect(find.text(l10n.audioAnalysisFileSection), findsOneWidget);
  });

  testWidgets('cancel button stops a running decode', (tester) async {
    final pending = Completer<AudioSourceAnalysis>();
    final job = _FakeJob(pending.future, progressValue: 0.4);
    await tester.pumpWidget(_app(_song, () => job));
    await tester.pump();

    expect(find.text(l10n.audioAnalysisCancel), findsOneWidget);
    await tester.tap(find.text(l10n.audioAnalysisCancel));
    await tester.pumpAndSettle();

    expect(job.cancelCalls, 1);
    expect(find.text(l10n.audioAnalysisCancelled), findsOneWidget);
    expect(find.text(l10n.audioAnalysisRetry), findsOneWidget);
  });

  testWidgets('blocked sources explain why analysis is unavailable',
      (tester) async {
    const networkSong = Song(
      id: 'remote-1',
      title: 'Remote',
      artist: 'Remote',
      filePath: '/tmp/remote.flac',
      duration: Duration(minutes: 3),
      fileType: 'FLAC',
      sourceType: 'webdav',
    );
    await tester.pumpWidget(
      _app(networkSong, () => _FakeJob(Future.value(_analysis()))),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.audioAnalysisLocalOnly), findsOneWidget);
    expect(find.text(l10n.audioAnalysisRetry), findsNothing);
  });
}
