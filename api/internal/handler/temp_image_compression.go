package handler

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/jpeg"
	"io"
	"log"
	"net/http"
	"strings"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/disintegration/imaging"
	"github.com/rwcarlsen/goexif/exif"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/service"
	"splajompy.com/api/v2/internal/utilities"
)

type CompressAllImagesResponse struct {
	Message           string   `json:"message"`
	ProcessedImages   int      `json:"processedImages"`
	CompressedImages  int      `json:"compressedImages"`
	SkippedImages     int      `json:"skippedImages"`
	Errors            []string `json:"errors,omitempty"`
}

func (h *Handler) CompressAllImages(w http.ResponseWriter, r *http.Request) {
	log.Printf("Starting image compression process...")

	// Initialize S3 client and bucket repository
	s3Client, err := service.NewS3Client()
	if err != nil {
		log.Printf("Error creating S3 client: %v", err)
		utilities.HandleError(w, http.StatusInternalServerError, "Failed to initialize S3 client")
		return
	}

	bucketRepo := repositories.NewS3BucketRepository(s3Client)
	bucketName := "splajompy-bucket"

	// List all objects in the bucket
	objects, err := h.listAllS3Objects(s3Client, bucketName)
	if err != nil {
		log.Printf("Error listing S3 objects: %v", err)
		utilities.HandleError(w, http.StatusInternalServerError, "Failed to list S3 objects")
		return
	}

	response := CompressAllImagesResponse{
		ProcessedImages:  0,
		CompressedImages: 0,
		SkippedImages:    0,
		Errors:           []string{},
	}

	// Process each image
	for _, obj := range objects {
		if obj.Key == nil {
			continue
		}

		key := *obj.Key
		log.Printf("Processing: %s", key)

		// Check if it's an image file
		if !h.isImageFile(key) {
			response.SkippedImages++
			continue
		}

		response.ProcessedImages++

		// Download, compress, and reupload the image
		err := h.compressAndReuploadImage(s3Client, bucketRepo, bucketName, key)
		if err != nil {
			log.Printf("Error processing %s: %v", key, err)
			response.Errors = append(response.Errors, fmt.Sprintf("%s: %v", key, err))
		} else {
			response.CompressedImages++
			log.Printf("Successfully compressed: %s", key)
		}
	}

	response.Message = fmt.Sprintf("Image compression completed. Processed %d images, compressed %d, skipped %d",
		response.ProcessedImages, response.CompressedImages, response.SkippedImages)

	log.Printf("Image compression process completed: %+v", response)
	utilities.HandleSuccess(w, response)
}

func (h *Handler) listAllS3Objects(s3Client *s3.Client, bucketName string) ([]types.Object, error) {
	var allObjects []types.Object
	var continuationToken *string

	for {
		input := &s3.ListObjectsV2Input{
			Bucket: &bucketName,
		}

		if continuationToken != nil {
			input.ContinuationToken = continuationToken
		}

		result, err := s3Client.ListObjectsV2(context.TODO(), input)
		if err != nil {
			return nil, fmt.Errorf("failed to list objects: %w", err)
		}

		allObjects = append(allObjects, result.Contents...)

		if result.IsTruncated == nil || !*result.IsTruncated {
			break
		}

		continuationToken = result.NextContinuationToken
	}

	return allObjects, nil
}

func (h *Handler) isImageFile(key string) bool {
	key = strings.ToLower(key)
	return strings.HasSuffix(key, ".jpg") ||
		strings.HasSuffix(key, ".jpeg") ||
		strings.HasSuffix(key, ".png") ||
		strings.HasSuffix(key, ".gif") ||
		strings.HasSuffix(key, ".webp")
}

