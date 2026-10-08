import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../model/story_media.dart';
import 'story_media_store.dart';

/// A disk cache for story media, bounded in bytes.
///
/// * **Bounded in bytes.** [maxBytes] is enforced after every download, not
///   on a schedule. The least recently used files go first.
/// * **Never evicts what is on screen.** Pinned media survives eviction.
/// * **Expires.** Media past its `expiresAt`, or unused for [maxAge], is
///   deleted by [purgeExpired], which runs when the store opens.
/// * **Resumable.** Downloads continue from the bytes already on disk with
///   HTTP `Range` requests, so a cancelled prefetch is never wasted.
/// * **One queue.** At most [maxConcurrentDownloads] run at once; the item
///   on screen pauses everything less urgent.
///
/// Files live in the app's cache directory, which the operating system may
/// clear when space runs low and which is not counted as user data.
///
/// {@tool snippet}
/// ```dart
/// final store = FileStoryMediaStore(
///   maxBytes: 80 * 1024 * 1024,
///   maxAge: const Duration(days: 2),
/// );
/// StoryMediaStore.instance = store; // the default for every player
/// ```
/// {@end-tool}
final class FileStoryMediaStore extends StoryMediaStore {
  /// Creates a store. Nothing is read from disk until first use.
  ///
  /// [directory] defaults to `stories_player` inside the app's cache
  /// directory. [httpClient] is for tests.
  FileStoryMediaStore({
    this.maxBytes = 100 * 1024 * 1024,
    this.maxAge = const Duration(days: 2),
    this.maxConcurrentDownloads = 2,
    String? directory,
    HttpClient? httpClient,
  }) : assert(maxBytes > 0, 'maxBytes must be positive.'),
       assert(maxConcurrentDownloads > 0, 'At least one download must run.'),
       _directoryOverride = directory,
       _client = httpClient ?? HttpClient();

  /// The most bytes the store keeps on disk.
  final int maxBytes;

  /// How long unused media is kept.
  final Duration maxAge;

  /// How many downloads run at the same time.
  final int maxConcurrentDownloads;

  final String? _directoryOverride;
  final HttpClient _client;
  final Map<String, _Entry> _entries = {};
  final Map<String, _Job> _jobs = {};
  final Map<String, int> _pins = {};
  late final Future<void> _ready = _open();
  late String _dir;
  bool _isOpen = false;
  bool _isDisposed = false;
  Timer? _saveTimer;
  int _sequence = 0;
  double? _bitsPerSecond;

  @override
  bool get supportsFiles => true;

  @override
  double? get estimatedBitsPerSecond => _bitsPerSecond;

  /// The directory the store writes to, once opened.
  @visibleForTesting
  Future<String> get directory async {
    await _ready;
    return _dir;
  }

  @override
  String? lookup(StoryMedia media) {
    if (!_isOpen) {
      unawaited(_ready);
      return null;
    }
    if (media.source == StoryMediaSource.file) return media.filePath;
    final entry = _entries[media.cacheKey];
    if (entry == null || !entry.complete) return null;
    entry.lastAccess = _now();
    _scheduleSave();
    return _pathOf(entry);
  }

  @override
  Future<String?> fetch(
    StoryMedia media, {
    StoryFetchPriority priority = StoryFetchPriority.visible,
    int? maxBytes,
    StoryFetchToken? token,
    DateTime? expiresAt,
  }) async {
    if (media.source == StoryMediaSource.file) return media.filePath;
    if (!media.isNetwork || _isDisposed) return null;
    await _ready;
    if (token != null && token.isCancelled) return null;

    final key = media.cacheKey;
    final entry = _entries[key];
    if (expiresAt != null && entry != null) {
      entry.expiresAt = expiresAt.millisecondsSinceEpoch;
    }
    if (entry != null && entry.complete) {
      entry.lastAccess = _now();
      _scheduleSave();
      return _pathOf(entry);
    }
    if (maxBytes != null && entry != null && entry.size >= maxBytes) {
      return null;
    }

    final job = _jobs.putIfAbsent(
      key,
      () => _Job(media, priority, _sequence++, expiresAt),
    );
    if (priority.index < job.priority.index) job.priority = priority;
    final waiter = _Waiter(maxBytes);
    job.waiters.add(waiter);
    if (token != null) {
      void onCancel() {
        if (job.waiters.remove(waiter)) waiter.complete(null);
        if (job.waiters.isEmpty) _stop(job, cancel: true);
      }

      token.addListener(onCancel);
      unawaited(
        waiter.completer.future.then(
          (_) => token.removeListener(onCancel),
          onError: (Object _) => token.removeListener(onCancel),
        ),
      );
    }
    _pump();
    return waiter.completer.future;
  }

