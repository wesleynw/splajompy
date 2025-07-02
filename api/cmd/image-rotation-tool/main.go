package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"image"
	"image/jpeg"
	"io"
	"log"
	"os"
	"os/exec"
	"strings"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/disintegration/imaging"
	"github.com/joho/godotenv"
	"github.com/rwcarlsen/goexif/exif"
	"splajompy.com/api/v2/internal/service"
)

type RotationTool struct {
	s3Client *s3.Client
	bucket   string
}

func main() {
	fmt.Println("🔄 Batch Image Rotation Tool")
	fmt.Println("============================")

	// Load .env file
	err := godotenv.Load()
	if err != nil {
		log.Printf("Warning: Could not load .env file: %v", err)
		fmt.Println("⚠️  No .env file found, using system environment variables")
	} else {
		fmt.Println("✅ Loaded .env file")
	}

	// Disable AWS SDK logging warnings
	log.SetOutput(io.Discard)

	// Initialize S3 client
	s3Client, err := service.NewS3Client()
	if err != nil {
		log.Fatalf("Failed to create S3 client: %v", err)
	}

	tool := &RotationTool{
		s3Client: s3Client,
		bucket:   "splajompy-bucket",
	}

	scanner := bufio.NewScanner(os.Stdin)

	// Test S3 connection first
	fmt.Println("🔗 Testing DigitalOcean Spaces connection...")
	err = tool.testConnection()
	if err != nil {
		log.Fatalf("Failed to connect to DigitalOcean Spaces: %v", err)
	}

	// Get all images from S3
	fmt.Println("📋 Loading all images from DigitalOcean Spaces...")
	images, err := tool.getAllImages()
	if err != nil {
		log.Fatalf("Failed to load images: %v", err)
	}

	fmt.Printf("Found %d images. Starting batch rotation...\n\n", len(images))
	
	if len(images) == 0 {
		fmt.Println("ℹ️  No images found. This could mean:")
		fmt.Println("   - The bucket is empty")
		fmt.Println("   - No images in the posts/ folder")
		fmt.Println("   - AWS credentials are incorrect")
		fmt.Println("   - Network/connection issues")
		return
	}

	// Process each image
	for i, imageKey := range images {
		fmt.Printf("📸 Image %d/%d: %s\n", i+1, len(images), imageKey)
		
		// Download and display image
		imageData, err := tool.downloadS3Image(imageKey)
		if err != nil {
			fmt.Printf("❌ Error downloading: %v\n", err)
			continue
		}

		// Show image inline
		tool.displayImageInline(imageData, imageKey)
		
		// Get user input for rotation
		rotation := tool.getRotationChoice(scanner)
		
		if rotation == "skip" {
			fmt.Println("⏭️  Skipped")
			continue
		}

		// Apply rotation and upload
		err = tool.applyRotationAndUpload(imageData, imageKey, rotation)
		if err != nil {
			fmt.Printf("❌ Error processing: %v\n", err)
		} else {
			fmt.Printf("✅ Updated %s\n", imageKey)
		}
		
		fmt.Println(strings.Repeat("-", 60))
	}

	fmt.Println("🎉 Batch rotation complete!")
}

func (t *RotationTool) testConnection() error {
	// Try to list just a few objects to test connection
	result, err := t.s3Client.ListObjectsV2(context.TODO(), &s3.ListObjectsV2Input{
		Bucket:  &t.bucket,
		MaxKeys: intPtr(1),
	})
	if err != nil {
		return fmt.Errorf("connection test failed: %w", err)
	}
	
	fmt.Printf("✅ Connected to bucket '%s', found %d objects\n", t.bucket, len(result.Contents))
	return nil
}

func (t *RotationTool) getAllImages() ([]string, error) {
	imageSet := make(map[string]bool) // Use map to deduplicate
	
	// Search multiple prefixes where images might be stored, including root directories
	prefixes := []string{"", "/", "posts/", "production/posts/"}
	
	for _, prefix := range prefixes {
		displayPrefix := prefix
		if displayPrefix == "" {
			displayPrefix = "[root]"
		}
		fmt.Printf("🔍 Searching bucket: %s with prefix: %s\n", t.bucket, displayPrefix)
		
		images, err := t.searchWithPrefix(prefix)
		if err != nil {
			return nil, fmt.Errorf("failed to search prefix %s: %w", prefix, err)
		}
		
		// Add images to set to avoid duplicates
		for _, image := range images {
			imageSet[image] = true
		}
		fmt.Printf("📊 Found %d images with prefix %s\n", len(images), displayPrefix)
	}

	// Convert set back to slice
	var allImages []string
	for image := range imageSet {
		allImages = append(allImages, image)
	}

	fmt.Printf("📋 Total unique images found: %d\n", len(allImages))
	return allImages, nil
}

