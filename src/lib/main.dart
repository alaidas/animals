import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnimalsApp());
}

class AnimalsApp extends StatelessWidget {
  const AnimalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Animals App',
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const LibraryScreen(repository: AnimalRepository()),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0A84FF),
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF0F131A) : const Color(0xFFF2F2F7),
    textTheme: Typography.blackCupertino.apply(
      bodyColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E),
      displayColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E),
    ),
  );
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.repository,
  });

  final AnimalRepository repository;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<AppLibrary>(
      future: repository.loadLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load animal packs.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          );
        }

        final library = snapshot.data!;

        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [Color(0xFF151922), Color(0xFF0F131A)]
                    : const [Color(0xFFF7F7FB), Color(0xFFEEF1F6)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Library',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: isDark
                                        ? const Color(0xFFB7BECA)
                                        : const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Animals App',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF0A84FF),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a pack',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.1,
                          ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 320,
                      child: Text(
                        'Explore available packs and upcoming worlds with the same polished, native mobile feel from the POC.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isDark
                                  ? const Color(0xFFA5ACB8)
                                  : const Color(0xFF666B76),
                              height: 1.35,
                            ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.builder(
                        itemCount: library.packs.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                        itemBuilder: (context, index) {
                          final pack = library.packs[index];
                          return _PackCard(
                            pack: pack,
                            isDark: isDark,
                            onTap: () {
                              if (pack.isLocked) {
                                final message = pack.isComingSoon
                                    ? '${pack.name} pack is not ready yet.'
                                    : '${pack.name} pack is locked.';
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                      SnackBar(content: Text(message)));
                                return;
                              }

                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ViewerScreen(pack: pack),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Center(
                      child: Text(
                        'Home',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? const Color(0xFFA5ACB8)
                                  : const Color(0xFF8E8E93),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.pack});

  final AnimalPack pack;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  int _currentIndex = 0;
  int _transitionDirection = 1;
  double? _dragStartX;

  AnimalItem get _currentAnimal => widget.pack.animals[_currentIndex];

  @override
  void initState() {
    super.initState();
    _setAnimal(0);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _setAnimal(int index) async {
    final nextAnimal = widget.pack.animals[index];
    final oldController = _videoController;
    final controller = VideoPlayerController.asset(nextAnimal.videoAssetPath);

    setState(() {
      _currentIndex = index;
      _videoController = controller;
    });

    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(0);
    await controller.play();

    if (!mounted || _videoController != controller) {
      await controller.dispose();
      return;
    }

    await oldController?.dispose();
    setState(() {});
  }

  Future<void> _playSound() async {
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(_currentAnimal.soundAssetSource));
  }

  void _goNext() {
    final nextIndex = (_currentIndex + 1) % widget.pack.animals.length;
    _transitionDirection = 1;
    _setAnimal(nextIndex);
  }

  void _goPrevious() {
    final previousIndex = (_currentIndex - 1 + widget.pack.animals.length) %
        widget.pack.animals.length;
    _transitionDirection = -1;
    _setAnimal(previousIndex);
  }

  @override
  Widget build(BuildContext context) {
    final animal = _currentAnimal;
    final isReady = _videoController?.value.isInitialized ?? false;
    final currentAnimalKey = ValueKey(animal.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragStart: (details) =>
            _dragStartX = details.globalPosition.dx,
        onHorizontalDragEnd: (details) {
          final start = _dragStartX;
          final velocity = details.primaryVelocity ?? 0;
          _dragStartX = null;

          if (velocity.abs() > 200) {
            velocity < 0 ? _goNext() : _goPrevious();
            return;
          }

          if (start == null) {
            return;
          }
        },
        onHorizontalDragUpdate: (details) {
          final start = _dragStartX;
          if (start == null) {
            return;
          }

          final delta = details.globalPosition.dx - start;
          if (delta.abs() < 24) {
            return;
          }

          _dragStartX = null;
          delta < 0 ? _goNext() : _goPrevious();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                final isIncoming = child.key == currentAnimalKey;
                final beginX = isIncoming
                    ? 0.18 * _transitionDirection
                    : -0.18 * _transitionDirection;
                final endX = isIncoming ? 0.0 : -0.08 * _transitionDirection;
                final offsetAnimation = Tween<Offset>(
                  begin: Offset(beginX, 0),
                  end: Offset(endX, 0),
                ).animate(animation);
                final fadeAnimation = CurvedAnimation(
                  parent: animation,
                  curve: isIncoming ? Curves.easeOut : Curves.easeIn,
                );

                return FadeTransition(
                  opacity: fadeAnimation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: _ViewerStage(
                key: currentAnimalKey,
                animal: animal,
                controller: isReady ? _videoController : null,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0x9E000000),
                  ],
                  stops: [0, 0.35, 1],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _GlassButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child:
                              const Icon(Icons.chevron_left_rounded, size: 28),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x66FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x47FFFFFF)),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.pack.animals.length}',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) {
                        final isIncoming = child.key == currentAnimalKey;
                        final beginX = isIncoming
                            ? 0.14 * _transitionDirection
                            : -0.14 * _transitionDirection;
                        final endX =
                            isIncoming ? 0.0 : -0.05 * _transitionDirection;
                        final offset = Tween<Offset>(
                          begin: Offset(beginX, 0),
                          end: Offset(endX, 0),
                        ).animate(animation);

                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offset,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        key: currentAnimalKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            animal.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              shadows: const [
                                Shadow(
                                  blurRadius: 12,
                                  color: Color(0x99000000),
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0x8C141418),
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: const Color(0x38FFFFFF)),
                            ),
                            child: Text(
                              animal.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GlassButton(
                          onPressed: _playSound,
                          circular: true,
                          child: const Icon(Icons.volume_up_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.isDark,
    required this.onTap,
  });

  final AnimalPack pack;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = pack.isLocked
        ? (isDark ? const Color(0xFF202530) : const Color(0xFFF1F3F8))
        : (isDark ? const Color(0xFF1A1F28) : const Color(0xFFFFFFFF));

    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E);
    final muted = isDark ? const Color(0xFFA5ACB8) : const Color(0xFF8E8E93);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: background.withOpacity(pack.isLocked ? 0.94 : 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0x14FFFFFF) : const Color(0xB8FFFFFF),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                offset: const Offset(0, 14),
                color:
                    isDark ? const Color(0x4D000000) : const Color(0x14312841),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0x1F0A84FF),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: Text(pack.emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                    const Spacer(),
                    if (pack.isLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xD1151A22)
                              : const Color(0xEFFFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          pack.isComingSoon ? 'Coming soon' : 'Locked',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  pack.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                Text(
                  pack.isComingSoon
                      ? 'Not ready yet'
                      : '${pack.animals.length} animals',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: muted,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerStage extends StatelessWidget {
  const _ViewerStage({
    super.key,
    required this.animal,
    required this.controller,
  });

  final AnimalItem animal;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(animal.imageAssetPath),
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (controller != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller!.value.size.width,
              height: controller!.value.size.height,
              child: VideoPlayer(controller!),
            ),
          ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.onPressed,
    required this.child,
    this.circular = false,
  });

  final VoidCallback onPressed;
  final Widget child;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(circular ? 999 : 18),
        child: Ink(
          width: circular ? 52 : null,
          height: circular ? 52 : 40,
          padding: circular
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xB3FFFFFF),
            borderRadius: BorderRadius.circular(circular ? 999 : 18),
            border: Border.all(color: const Color(0x47FFFFFF)),
          ),
          child: Center(
            child: IconTheme(
              data: const IconThemeData(color: Color(0xFF0A84FF)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimalRepository {
  const AnimalRepository();

  static const _packsAsset = 'assets/content/packs/packs.json';
  static const _textsAsset = 'assets/content/packs/jungle/texts.json';

  Future<AppLibrary> loadLibrary() async {
    final packsJson = jsonDecode(await rootBundle.loadString(_packsAsset))
        as Map<String, dynamic>;
    final textsJson = jsonDecode(await rootBundle.loadString(_textsAsset))
        as Map<String, dynamic>;

    final textItems = (textsJson['items'] as Map<String, dynamic>?) ?? {};
    final packs = (packsJson['packs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final jungleMap = packs.firstWhere(
      (pack) => pack['id'] == 'jungle',
      orElse: () => <String, dynamic>{},
    );

    final jungleAnimals = ((jungleMap['items'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>())
        .map((item) {
      final id = item['id'] as String? ?? '';
      final descriptionMap =
          ((textItems[id] as Map<String, dynamic>?)?['description']
                  as Map<String, dynamic>?) ??
              {};

      return AnimalItem(
        id: id,
        name: item['name'] as String? ?? 'Unknown animal',
        description: descriptionMap['en'] as String? ?? 'No description',
        imageAssetPath: _assetPath(item['image'] as String?),
        soundAssetPath: _assetPath(item['sound'] as String?),
        videoAssetPath: _assetPath(item['video'] as String?),
      );
    }).toList(growable: false);

    return AppLibrary(
      packs: [
        AnimalPack(
          id: 'jungle',
          name: 'Jungle',
          emoji: '🌿',
          animals: jungleAnimals,
        ),
        const AnimalPack(
          id: 'pets',
          name: 'Pets',
          emoji: '🐶',
          animals: [],
          isLocked: true,
        ),
        const AnimalPack(
          id: 'water',
          name: 'Water',
          emoji: '🐬',
          animals: [],
          isLocked: true,
        ),
        const AnimalPack(
          id: 'birds',
          name: 'Birds',
          emoji: '🦜',
          animals: [],
          isLocked: true,
          isComingSoon: true,
        ),
      ],
    );
  }

  static String _assetPath(String? path) => 'assets/${path ?? ''}';
}

class AppLibrary {
  const AppLibrary({required this.packs});

  final List<AnimalPack> packs;
}

class AnimalPack {
  const AnimalPack({
    required this.id,
    required this.name,
    required this.emoji,
    required this.animals,
    this.isLocked = false,
    this.isComingSoon = false,
  });

  final String id;
  final String name;
  final String emoji;
  final List<AnimalItem> animals;
  final bool isLocked;
  final bool isComingSoon;
}

class AnimalItem {
  const AnimalItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageAssetPath,
    required this.soundAssetPath,
    required this.videoAssetPath,
  });

  final String id;
  final String name;
  final String description;
  final String imageAssetPath;
  final String soundAssetPath;
  final String videoAssetPath;

  String get soundAssetSource => soundAssetPath.replaceFirst('assets/', '');
}
