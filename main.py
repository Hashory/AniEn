import json
import os
import uuid

import numpy as np
import opengl_image_process_util as oip
import OpenImageIO
from aiohttp import web
from aiohttp_middlewares import cors_middleware
from aiortc import (
	RTCPeerConnection,
	RTCSessionDescription,
	VideoStreamTrack,
)
from av import VideoFrame


def load_image(filename):
	"""Load an image and return its pixel data and specifications"""
	in_img = OpenImageIO.ImageInput.open(filename)
	if not in_img:
		print(f"Error: Could not open input image: {filename}")
		return None, None

	spec = in_img.spec()
	width = spec.width
	height = spec.height
	nchannels = spec.nchannels
	pixel_data = in_img.read_image()
	in_img.close()

	return pixel_data, spec


def get_visible_clips_at_frame(timeline, frame_number, asset_folder="assets"):
	"""Recursively search timeline to find all clips visible at the given frame"""
	visible_clips = []

	if timeline.get("role") == "folder":
		tracks = timeline.get("tracks", [])
		start_offset = timeline.get("start", 0)

		for track in tracks:
			clips = track.get("clips", [])
			for clip in clips:
				if clip.get("role") == "folder":
					# Recursively search folders
					nested_start = clip.get("start", 0) + start_offset
					nested_timeline = {"role": "folder", "start": nested_start, "tracks": clip.get("tracks", [])}
					visible_clips.extend(get_visible_clips_at_frame(nested_timeline, frame_number, asset_folder))
				elif clip.get("role") == "clip":
					# Check if this clip is visible at the current frame
					clip_start = clip.get("start", 0) + start_offset
					clip_length = clip.get("length", 0)
					clip_end = clip_start + clip_length

					if clip_start <= frame_number < clip_end:
						source = clip.get("source", "")
						if source:
							visible_clips.append(os.path.join(asset_folder, source))

	return visible_clips


def image_process(timeline, frame_number, asset_folder="assets"):
	"""Process the timeline and return the rendered frame image for the specified frame number"""
	# Find all clips visible at the specified frame
	visible_clip_paths = get_visible_clips_at_frame(timeline, frame_number, asset_folder)

	if not visible_clip_paths:
		print(f"No clips found for frame {frame_number}")
		return None, None

	print(f"Found {len(visible_clip_paths)} visible clips at frame {frame_number}:")
	for path in visible_clip_paths:
		print(f"  - {path}")

	# Load the first image to get dimensions
	first_image_path = visible_clip_paths[0]
	result_pixels, spec = load_image(first_image_path)

	if result_pixels is None:
		print(f"Failed to load first image: {first_image_path}")
		return None, None

	# Blend all subsequent images
	for image_path in visible_clip_paths[1:]:
		image_pixels, _ = load_image(image_path)
		if image_pixels is not None:
			# Blend the current result with the new image
			result_pixels = oip.overlay_images(result_pixels, image_pixels)
		else:
			print(f"Failed to load image: {image_path}")

	return result_pixels, spec


pcs = set()  # Set of active PeerConnections


class ServerVideoTrack(VideoStreamTrack):
	"""
	Server video track for streaming frames to clients
	"""

	def __init__(self):
		super().__init__()  # Initialize parent class
		self.counter = 0  # Frame counter

	async def recv(self):
		# Get next timestamp
		pts, time_base = await self.next_timestamp()

		try:
			# Generate a color frame - in a real app, this could pull from your rendering system
			img = np.zeros((480, 640, 3), dtype=np.uint8)
			color = ((self.counter * 5) % 255, (self.counter * 3) % 255, (self.counter * 7) % 255)
			img = np.full((480, 640, 3), color, dtype=np.uint8)
			self.counter += 1

			# Create a video frame from the numpy array
			frame = VideoFrame.from_ndarray(img, format="bgr24")
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
		video_track = ServerVideoTrack()
		pc.addTrack(video_track)

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
