import asyncio
import fractions
import json
import time
import uuid

import numpy as np
from aiohttp import web
from aiohttp_middlewares import cors_middleware
from aiortc import (
	MediaStreamTrack,
	RTCPeerConnection,
	RTCSessionDescription,
)
from av import VideoFrame

from image_process import image_process

pcs = set()  # Set of active PeerConnections
project_data = None  # Placeholder for the project data object


class ServerVideoTrack(MediaStreamTrack):
	"""
	Server video track for streaming frames to clients
	"""

	kind = "video"

	def __init__(self, timeline):
		super().__init__()  # Initialize parent class
		self._queue = asyncio.Queue(maxsize=1)  # Queue to hold frames (only the latest 1 frame)
		self.timeline = timeline

	async def request_frame(self, frame_index):
		now = time.time()

		# Get frame data
		result_pixels, spec = image_process(self.timeline, frame_index)

		# Convert form float32 RGBA to uint8 BGR
		result_pixels = (np.clip(result_pixels, 0, 1) * 255).astype(np.uint8)
		result_pixels = result_pixels[:, :, :3]  # Drop the alpha channel
		result_pixels = result_pixels[:, :, ::-1]  # Convert RGBA to BGR

		# Create a video frame from the numpy array
		frame = VideoFrame.from_ndarray(result_pixels, format="bgr24")
		frame.pts = int(now * 1000)
		frame.time_base = fractions.Fraction(1, 1000)

		# Update the frame index for the next request
		print(f"Frame {frame_index} requested at {now:.2f}s")
		if self._queue.full():
			await self._queue.get()
		await self._queue.put(frame)

	async def recv(self):
		frame = await self._queue.get()
		print(f"Sending frame {frame.pts}")
		return frame


async def offer(request):
	"""
	Handle WebRTC offer from client and return an answer
	"""
	try:
		params = await request.json()
		offer = RTCSessionDescription(sdp=params["sdp"], type=params["type"])

		# Create a new peer connection
		pc = RTCPeerConnection()
		pc_id = f"PeerConnection({uuid.uuid4()})"
		pcs.add(pc)
		print(f"{pc_id} created for {request.remote}")

		# Process the offer and set remote description
		await pc.setRemoteDescription(offer)

		@pc.on("connectionstatechange")
		async def on_connectionstatechange():
			print(f"{pc_id} Connection state is {pc.connectionState}")
			if pc.connectionState == "failed" or pc.connectionState == "closed":
				await pc.close()
				pcs.discard(pc)

		@pc.on("iceconnectionstatechange")
		async def on_iceconnectionstatechange():
			print(f"{pc_id} ICE Connection state is {pc.iceConnectionState}")

		@pc.on("icegatheringstatechange")
		async def on_icegatheringstatechange():
			print(f"{pc_id} ICE Gathering state is {pc.iceGatheringState}")

		# Add the video track from server to the peer connection
		timeline = project_data.get("timeline", {})
		video_track = ServerVideoTrack(timeline=timeline)
		pc.addTrack(video_track)

		@pc.on("datachannel")
		async def on_datachannel(channel):
			@channel.on("message")
			def on_message(message):
				if isinstance(message, str):
					print(f"Message from {pc_id}: {message}")
					try:
						frame_number = int(message)
						asyncio.create_task(video_track.request_frame(frame_number))
					except ValueError:
						print(f"Invalid frame index: {message}")

		# Create an answer
		answer = await pc.createAnswer()

		# Set local description
		await pc.setLocalDescription(answer)

		# Return the answer with the gathered ICE candidates
		return web.Response(
			content_type="application/json",
			text=json.dumps({"sdp": pc.localDescription.sdp, "type": pc.localDescription.type}),
		)

	except Exception as e:
		print(f"Error handling offer: {e}")
		return web.Response(status=500, text=str(e))


async def on_shutdown(app):
	"""Close all peer connections when server shuts down"""
	print("Shutting down WebRTC connections")
	coros = [pc.close() for pc in pcs]
	await web.asyncio.gather(*coros)
	pcs.clear()


def main():
	# ---------
	# For project
	# ---------

	global project_data

	project_filename = "assets/project.json"

	# Load the project file
	try:
		with open(project_filename, "r") as f:
			project_data = json.load(f)
	except Exception as e:
		print(f"Error loading project file: {e}")
		return

	# -----------
	# For WebRTC
	# -----------
	app = web.Application(
		middlewares=[
			cors_middleware(
				allow_all=True,
				allow_headers="*",
				allow_methods="*",
			)
		]
	)
	app.router.add_post("/offer", offer)

	# Register shutdown handler
	app.on_shutdown.append(on_shutdown)

	# Run the server
	print("Starting WebRTC server at http://localhost:41395")
	web.run_app(app=app, host="localhost", port=41395)


if __name__ == "__main__":
	main()