  @override
  void pin(StoryMedia media) =>
      _pins.update(media.cacheKey, (count) => count + 1, ifAbsent: () => 1);

  @override
  void unpin(StoryMedia media) {
    final key = media.cacheKey;
    final count = _pins[key];
    if (count == null) return;
    if (count <= 1) {
      _pins.remove(key);
    } else {
      _pins[key] = count - 1;
    }
  }

  @override
  Future<void> purgeExpired() async {
    await _ready;
    await _purgeExpired();
  }

  Future<void> _purgeExpired() async {
    final now = _now();
    final oldest = now - maxAge.inMilliseconds;
    final expired = _entries.values.where(
      (entry) =>
          _isEvictable(entry) &&
          ((entry.expiresAt != null && entry.expiresAt! <= now) ||
              entry.lastAccess < oldest),
    );
    for (final entry in expired.toList()) {
      await _delete(entry);
    }
    _scheduleSave();
  }

  @override
  Future<void> evict(StoryMedia media) async {
    await _ready;
    final entry = _entries[media.cacheKey];
    if (entry != null) {
      final job = _jobs[entry.key];
      if (job != null) _stop(job, cancel: true);
      await _delete(entry);
      _scheduleSave();
    }
  }

  @override
  Future<void> clear() async {
    await _ready;
    for (final job in _jobs.values.toList()) {
      _stop(job, cancel: true);
    }
    for (final entry in _entries.values.toList()) {
      await _delete(entry);
    }
    _scheduleSave();
  }

  @override
  Future<StoryMediaStoreUsage> usage() async {
    await _ready;
    return StoryMediaStoreUsage(
      bytes: _entries.values.fold(0, (sum, entry) => sum + entry.size),
      entries: _entries.length,
    );
  }

  @override
  Future<void> dispose() async {
    if (identical(StoryMediaStore.instance, this) || _isDisposed) return;
    _isDisposed = true;
    for (final job in _jobs.values.toList()) {
      _stop(job, cancel: true);
    }
    _saveTimer?.cancel();
    if (_isOpen) await _saveIndex();
    _client.close(force: true);
  }

  // ---------------------------------------------------------------- opening

  Future<void> _open() async {
    _dir =
        _directoryOverride ??
        '${(await getApplicationCacheDirectory()).path}/stories_player';
    final dir = Directory(_dir);
    await dir.create(recursive: true);
    final index = File('$_dir/index.json');
    if (await index.exists()) {
      try {
        final json = jsonDecode(await index.readAsString());
        if (json is Map<String, Object?> && json['entries'] is List) {
          for (final raw in json['entries']! as List<Object?>) {
            if (raw is Map<String, Object?>) {
              final entry = _Entry.fromJson(raw);
              if (entry != null) _entries[entry.key] = entry;
            }
          }
        }
      } on FormatException {
        // A corrupt index is rebuilt from scratch below.
      }
    }
    // Drop entries whose files vanished, and files nothing points to.
    final known = <String>{'index.json', 'index.json.tmp'};
    for (final entry in _entries.values.toList()) {
      final file = File(entry.complete ? _pathOf(entry) : _partPathOf(entry));
      if (!await file.exists()) {
        _entries.remove(entry.key);
        continue;
      }
      entry.size = await file.length();
      known.add(file.uri.pathSegments.last);
    }
    await for (final file in dir.list()) {
      final name = file.uri.pathSegments.last;
      if (file is File && !known.contains(name)) {
        await file.delete().catchError((Object _) => file);
      }
    }
    _isOpen = true;
    await _purgeExpired();
    await _enforceLimit();
  }

  // ------------------------------------------------------------- scheduling

  void _pump() {
    if (_isDisposed || !_isOpen) return;
    final queued = _jobs.values.where((job) => !job.running).toList()
      ..sort(
        (a, b) => a.priority.index != b.priority.index
            ? a.priority.index - b.priority.index
            : a.sequence - b.sequence,
      );
    var running = _jobs.values.where((job) => job.running).length;
    for (final job in queued) {
      if (running >= maxConcurrentDownloads) {
        if (job.priority != StoryFetchPriority.visible) break;
        // The item on screen pauses the least urgent running download.
        final victim = _jobs.values
            .where(
              (other) =>
                  other.running &&
                  !other.stopping &&
                  other.priority.index > job.priority.index,
            )
            .fold<_Job?>(
              null,
              (worst, other) =>
                  worst == null || other.priority.index > worst.priority.index
                  ? other
                  : worst,
            );
        if (victim == null) break;
        _stop(victim, cancel: false);
        running--;
      }
      running++;
      unawaited(_run(job));
    }
  }

