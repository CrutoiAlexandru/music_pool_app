import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:MusicPool/global/global.dart';
import 'package:MusicPool/global/session/session.dart';
import 'package:MusicPool/platform_controller/spotify/spotify_controller.dart';
import 'package:MusicPool/ui/config.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

// class made for retrieving and showing player state data such as:
//    audio progress(spotify)
//    audio duration(spotify)
class BuildPlayerStateWidget extends StatefulWidget {
  const BuildPlayerStateWidget({Key? key}) : super(key: key);

  @override
  State<BuildPlayerStateWidget> createState() => _BuildPlayerStateWidget();
}

class _BuildPlayerStateWidget extends State<BuildPlayerStateWidget> {
  // timer used for second based progress update from spotify
  late Timer timer;
  // data stream from our database
  late Stream database;

  @override
  void initState() {
    database = FirebaseFirestore.instance
        .collection('default')
        .orderBy('order')
        .snapshots();
    getSongLengthSpotify();
    setTimerSpotify();
    super.initState();
  }

  @override
  void dispose() {
    cancelTimer();
    super.dispose();
  }

  // method for retrieving the song length every time the song changes
  getSongLengthSpotify() async {
    var url = Uri.https('api.spotify.com', '/v1/me/player');
    final res = await http.get(url,
        headers: {'Authorization': 'Bearer ${SpotifyController.token}'});

    var body = jsonDecode(res.body);
    if (body['item']['duration_ms'].runtimeType == int) {
      double duration = body['item']['duration_ms'].toDouble();

      Provider.of<GlobalNotifier>(context, listen: false).setDuration(duration);
    }
  }

  // this way we get the progress of our song every second
  // we do it this way because the stream from spotify sdk about player state does not currently update
  // even though there will be a lot of calls to spotify api
  // more precise it would be for even more often calls?
  setTimerSpotify() {
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        Map body;
        var url = Uri.https('api.spotify.com', '/v1/me/player');
        final res = await http.get(url,
            headers: {'Authorization': 'Bearer ${SpotifyController.token}'});

        body = jsonDecode(res.body);

        if (body['progress_ms'].runtimeType == int) {
          if (body['progress_ms'] != 0) {
            double progress = body['progress_ms'].toDouble();

            Provider.of<GlobalNotifier>(context, listen: false)
                .setProgress(progress);
          }
        }
      },
    );
  }

  // method for canceling the timer
  cancelTimer() {
    timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    // database connection (firestore)
    if (Provider.of<SessionNotifier>(context).session.isNotEmpty) {
      database = FirebaseFirestore.instance
          .collection(Provider.of<SessionNotifier>(context).session)
          .orderBy('order')
          .snapshots();
    } else {
      database = FirebaseFirestore.instance
          .collection('default')
          .orderBy('order')
          .snapshots();
    }

    // if the progress and duration are equal it means the song is over
    // if so we tell our player state that over = true in order to play the next song in queue
    // we have to do it manually because we use a separate queue held in firestore
    // we do not use the automatic queues given by our playing services
    // should >= with duration - 1 in case of mistakes or timing induced errors
    if ((Provider.of<GlobalNotifier>(context).progress / 1000).floor() >=
            (Provider.of<GlobalNotifier>(context).duration / 1000).floor() -
                1 &&
        Provider.of<GlobalNotifier>(context).duration != 0) {
      Provider.of<GlobalNotifier>(context, listen: false).setOver(true);
    }

    // auto play method to skip to next song
    autoPlayNext(snapshot) {
      Provider.of<GlobalNotifier>(context, listen: false).setPlaying(
          Provider.of<GlobalNotifier>(context, listen: false).playing + 1);
      if (snapshot.data!.docs
              .toList()[
                  Provider.of<GlobalNotifier>(context, listen: false).playing]
              .data()['platform'] ==
          'spotify') {
        SpotifyController.play(snapshot.data!.docs
            .toList()[
                Provider.of<GlobalNotifier>(context, listen: false).playing]
            .data()['playback_uri']);
      }
      Provider.of<GlobalNotifier>(context, listen: false).setPlayingState(true);
    }

    // updating method for our progress bar
    if (Provider.of<GlobalNotifier>(context).playState) {
      if (!timer.isActive) {
        setTimerSpotify();
      }
    } else {
      if (timer.isActive) {
        cancelTimer();
      }
    }

    // shouldn't execute when playing from yt
    // every time the song changes get its length
    // executes too many times because of the way providers work
    if ((Provider.of<GlobalNotifier>(context).progress / 1000).floor() <= 1 &&
        Provider.of<GlobalNotifier>(context).playState) {
      getSongLengthSpotify();
    }

    return StreamBuilder(
      stream: database,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasError) {
          return const Text('Something went wrong',
              textAlign: TextAlign.center);
        }

        if (snapshot.connectionState != ConnectionState.waiting &&
                snapshot.data.docs.isEmpty ||
            Provider.of<GlobalNotifier>(context).playing == -1) {
          return const SizedBox();
        }

        // when song is over play next song in queue
        if (Provider.of<GlobalNotifier>(context).over) {
          // currently the method gets executed while building, not ok but works in case of not being able to work around it
          autoPlayNext(snapshot);
          Provider.of<GlobalNotifier>(context, listen: false).setOver(false);
        }

        return Hero(
          tag: 'playerState',
          child: Column(
            children: [
              Slider(
                value: Provider.of<GlobalNotifier>(context).duration > 0
                    ? Provider.of<GlobalNotifier>(context).progress
                    : 0,
                min: 0,
                max: Provider.of<GlobalNotifier>(context).duration > 0
                    ? Provider.of<GlobalNotifier>(context).duration
                    : 0,
                onChanged: (double value) {},
                onChangeEnd: (double value) {
                  SpotifyController.seekTo(value * 1000);
                  SpotifyController.resume();
                },
                inactiveColor: Config.colorStyleDark,
                activeColor: Config.colorStyle,
              ),
            ],
          ),
        );
      },
    );
  }
}