func (t *RotationTool) searchWithPrefix(prefix string) ([]string, error) {
	var images []string
	var continuationToken *string

	for {
		input := &s3.ListObjectsV2Input{
			Bucket: &t.bucket,
			Prefix: stringPtr(prefix),
		}

		if continuationToken != nil {
			input.ContinuationToken = continuationToken
		}

		result, err := t.s3Client.ListObjectsV2(context.TODO(), input)
		if err != nil {
			return nil, fmt.Errorf("failed to list objects: %w", err)
		}

		batchImages := 0
		for _, obj := range result.Contents {
			if obj.Key != nil {
				if t.isImageFile(*obj.Key) {
					images = append(images, *obj.Key)
					batchImages++
					fmt.Printf("   ✅ %s\n", *obj.Key)
				}
			}
		}
		
		if len(result.Contents) > 0 {
			fmt.Printf("📄 Found %d objects, %d images in this batch\n", len(result.Contents), batchImages)
		}

		if result.IsTruncated == nil || !*result.IsTruncated {
			break
		}

		continuationToken = result.NextContinuationToken
	}

	return images, nil
}

func (t *RotationTool) isImageFile(key string) bool {
	key = strings.ToLower(key)
	return strings.HasSuffix(key, ".jpg") ||
		strings.HasSuffix(key, ".jpeg") ||
		strings.HasSuffix(key, ".png") ||
		strings.HasSuffix(key, ".gif") ||
		strings.HasSuffix(key, ".webp")
}

func (t *RotationTool) displayImageInline(imageData []byte, imageName string) {
	// Get EXIF orientation and image info
	orientation := t.getExifOrientation(imageData)
	img, format, err := image.Decode(bytes.NewReader(imageData))
	if err != nil {
		fmt.Printf("❌ Error decoding image: %v\n", err)
		return
	}

	fmt.Printf("📐 EXIF: %d | 🖼️  %dx%d %s\n", orientation, img.Bounds().Dx(), img.Bounds().Dy(), format)

	// Always save a preview file automatically
	t.autoSavePreview(img, imageName)

	// Try terminal image display
	displayed := false
	
	if t.displayWithITerm2(img) {
		displayed = true
	} else if t.displayWithKitty(img) {
		displayed = true
	} else if t.displayWithSixel(img) {
		displayed = true
	}
	
	if !displayed {
		fmt.Println("💡 Terminal doesn't support inline images.")
		fmt.Println("📁 Auto-saved preview as 'current_preview.jpg' - open it to see the image!")
		
		// Try to auto-open the image
		t.tryAutoOpenImage()
	}
}

func (t *RotationTool) autoSavePreview(img image.Image, imageName string) {
	// Create a preview
	preview := imaging.Resize(img, 800, 0, imaging.Lanczos)
	
	// Save as preview.jpg
	file, err := os.Create("current_preview.jpg")
	if err != nil {
		return
	}
	defer file.Close()

	jpeg.Encode(file, preview, &jpeg.Options{Quality: 90})
}

func (t *RotationTool) tryAutoOpenImage() {
	// Detect OS and try to open the image
	var cmdName string
	var args []string
	
	switch {
	case strings.Contains(strings.ToLower(os.Getenv("HOME")), "/users/"):
		// macOS
		cmdName = "open"
		args = []string{"current_preview.jpg"}
	case os.Getenv("DISPLAY") != "" || os.Getenv("WAYLAND_DISPLAY") != "":
		// Linux
		cmdName = "xdg-open"
		args = []string{"current_preview.jpg"}
	default:
		fmt.Println("💡 Run: open current_preview.jpg (or your image viewer)")
		return
	}
	
	// Try to execute the command
	cmd := exec.Command(cmdName, args...)
	err := cmd.Start()
	
	if err == nil {
		fmt.Printf("🖼️  Opened image in default viewer\n")
		// Don't wait for the process to finish
		go cmd.Wait()
	} else {
		fmt.Printf("💡 Run: %s %s\n", cmdName, strings.Join(args, " "))
	}
}

func (t *RotationTool) displayWithITerm2(img image.Image) bool {
	// Check if we're in iTerm2
	if os.Getenv("TERM_PROGRAM") != "iTerm.app" {
		return false
	}
	
	// Create thumbnail for terminal display
	thumbnail := imaging.Resize(img, 400, 0, imaging.Lanczos)
	
	// Convert to base64 and display using iTerm2 inline images
	var buf bytes.Buffer
	jpeg.Encode(&buf, thumbnail, &jpeg.Options{Quality: 80})
	encoded := base64.StdEncoding.EncodeToString(buf.Bytes())
	
	// iTerm2 inline image protocol
	fmt.Printf("\033]1337;File=inline=1;width=30;height=20:%s\a\n", encoded)
	return true
}

func (t *RotationTool) displayWithKitty(img image.Image) bool {
	// Check if we're in Kitty terminal
	if os.Getenv("TERM") != "xterm-kitty" {
		return false
	}
	
	// Create thumbnail
	thumbnail := imaging.Resize(img, 400, 0, imaging.Lanczos)
	
	// Convert to base64
	var buf bytes.Buffer
	jpeg.Encode(&buf, thumbnail, &jpeg.Options{Quality: 80})
	encoded := base64.StdEncoding.EncodeToString(buf.Bytes())
	
	// Kitty graphics protocol
	fmt.Printf("\033_Gf=100,t=d,m=1;%s\033\\\n", encoded)
	return true
}