func (h *Handler) compressAndReuploadImage(s3Client *s3.Client, bucketRepo *repositories.S3BucketRepository, bucketName, key string) error {
	// Download the image
	getObjectInput := &s3.GetObjectInput{
		Bucket: &bucketName,
		Key:    &key,
	}

	result, err := s3Client.GetObject(context.TODO(), getObjectInput)
	if err != nil {
		return fmt.Errorf("failed to download image: %w", err)
	}
	defer result.Body.Close()

	// Read the image data into memory so we can use it for both EXIF and image decoding
	imageData, err := io.ReadAll(result.Body)
	if err != nil {
		return fmt.Errorf("failed to read image data: %w", err)
	}

	// Check EXIF orientation if it's a JPEG
	orientation := 1 // Default orientation (no rotation)
	if strings.ToLower(strings.Split(key, ".")[len(strings.Split(key, "."))-1]) == "jpg" || 
	   strings.ToLower(strings.Split(key, ".")[len(strings.Split(key, "."))-1]) == "jpeg" {
		orientation = h.getExifOrientation(imageData)
	}

	// Decode the image
	img, format, err := image.Decode(bytes.NewReader(imageData))
	if err != nil {
		return fmt.Errorf("failed to decode image: %w", err)
	}

	// Apply orientation correction based on EXIF data
	img = h.applyOrientation(img, orientation)

	// Get original dimensions
	bounds := img.Bounds()
	originalWidth := bounds.Dx()
	originalHeight := bounds.Dy()

	// Check if resizing is needed
	if originalWidth <= 1000 {
		// Image doesn't need compression, but reupload with correct ACL and orientation
		log.Printf("Image %s already smaller than 1000px width (%dpx), reuploading with correct ACL and orientation", key, originalWidth)
		
		// Encode the orientation-corrected image
		var buf bytes.Buffer
		var encodeErr error
		
		switch strings.ToLower(format) {
		case "jpeg", "jpg":
			encodeErr = jpeg.Encode(&buf, img, &jpeg.Options{Quality: 100})
		case "png":
			// Convert to JPEG for consistency
			encodeErr = jpeg.Encode(&buf, img, &jpeg.Options{Quality: 100})
		default:
			encodeErr = jpeg.Encode(&buf, img, &jpeg.Options{Quality: 100})
		}
		
		if encodeErr != nil {
			return fmt.Errorf("failed to encode image for ACL update: %w", encodeErr)
		}
		
		// Upload with correct ACL
		putObjectInput := &s3.PutObjectInput{
			Bucket:      &bucketName,
			Key:         &key,
			Body:        bytes.NewReader(buf.Bytes()),
			ContentType: stringPtr("image/jpeg"),
			ACL:         types.ObjectCannedACLPublicRead,
		}
		
		_, err = s3Client.PutObject(context.TODO(), putObjectInput)
		if err != nil {
			return fmt.Errorf("failed to reupload image with correct ACL: %w", err)
		}
		
		log.Printf("Successfully reuploaded %s with public-read ACL", key)
		return nil
	}

	// Resize to max width of 1000px while maintaining aspect ratio
	resizedImg := imaging.Resize(img, 1000, 0, imaging.Lanczos)

	// Encode back to JPEG with compression
	var buf bytes.Buffer
	var encodeErr error

	switch strings.ToLower(format) {
	case "jpeg", "jpg":
		encodeErr = jpeg.Encode(&buf, resizedImg, &jpeg.Options{Quality: 100})
	case "png":
		// Convert PNG to JPEG for better compression
		encodeErr = jpeg.Encode(&buf, resizedImg, &jpeg.Options{Quality: 100})
	default:
		// For other formats, convert to JPEG
		encodeErr = jpeg.Encode(&buf, resizedImg, &jpeg.Options{Quality: 100})
	}

	if encodeErr != nil {
		return fmt.Errorf("failed to encode compressed image: %w", encodeErr)
	}

	// Upload the compressed image back to S3
	putObjectInput := &s3.PutObjectInput{
		Bucket:      &bucketName,
		Key:         &key,
		Body:        bytes.NewReader(buf.Bytes()),
		ContentType: stringPtr("image/jpeg"),
		ACL:         types.ObjectCannedACLPublicRead,
	}

	_, err = s3Client.PutObject(context.TODO(), putObjectInput)
	if err != nil {
		return fmt.Errorf("failed to upload compressed image: %w", err)
	}

	var sizeReduction float64
	originalSize := len(imageData)
	sizeReduction = (1.0 - float64(len(buf.Bytes()))/float64(originalSize)) * 100
	
	log.Printf("Compressed %s: %dx%d -> %dx%d, size reduced by %.1f%%",
		key,
		originalWidth, originalHeight,
		resizedImg.Bounds().Dx(), resizedImg.Bounds().Dy(),
		sizeReduction)

	return nil
}

func stringPtr(s string) *string {
	return &s
}

func (h *Handler) getExifOrientation(imageData []byte) int {
	// Decode EXIF data
	x, err := exif.Decode(bytes.NewReader(imageData))
	if err != nil {
		log.Printf("No EXIF data found or error reading EXIF: %v", err)
		return 1 // Default orientation
	}

	// Get orientation tag
	tag, err := x.Get(exif.Orientation)
	if err != nil {
		log.Printf("No orientation tag found: %v", err)
		return 1
	}

	orientation, err := tag.Int(0)
	if err != nil {
		log.Printf("Error reading orientation value: %v", err)
		return 1
	}

	log.Printf("Found EXIF orientation: %d", orientation)
	return orientation
}

func (h *Handler) applyOrientation(img image.Image, orientation int) image.Image {
	switch orientation {
	case 1:
		// Normal - no rotation needed
		return img
	case 2:
		// Flip horizontal
		return imaging.FlipH(img)
	case 3:
		// Rotate 180
		return imaging.Rotate180(img)
	case 4:
		// Flip vertical
		return imaging.FlipV(img)
	case 5:
		// Flip horizontal + rotate 90 CW
		return imaging.Rotate90(imaging.FlipH(img))
	case 6:
		// Rotate 90 CCW (camera was rotated 90 CW)
		return imaging.Rotate270(img)
	case 7:
		// Flip horizontal + rotate 90 CCW
		return imaging.Rotate270(imaging.FlipH(img))
	case 8:
		// Rotate 90 CW (camera was rotated 90 CCW)
		return imaging.Rotate90(img)
	default:
		log.Printf("Unknown orientation value: %d", orientation)
		return img
	}
}