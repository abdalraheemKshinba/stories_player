import 'dart:async';

import 'package:flutter/foundation.dart';

import 'story_item_session.dart';

/// The sessions the player keeps alive: the current item and the few kept
/// warm around it. Owns their listeners and disposal.
@internal
final class StorySessionPool {
  /// Creates a pool that calls [onChanged] when any session changes.
  StorySessionPool({required this.onChanged});

  /// Called when any session in the pool changes.
  final VoidCallback onChanged;

  final Map<String, StoryItemSession> _sessions = {};
  final Set<StoryItemSession> _shown = {};

  /// Every live session.
  Iterable<StoryItemSession> get sessions => _sessions.values;

  /// The keys of every live session.
  Iterable<String> get keys => _sessions.keys;

  /// The session for [key], if live.
  StoryItemSession? operator [](String key) => _sessions[key];

  /// The session for [key], created with [create] and prepared if new.
  StoryItemSession obtain(String key, StoryItemSession Function() create) {
    final existing = _sessions[key];
    if (existing != null) return existing;
    final session = create();
    _sessions[key] = session;
    session.addListener(onChanged);
    unawaited(session.prepare());
    return session;
  }

  /// Records that [session] is being shown. Returns false if it was shown
  /// before, so the caller rewinds it.
  bool markShown(StoryItemSession session) => _shown.add(session);

  /// Disposes every session whose key is not in [keep].
  void keepOnly(Set<String> keep) {
    for (final key in _sessions.keys.toList()) {
      if (!keep.contains(key)) remove(key);
    }
  }

  /// Disposes the session for [key].
  void remove(String key) {
    final session = _sessions.remove(key);
    if (session == null) return;
    _shown.remove(session);
    session
      ..removeListener(onChanged)
      ..dispose();
  }

  /// Turns sound on or off in every session.
  void setMuted(bool muted) {
    for (final session in _sessions.values) {
      session.setMuted(muted);
    }
  }

  /// Disposes every session.
  void clear() => keepOnly(const {});
}
