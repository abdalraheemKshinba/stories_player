import 'file_story_media_store_io.dart';
import 'story_media_store.dart';

/// Creates the default store on platforms with a file system.
StoryMediaStore createDefaultStore() => FileStoryMediaStore();
