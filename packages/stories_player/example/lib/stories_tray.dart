import 'package:flutter/material.dart';
import 'package:stories_player/stories_player.dart';

/// The row of story circles an app shows above its content.
///
/// The tray is the app's own widget, not part of the package: every app
/// draws it differently. Its avatars use [StoryMediaImage], so the player
/// later finds them already cached.
class StoriesTray extends StatelessWidget {
  const StoriesTray({
    super.key,
    required this.groups,
    required this.isSeen,
    required this.onTap,
  });

  final List<StoryGroup> groups;
  final bool Function(StoryGroup group) isSeen;
  final ValueChanged<StoryGroup> onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        final group = groups[index];
        final seen = isSeen(group);
        return Semantics(
          button: true,
          label: group.label,
          child: GestureDetector(
            onTap: () => onTap(group),
            child: SizedBox(
              width: 76,
              child: Column(
                children: [
                  _Ring(
                    seen: seen,
                    child: ClipOval(
                      child: StoryMediaImage(
                        group.avatar!,
                        width: 64,
                        height: 64,
                        color: const Color(0xFFEDE7E3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group.label ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: seen ? FontWeight.w400 : FontWeight.w600,
                      color: seen ? Colors.black45 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Ring extends StatelessWidget {
  const _Ring({required this.seen, required this.child});

  final bool seen;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: seen
          ? null
          : const SweepGradient(
              colors: [
                Color(0xFFFF6B2C),
                Color(0xFFEE4266),
                Color(0xFFFFC23C),
                Color(0xFFFF6B2C),
              ],
            ),
      color: seen ? const Color(0xFFD9D4D0) : null,
    ),
    child: Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFAF7F5),
      ),
      child: child,
    ),
  );
}
