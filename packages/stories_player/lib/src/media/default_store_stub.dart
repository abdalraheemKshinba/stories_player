import 'story_media_store.dart';

/// Creates the default store on platforms without a file system.
StoryMediaStore createDefaultStore() => NoopStoryMediaStore();