  void _stop(_Job job, {required bool cancel}) {
    if (cancel) {
      job.cancelled = true;
      for (final waiter in job.waiters) {
        waiter.complete(null);
      }
      job.waiters.clear();
      if (!job.running) _jobs.remove(job.media.cacheKey);
    }
    if (job.running) {
      job.stopping = true;
      job.request?.abort();
      // Aborting does not always end the response stream; end it here.
      final done = job.streamDone;
      if (done != null && !done.isCompleted) done.complete();
    }
  }

  // ------------------------------------------------------------ downloading

  Future<void> _run(_Job job) async {
    job
      ..running = true
      ..stopping = false;
    final media = job.media;
    final key = media.cacheKey;
    final entry = _entries.putIfAbsent(
      key,
      () => _Entry(key: key, fileName: _fileNameFor(media), lastAccess: _now()),
    );
    if (job.expiresAt != null) {
      entry.expiresAt = job.expiresAt!.millisecondsSinceEpoch;
    }
    entry.lastAccess = _now();
    final limit = job.byteLimit;
    final part = File(_partPathOf(entry));
    var start = await part.exists() ? await part.length() : 0;
    final stopwatch = Stopwatch()..start();
    var fetched = 0;
    Object? failure;

    try {
      if (limit != null && start >= limit) {
        entry.size = start;
      } else {
        final request = await _client.getUrl(media.uri!);
        job.request = request;
        media.headers.forEach(request.headers.set);
        if (start > 0 || limit != null) {
          request.headers.set(
            HttpHeaders.rangeHeader,
            'bytes=$start-${limit == null ? '' : limit - 1}',
          );
        }
        final response = await request.close();
        int? total;
        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
            start > 0) {
          // The partial file already holds everything.
          total = entry.total ?? start;
          await response.drain<void>();
        } else if (response.statusCode == HttpStatus.partialContent) {
          final range = response.headers.value(HttpHeaders.contentRangeHeader);
          total = int.tryParse(range?.split('/').last ?? '') ?? entry.total;
        } else if (response.statusCode == HttpStatus.ok) {
          start = 0;
          total = response.contentLength >= 0 ? response.contentLength : null;
        } else {
          await response.drain<void>();
          throw StoryMediaException(
            media,
            'Unexpected response',
            statusCode: response.statusCode,
          );
        }
        entry.total = total ?? entry.total;
        if (response.statusCode != HttpStatus.requestedRangeNotSatisfiable) {
          final sink = part.openWrite(
            mode: start == 0 ? FileMode.write : FileMode.append,
          );
          var received = start;
          final done = Completer<void>();
          job.streamDone = done;
          job.subscription = response.listen(
            (chunk) {
              sink.add(chunk);
              received += chunk.length;
              fetched += chunk.length;
              entry.size = received;
              if (limit != null && received >= limit && !done.isCompleted) {
                done.complete();
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!done.isCompleted) done.completeError(error, stackTrace);
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
          try {
            await done.future;
          } finally {
            await job.subscription?.cancel();
            job
              ..subscription = null
              ..streamDone = null;
            await sink.flush();
            await sink.close();
            entry.size = received;
          }
          if (entry.total == null && limit == null) entry.total = received;
        }
      }
    } on Object catch (error) {
      failure = error;
    } finally {
      job.request = null;
    }

    _recordBandwidth(fetched, stopwatch.elapsed);
    job.running = false;

    if (job.stopping || job.cancelled) {
      job.stopping = false;
      if (job.cancelled || job.waiters.isEmpty) _jobs.remove(key);
      _scheduleSave();
      await _enforceLimit();
      _pump();
      return;
    }

    _jobs.remove(key);
    if (failure != null) {
      final error = failure is StoryMediaException
          ? failure
          : StoryMediaException(media, failure.toString());
      for (final waiter in job.waiters) {
        waiter.completeError(error);
      }
    } else {
      if (entry.total != null && entry.size >= entry.total!) {
        await part.rename(_pathOf(entry));
        entry.complete = true;
      }
      final path = entry.complete ? _pathOf(entry) : null;
      for (final waiter in job.waiters) {
        waiter.complete(path);
      }
    }
    _scheduleSave();
    await _enforceLimit();
    _pump();
  }

  void _recordBandwidth(int bytes, Duration elapsed) {
    if (bytes < 32 * 1024 || elapsed.inMilliseconds < 50) return;
    final sample = bytes * 8 * 1000 / elapsed.inMilliseconds;
    _bitsPerSecond = _bitsPerSecond == null
        ? sample
        : _bitsPerSecond! * 0.7 + sample * 0.3;
  }

  // -------------------------------------------------------------- eviction

  bool _isEvictable(_Entry entry) =>
      !_pins.containsKey(entry.key) && !(_jobs[entry.key]?.running ?? false);

  Future<void> _enforceLimit() async {
    var total = _entries.values.fold(0, (sum, entry) => sum + entry.size);
    if (total <= maxBytes) return;
    final candidates = _entries.values.where(_isEvictable).toList()
      ..sort((a, b) => a.lastAccess - b.lastAccess);
    for (final entry in candidates) {
      if (total <= maxBytes) break;
      total -= entry.size;
      await _delete(entry);
    }
    _scheduleSave();
  }

  Future<void> _delete(_Entry entry) async {
    _entries.remove(entry.key);
    for (final path in [_pathOf(entry), _partPathOf(entry)]) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete().catchError((Object _) => file);
      }
    }
  }

  // ----------------------------------------------------------------- index

  void _scheduleSave() {
    if (_isDisposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveIndex);
  }

  Future<void> _saveIndex() async {
    if (!_isOpen) return;
    final tmp = File('$_dir/index.json.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'version': 1,
        'entries': [for (final entry in _entries.values) entry.toJson()],
      }),
      flush: true,
    );
    await tmp.rename('$_dir/index.json');
  }

  // ----------------------------------------------------------------- paths

  String _pathOf(_Entry entry) => '$_dir/${entry.fileName}';

  String _partPathOf(_Entry entry) => '$_dir/${entry.fileName}.part';

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static String _fileNameFor(StoryMedia media) {
    final key = media.cacheKey;
    // FNV-1a, 64 bits: short, stable, and collision-free in practice for a
    // few hundred URLs. The URL itself is kept in the index.
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(key)) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    final name = hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
    return '$name.${_extensionFor(media)}';
  }

  static String _extensionFor(StoryMedia media) {
    final explicit = media.extension;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final segments = media.uri?.pathSegments ?? const <String>[];
    final last = segments.isEmpty ? '' : segments.last;
    final dot = last.lastIndexOf('.');
    if (dot > 0) {
      final ext = last.substring(dot + 1).toLowerCase();
      if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) return ext;
    }
    return switch (media.kind) {
      StoryMediaKind.image => 'jpg',
      StoryMediaKind.video => 'mp4',
      StoryMediaKind.lottie => 'json',
      StoryMediaKind.audio => 'm4a',
      StoryMediaKind.other => 'bin',
    };
  }
}

