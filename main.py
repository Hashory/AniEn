import OpenImageIO


def main():
	input_filename = "assets/image.jpg"
	in_img = OpenImageIO.ImageInput.open(input_filename)
	if not in_img:
		print(f"Error: Could not open input image: {input_filename}")
		exit()

	spec = in_img.spec()
	width = spec.width
	height = spec.height
	nchannels = spec.nchannels
	pixel_data = in_img.read_image()

	# Print image information
	print(f"Image loaded: {input_filename}")
	print(f"Width: {width}, Height: {height}, Channels: {nchannels}")
	print(f"Pixel data: {pixel_data}")
	print(f"Pixel data shape: {pixel_data.shape}")

	# Convert color a bit
	output_pixel_data = pixel_data

	# Modify spec for output
	new_spec = OpenImageIO.ImageSpec(width, height, nchannels, "uint8")

	# Write the output image using OpenImageIO
	output_filename = "outputs/image.jpg"
	out_img = OpenImageIO.ImageOutput.create(output_filename)
	out_img.open(output_filename, new_spec)
	out_img.write_image(output_pixel_data)

	# Close the image files
	in_img.close()
	out_img.close()


if __name__ == "__main__":
	main()
