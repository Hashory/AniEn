import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class VideoPlayerSection extends StatefulWidget {
  const VideoPlayerSection({super.key});

  @override
  State<VideoPlayerSection> createState() => _VideoPlayerSectionState();
}

class _VideoPlayerSectionState extends State<VideoPlayerSection> {
  // State
  bool _connected = false;
  bool _connecting = false;
  String _statusMessage = 'Tap Connect to start';

  // WebRTC objects
  final _renderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _stream;

  // Server endpoint
  final _serverUrl = 'http://localhost:41395';

  @override
  void initState() {
    super.initState();
    _renderer.initialize();
  }

  Future<void> _connect() async {
    if (_connecting) return;

    setState(() {
      _connecting = true;
      _statusMessage = 'Connecting...';
    });

    try {
      // Create peer connection
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      });

      // Set up track event handler
      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          setState(() {
            _stream = event.streams[0];
            _renderer.srcObject = _stream;
            _connected = true;
          });
        }
      };

      // Set up connection state handler
      _peerConnection!.onIceConnectionState = (state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          setState(() {
            _connected = false;
            _statusMessage = 'Connection lost. Try reconnecting.';
          });
        }
      };

      // Create and send offer
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(offer);

      // await _waitForIceGatheringComplete();

      final response = await http.post(
        Uri.parse('$_serverUrl/offer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sdp': offer.sdp, 'type': offer.type}),
      );

      if (response.statusCode == 200) {
        final answer = jsonDecode(response.body);
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _connecting = false;
      });
    }
  }

  Future<void> _waitForIceGatheringComplete() async {
    // // if the connection is already complete, return
    // if (_peerConnection!.iceGatheringState ==
    //     RTCIceGatheringState.RTCIceGatheringStateComplete) {
    //   return;
    // }
    // // Wait for completion using Completer
    final completer = Completer<void>();
    // print(_peerConnection!.iceGatheringState);
    // _peerConnection!.onIceGatheringState = (state) {
    //   print(state);
    //   if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
    //     completer.complete();
    //   }
    // };

    _peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) async {
      if (candidate == null) {
        completer.complete();
        return;
      }

      print('New ICE candidate: ${candidate.toString()}');

      await _peerConnection!.addCandidate(candidate!);
    };

    await completer.future;
  }

  @override
  void dispose() {
    _renderer.dispose();
    _peerConnection?.close();
    _stream?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child:
          _connected && _stream != null
              ? RTCVideoView(
                _renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              )
              : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _connecting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : ElevatedButton(
                          onPressed: _connect,
                          child: const Text('Connect'),
                        ),
                  ],
                ),
              ),
    );
  }
}