final class _Entry {
  _Entry({
    required this.key,
    required this.fileName,
    required this.lastAccess,
    this.total,
    this.complete = false,
    this.expiresAt,
  });

  static _Entry? fromJson(Map<String, Object?> json) {
    final key = json['key'];
    final fileName = json['file'];
    final lastAccess = json['lastAccess'];
    if (key is! String || fileName is! String || lastAccess is! int) {
      return null;
    }
    return _Entry(
      key: key,
      fileName: fileName,
      lastAccess: lastAccess,
      total: json['total'] as int?,
      complete: json['complete'] == true,
      expiresAt: json['expiresAt'] as int?,
    );
  }

  final String key;
  final String fileName;
  int lastAccess;
  int size = 0;
  int? total;
  bool complete;
  int? expiresAt;

  Map<String, Object?> toJson() => {
    'key': key,
    'file': fileName,
    'lastAccess': lastAccess,
    'total': total,
    'complete': complete,
    'expiresAt': expiresAt,
  };
}

final class _Job {
  _Job(this.media, this.priority, this.sequence, this.expiresAt);

  final StoryMedia media;
  StoryFetchPriority priority;
  final int sequence;
  final DateTime? expiresAt;
  final List<_Waiter> waiters = [];
  HttpClientRequest? request;
  StreamSubscription<List<int>>? subscription;
  Completer<void>? streamDone;
  bool running = false;
  bool stopping = false;
  bool cancelled = false;

  /// The bytes to fetch: everything if any waiter wants the whole file.
  int? get byteLimit {
    if (waiters.isEmpty || waiters.any((w) => w.maxBytes == null)) return null;
    return waiters.map((w) => w.maxBytes!).reduce((a, b) => a > b ? a : b);
  }
}

final class _Waiter {
  _Waiter(this.maxBytes);

  final int? maxBytes;
  final Completer<String?> completer = Completer<String?>();

  void complete(String? path) {
    if (!completer.isCompleted) completer.complete(path);
  }

  void completeError(Object error) {
    if (!completer.isCompleted) completer.completeError(error);
  }
}
