import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class VideoPlayerSection extends StatefulWidget {
  const VideoPlayerSection({Key? key}) : super(key: key);

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
      // Create PeerConnection
      _peerConnection = await createPeerConnection({
        'iceServers': [
          // {'urls': 'stun:stun1.l.google.com:19302'},
          // {'urls': 'stun:stun2.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      });

      final iceGatheringStateComplete = Completer<void>();

      // Display received video stream in onTrack event
      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          setState(() {
            _stream = event.streams[0];
            _renderer.srcObject = _stream;
            _connected = true;
          });
        }
      };

      // Handle ICE Connection State disconnections
      _peerConnection!.onIceConnectionState = (state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          setState(() {
            _connected = false;
            _statusMessage = 'Connection lost. Try reconnecting.';
          });
        }
      };

      // Handle ICE Gathering State
      _peerConnection!.onIceGatheringState = (state) {
        print('ICE Gathering State: $state');

        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          print('ICE Gathering Complete');
          iceGatheringStateComplete.complete();
        }
      };

      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (candidate) {
        print('ICE Candidate: ${candidate.candidate}');
      };

      // Create an offer and set it as the local description
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': true,
        'offerToReceiveAudio': false,
      });
      await _peerConnection!.setLocalDescription(offer);
      print('Local SDP: ${offer.sdp}');

      print(
        'Local SDP:\n${(await _peerConnection!.getLocalDescription())?.sdp}',
      );

      // Wait for all ICE candidates to be gathered (completed via onIceCandidate)
      // Note: The availability of empty candidates may be platform-dependent,
      // so consider implementing a timeout mechanism if needed
      await iceGatheringStateComplete.future;

      print('All ICE candidates gathered');

      print(
        'Local SDP:\n${(await _peerConnection!.getLocalDescription())?.sdp}',
      );

      // Once all candidates are included in the LocalDescription, get the final SDP and send it to the server
      final localDesc = await _peerConnection!.getLocalDescription();
      if (localDesc == null) {
        throw Exception('Failed to get localDescription');
      }

      final response = await http.post(
        Uri.parse('$_serverUrl/offer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sdp': localDesc.sdp, 'type': localDesc.type}),
      );

      if (response.statusCode == 200) {
        // Set the response (Answer) from the server
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
