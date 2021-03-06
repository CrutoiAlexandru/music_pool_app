import 'package:flutter/material.dart';
import 'package:MusicPool/ui/config.dart';
import 'package:MusicPool/ui/secondPage/player/player.dart';

// class for building the second page containing the player(mostly for spotify)
class SecondPage extends StatefulWidget {
  const SecondPage({Key? key}) : super(key: key);

  @override
  State<SecondPage> createState() => _SecondPage();
}

class _SecondPage extends State<SecondPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Config.back1,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25), topRight: Radius.circular(25)),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 50,
              child: Scaffold(
                backgroundColor: Colors.black,
                body: Column(
                  children: [
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          primary: Colors.transparent,
                          fixedSize: const Size(double.maxFinite, 60),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Icon(
                          Icons.arrow_drop_down_sharp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SongPlayer(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
