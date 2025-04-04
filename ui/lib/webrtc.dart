import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

/// A singleton class that manages WebRTC connections and state
class WebRTCManager {
  // Singleton instance
  static final WebRTCManager _instance = WebRTCManager._internal();

  // Factory constructor to return the singleton instance
  factory WebRTCManager() {
    return _instance;
  }

  // Private constructor
  WebRTCManager._internal();

  // WebRTC related properties
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;

  // Stream controller to notify listeners about remote stream updates
  final StreamController<MediaStream?> _streamController =
      StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get onStreamUpdate => _streamController.stream;

  // Server URL for signaling
  final String _serverUrl = 'http://localhost:41395';

  // Configuration for peer connection with ICE servers enabled
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  // Connect to WebRTC server and return success status
  Future<bool> connectToServer() async {
    try {
      await initPeerConnection();
      return _remoteStream != null;
    } catch (e) {
      print('Error connecting to WebRTC server: $e');
      return false;
    }
  }

  // Get the remote media stream
  MediaStream? getRemoteStream() {
    return _remoteStream;
  }

  // Initialize peer connection
  Future<void> initPeerConnection() async {
    _peerConnection = await createPeerConnection(_configuration);

    // Listen for remote stream
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isEmpty) return;
      _remoteStream = event.streams[0];
      // Notify listeners about the new stream
      _streamController.add(_remoteStream);
      print('Remote stream received and updated');
    };

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      print('Got ICE candidate: ${candidate.candidate}');
      // In a complete implementation, we would send this to the server
    };

    // Connection state monitoring
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state changed: $state');
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state changed: $state');

      // If we disconnect, update the stream to null
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _remoteStream = null;
        _streamController.add(null);
      }
    };

    var offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': false,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(offer);

    var response = await http.post(
      Uri.parse('$_serverUrl/offer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sdp': offer.sdp, 'type': offer.type}),
    );

    if (response.statusCode == 200) {
      var answer = jsonDecode(response.body);
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
    } else {
      print('Failed to send offer: ${response.statusCode}');
    }
  }

  // Close connection and clean up resources
  void dispose() {
    _remoteStream?.dispose();
    _peerConnection?.close();
    _streamController.close();

    _remoteStream = null;
    _peerConnection = null;
  }
}