func (t *RotationTool) displayWithSixel(img image.Image) bool {
	// Check if terminal supports sixel (some terminals like mlterm, xterm with sixel)
	if os.Getenv("TERM") == "" {
		return false
	}
	
	// For now, skip sixel implementation as it's complex
	return false
}

func (t *RotationTool) getRotationChoice(scanner *bufio.Scanner) string {
	fmt.Println("\n🔄 Rotation needed?")
	fmt.Println("0=None  1=90°CW  2=180°  3=90°CCW  4=FlipH  5=FlipV  6=EXIF  s=Skip")
	fmt.Print("Choice: ")
	
	if !scanner.Scan() {
		return "skip"
	}
	
	choice := strings.TrimSpace(scanner.Text())
	switch choice {
	case "0", "1", "2", "3", "4", "5", "6":
		return choice
	case "s", "S", "skip":
		return "skip"
	default:
		fmt.Println("Invalid choice, skipping...")
		return "skip"
	}
}

func (t *RotationTool) savePreviewFile(imageData []byte, imageName string) {
	// Decode image
	img, _, err := image.Decode(bytes.NewReader(imageData))
	if err != nil {
		fmt.Printf("❌ Error decoding image: %v\n", err)
		return
	}

	// Create a larger preview
	preview := imaging.Resize(img, 800, 0, imaging.Lanczos)
	
	// Save as preview.jpg
	file, err := os.Create("current_preview.jpg")
	if err != nil {
		fmt.Printf("❌ Error creating preview file: %v\n", err)
		return
	}
	defer file.Close()

	err = jpeg.Encode(file, preview, &jpeg.Options{Quality: 90})
	if err != nil {
		fmt.Printf("❌ Error saving preview: %v\n", err)
		return
	}

	fmt.Println("✅ Saved preview as 'current_preview.jpg' - open it in your image viewer!")
}

func (t *RotationTool) applyRotationAndUpload(imageData []byte, key string, rotation string) error {
	// Decode image
	img, _, err := image.Decode(bytes.NewReader(imageData))
	if err != nil {
		return fmt.Errorf("failed to decode image: %w", err)
	}

	// Apply rotation
	var rotatedImg image.Image
	switch rotation {
	case "0":
		rotatedImg = img
	case "1":
		rotatedImg = imaging.Rotate90(img)
	case "2":
		rotatedImg = imaging.Rotate180(img)
	case "3":
		rotatedImg = imaging.Rotate270(img)
	case "4":
		rotatedImg = imaging.FlipH(img)
	case "5":
		rotatedImg = imaging.FlipV(img)
	case "6":
		orientation := t.getExifOrientation(imageData)
		rotatedImg = t.applyOrientation(img, orientation)
	default:
		return fmt.Errorf("invalid rotation choice: %s", rotation)
	}

	// Encode and upload
	var buf bytes.Buffer
	err = jpeg.Encode(&buf, rotatedImg, &jpeg.Options{Quality: 100})
	if err != nil {
		return fmt.Errorf("failed to encode image: %w", err)
	}

	_, err = t.s3Client.PutObject(context.TODO(), &s3.PutObjectInput{
		Bucket:      &t.bucket,
		Key:         &key,
		Body:        bytes.NewReader(buf.Bytes()),
		ContentType: stringPtr("image/jpeg"),
		ACL:         types.ObjectCannedACLPublicRead,
	})

	return err
}


func (t *RotationTool) downloadS3Image(key string) ([]byte, error) {
	result, err := t.s3Client.GetObject(context.TODO(), &s3.GetObjectInput{
		Bucket: &t.bucket,
		Key:    &key,
	})
	if err != nil {
		return nil, err
	}
	defer result.Body.Close()

	return io.ReadAll(result.Body)
}


func (t *RotationTool) getExifOrientation(imageData []byte) int {
	x, err := exif.Decode(bytes.NewReader(imageData))
	if err != nil {
		return 1 // Default orientation
	}

	tag, err := x.Get(exif.Orientation)
	if err != nil {
		return 1
	}

	orientation, err := tag.Int(0)
	if err != nil {
		return 1
	}

	return orientation
}

func (t *RotationTool) applyOrientation(img image.Image, orientation int) image.Image {
	switch orientation {
	case 1:
		return img
	case 2:
		return imaging.FlipH(img)
	case 3:
		return imaging.Rotate180(img)
	case 4:
		return imaging.FlipV(img)
	case 5:
		return imaging.Rotate90(imaging.FlipH(img))
	case 6:
		return imaging.Rotate270(img)
	case 7:
		return imaging.Rotate270(imaging.FlipH(img))
	case 8:
		return imaging.Rotate90(img)
	default:
		return img
	}
}

func stringPtr(s string) *string {
	return &s
}

func intPtr(i int32) *int32 {
	return &i
}