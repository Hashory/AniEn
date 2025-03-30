import asyncio
import fractions
import json
import os
import time
import uuid
from typing import Tuple

import numpy as np
import OpenImageIO
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


VIDEO_CLOCK_RATE = 90000
VIDEO_PTIME = 1 / 3  # 3fps
VIDEO_TIME_BASE = fractions.Fraction(1, VIDEO_CLOCK_RATE)


class ServerVideoTrack(MediaStreamTrack):
	"""
	Server video track for streaming frames to clients
	"""

	kind = "video"

	_start: float
	_timestamp: int

	def __init__(self, timeline):
		super().__init__()  # Initialize parent class
		self.timeline = timeline
		self.frame_index = 22  # Default frame index

	async def next_timestamp(self) -> Tuple[int, fractions.Fraction]:
		if self.readyState != "live":
			raise Exception("Track is not live")

		if hasattr(self, "_timestamp"):
			self._timestamp += int(VIDEO_PTIME * VIDEO_CLOCK_RATE)
			wait = self._start + (self._timestamp / VIDEO_CLOCK_RATE) - time.time()
			await asyncio.sleep(wait)
		else:
			self._start = time.time()
			self._timestamp = 0
		return self._timestamp, VIDEO_TIME_BASE

	async def recv(self):
		# Get next timestamp
		pts, time_base = await self.next_timestamp()

		try:
			result_pixels, spec = image_process(self.timeline, self.frame_index)

			# Convert form float32 RGBA to uint8 BGR
			result_pixels = (np.clip(result_pixels, 0, 1) * 255).astype(np.uint8)
			result_pixels = result_pixels[:, :, :3]  # Drop the alpha channel
			result_pixels = result_pixels[:, :, ::-1]  # Convert RGBA to BGR

			# Create a video frame from the numpy array
			frame = VideoFrame.from_ndarray(result_pixels, format="bgr24")
			frame.pts = pts
			frame.time_base = time_base
			return frame
		except Exception as e:
			print(f"Error generating video frame: {e}")
			# Return a black frame in case of error
			img = np.zeros((480, 640, 3), dtype=np.uint8)
			frame = VideoFrame.from_ndarray(img, format="bgr24")
			frame.pts = pts
			frame.time_base = time_base
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
						video_track.frame_index = frame_number
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

	input_frame_number = 22
	project_filename = "assets/project.json"
	output_filename = f"outputs/frame_{input_frame_number:04d}.png"

	# Create outputs directory if it doesn't exist
	os.makedirs("outputs", exist_ok=True)

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

	# ---------------------
	# For image processing
	# ---------------------

	# Get the timeline from the project
	timeline = project_data.get("timeline", {})

	# Process the frame
	result_pixels, spec = image_process(timeline, input_frame_number)

	if result_pixels is None or spec is None:
		print(f"Failed to process frame {input_frame_number}")
		return

	# Write the output image
	width = spec.width
	height = spec.height
	nchannels = spec.nchannels

	# Modify spec for output
	new_spec = OpenImageIO.ImageSpec(width, height, nchannels, "uint8")

	# Write the output image using OpenImageIO
	out_img = OpenImageIO.ImageOutput.create(output_filename)
	out_img.open(output_filename, new_spec)
	out_img.write_image(result_pixels)
	out_img.close()

	print(f"Rendered frame {input_frame_number} to {output_filename}")


if __name__ == "__main__":
	main()
