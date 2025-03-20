import json
import os

import opengl_image_process_util as oip
import OpenImageIO


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


def main():
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
