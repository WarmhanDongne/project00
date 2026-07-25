import 'package:flutter/material.dart';
import 'package:project00/platform/hub/services/game_service.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            Row(
              children: [
                ShopButton(),
                const SizedBox(width: 300),
                const Expanded(child: SearchBar()),
                const SizedBox(width: 300),
                const Profile(),
              ],
            ),

            const SizedBox(height: 24),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(child: Gamelist()),
                  SizedBox(width: 24),
                  MemberTap(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 678,
      height: 50,
      decoration: const BoxDecoration(color: Colors.grey),
    );
  }
}

class Gamelist extends StatefulWidget {
  const Gamelist({super.key});

  @override
  State<Gamelist> createState() => _GamelistState();
}

class _GamelistState extends State<Gamelist> {
  final GameService _gameService = GameService();

  late Future<List<Map<String, dynamic>>> _games;

  @override
  void initState() {
    super.initState();
    _games = _gameService.fetchGames();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _games,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(snapshot.error.toString()),
          );
        }

        final games = snapshot.data ?? [];

        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 50,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilterBar(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: GridView.builder(
                itemCount: games.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 26,
                  mainAxisSpacing: 50,
                  childAspectRatio: 164 / 200,
                ),
                itemBuilder: (context, index) {
                  final game = games[index];

                  return Container(
                    decoration: BoxDecoration(
                      color: game['isOwned']
                          ? Colors.blue
                          : Colors.grey,
                    ),
                    child: Center(
                      child: Text(game['name']),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class ShopButton extends StatelessWidget {
  const ShopButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {},
      label: const Text('상점'),
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 12),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  const SearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      child: TextField(
        decoration: InputDecoration(
          hintText: '게임 검색',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, color: Colors.white),
    );
  }
}

class MemberTap extends StatelessWidget {
  const MemberTap({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SizedBox(width: 230, height: 50, child: InitializeButton()),
          ),
          const SizedBox(height: 16),
          Expanded(child: Container(color: Colors.grey)),
        ],
      ),
    );
  }
}

class InitializeButton extends StatelessWidget {
  const InitializeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {},
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),
      child: const Text('초기화'),
    );
  }
}