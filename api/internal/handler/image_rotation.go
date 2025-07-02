package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"image"
	"image/jpeg"
	"log"
	"net/http"
	"net/url"
	"sort"
	"strings"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/disintegration/imaging"
	"github.com/rwcarlsen/goexif/exif"
	"splajompy.com/api/v2/internal/service"
)

type ImageRotationHandler struct {
	s3Client *s3.Client
	bucket   string
}

type ImageInfo struct {
	Key         string `json:"key"`
	URL         string `json:"url"`
	Orientation int    `json:"orientation"`
	Width       int    `json:"width"`
	Height      int    `json:"height"`
}

type RotationRequest struct {
	Rotation string `json:"rotation"`
}

func NewImageRotationHandler() (*ImageRotationHandler, error) {
	s3Client, err := service.NewS3Client()
	if err != nil {
		return nil, fmt.Errorf("failed to create S3 client: %w", err)
	}

	return &ImageRotationHandler{
		s3Client: s3Client,
		bucket:   "splajompy-bucket",
	}, nil
}

func (h *Handler) ListImages(w http.ResponseWriter, r *http.Request) {
	rotationHandler, err := NewImageRotationHandler()
	if err != nil {
		http.Error(w, "Failed to initialize image handler", http.StatusInternalServerError)
		return
	}

	images, err := rotationHandler.getAllImages()
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to list images: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(images)
}

func (h *Handler) GetImageInfo(w http.ResponseWriter, r *http.Request) {
	encodedKey := r.PathValue("key")
	if encodedKey == "" {
		http.Error(w, "Missing image key", http.StatusBadRequest)
		return
	}

	key, err := url.QueryUnescape(encodedKey)
	if err != nil {
		http.Error(w, "Invalid image key", http.StatusBadRequest)
		return
	}

	rotationHandler, err := NewImageRotationHandler()
	if err != nil {
		http.Error(w, "Failed to initialize image handler", http.StatusInternalServerError)
		return
	}

	imageData, err := rotationHandler.downloadS3Image(key)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to download image: %v", err), http.StatusInternalServerError)
		return
	}

	orientation := rotationHandler.getExifOrientation(imageData)
	img, _, err := image.Decode(bytes.NewReader(imageData))
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to decode image: %v", err), http.StatusInternalServerError)
		return
	}

	imageInfo := ImageInfo{
		Key:         key,
		URL:         fmt.Sprintf("/api/images/%s/view", url.QueryEscape(key)), // Use our proxy endpoint to bypass CDN
		Orientation: orientation,
		Width:       img.Bounds().Dx(),
		Height:      img.Bounds().Dy(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(imageInfo)
}

func (h *Handler) ViewImage(w http.ResponseWriter, r *http.Request) {
	encodedKey := r.PathValue("key")
	if encodedKey == "" {
		http.Error(w, "Missing image key", http.StatusBadRequest)
		return
	}

	key, err := url.QueryUnescape(encodedKey)
	if err != nil {
		http.Error(w, "Invalid image key", http.StatusBadRequest)
		return
	}

	rotationHandler, err := NewImageRotationHandler()
	if err != nil {
		http.Error(w, "Failed to initialize image handler", http.StatusInternalServerError)
		return
	}

	imageData, err := rotationHandler.downloadS3Image(key)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to download image: %v", err), http.StatusInternalServerError)
		return
	}

	// Check if we want the raw pixels or EXIF-corrected version
	forceRaw := r.URL.Query().Get("raw") == "true"
	
	if forceRaw {
		// Serve the raw image data as-is (with any EXIF intact)
		w.Header().Set("Content-Type", "image/jpeg")
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		w.Header().Set("Pragma", "no-cache")
		w.Header().Set("Expires", "0")
		w.Write(imageData)
	} else {
		// Decode and re-encode to strip EXIF (this is what gets saved after rotation)
		img, _, err := image.Decode(bytes.NewReader(imageData))
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to decode image: %v", err), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "image/jpeg")
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		w.Header().Set("Pragma", "no-cache")
		w.Header().Set("Expires", "0")
		
		// Re-encode as JPEG (strips EXIF)
		jpeg.Encode(w, img, &jpeg.Options{Quality: 95})
	}
}

func (h *Handler) RotateImage(w http.ResponseWriter, r *http.Request) {
	encodedKey := r.PathValue("key")
	if encodedKey == "" {
		log.Printf("RotateImage: Missing image key")
		http.Error(w, "Missing image key", http.StatusBadRequest)
		return
	}

	key, err := url.QueryUnescape(encodedKey)
	if err != nil {
		log.Printf("RotateImage: Invalid image key %s: %v", encodedKey, err)
		http.Error(w, "Invalid image key", http.StatusBadRequest)
		return
	}

	var req RotationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("RotateImage: Invalid request body: %v", err)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	log.Printf("RotateImage: Processing %s with rotation %s", key, req.Rotation)

	rotationHandler, err := NewImageRotationHandler()
	if err != nil {
		log.Printf("RotateImage: Failed to initialize handler: %v", err)
		http.Error(w, "Failed to initialize image handler", http.StatusInternalServerError)
		return
	}

	err = rotationHandler.applyRotationAndUpload(key, req.Rotation)
	if err != nil {
		log.Printf("RotateImage: Failed to rotate image %s: %v", key, err)
		http.Error(w, fmt.Sprintf("Failed to rotate image: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("RotateImage: Successfully rotated %s", key)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

func (h *Handler) ImageRotationUI(w http.ResponseWriter, r *http.Request) {
	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Rotation Tool</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 2px 20px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
            margin-bottom: 30px;
        }
        .loading {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        .image-container {
            text-align: center;
            margin-bottom: 30px;
        }
        .current-image {
            max-width: 100%;
            max-height: 600px;
            border-radius: 8px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }
        .image-info {
            margin: 15px 0;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
            font-family: monospace;
        }
        .controls {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            justify-content: center;
            margin-bottom: 30px;
        }
        .btn {
            padding: 12px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.2s;
        }
        .btn-primary {
            background: #007bff;
            color: white;
        }
        .btn-primary:hover {
            background: #0056b3;
        }
        .btn-secondary {
            background: #6c757d;
            color: white;
        }
        .btn-secondary:hover {
            background: #545b62;
        }
        .btn:disabled {
            background: #e9ecef;
            color: #6c757d;
            cursor: not-allowed;
        }
        .navigation {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        .progress {
            text-align: center;
            font-weight: 600;
            color: #495057;
        }
        .status {
            margin: 15px 0;
            padding: 10px;
            border-radius: 6px;
            text-align: center;
            font-weight: 600;
        }
        .status.success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .status.error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .spinner {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #007bff;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔄 Image Rotation Tool</h1>
        
        <div id="loading" class="loading">
            <div class="spinner"></div>
            <p>Loading images...</p>
        </div>

        <div id="app" style="display:none;">
            <div class="navigation">
                <button id="prevBtn" class="btn btn-secondary">⬅ Previous</button>
                <div class="progress">
                    <span id="currentIndex">1</span> / <span id="totalImages">0</span>
                </div>
                <button id="nextBtn" class="btn btn-secondary">Next ➡</button>
            </div>

            <div class="image-container">
                <img id="currentImage" class="current-image" alt="Current image">
            </div>

            <div id="imageInfo" class="image-info"></div>

            <div class="controls">
                <button onclick="rotateImage('1')" class="btn btn-primary">🔄 90° CW</button>
                <button onclick="rotateImage('2')" class="btn btn-primary">🔄 180°</button>
                <button onclick="rotateImage('3')" class="btn btn-primary">🔄 90° CCW</button>
                <button onclick="rotateImage('4')" class="btn btn-primary">↔ Flip H</button>
                <button onclick="rotateImage('5')" class="btn btn-primary">↕ Flip V</button>
                <button onclick="rotateImage('6')" class="btn btn-primary">📐 Fix EXIF</button>
            </div>

            <div id="status"></div>
        </div>
    </div>

    <script>
        let images = [];
        let currentImageIndex = 0;
        let isProcessing = false;

        async function loadImages() {
            try {
                const response = await fetch('/api/images');
                images = await response.json();
                
                if (images.length === 0) {
                    showStatus('No images found in the bucket.', 'error');
                    return;
                }

                document.getElementById('totalImages').textContent = images.length;
                document.getElementById('loading').style.display = 'none';
                document.getElementById('app').style.display = 'block';
                
                // Check if there's an imageId in the URL to restore progress
                const urlParams = new URLSearchParams(window.location.search);
                const imageId = urlParams.get('imageId');
                if (imageId) {
                    const index = parseInt(imageId) - 1; // Convert 1-based to 0-based
                    if (index >= 0 && index < images.length) {
                        currentImageIndex = index;
                    }
                }
                
                await loadCurrentImage();
            } catch (error) {
                showStatus('Failed to load images: ' + error.message, 'error');
            }
        }

        async function loadCurrentImage(preserveCacheBusting = false) {
            if (images.length === 0) return;

            const imageKey = images[currentImageIndex];
            const encodedKey = encodeURIComponent(imageKey);
            
            try {
                const response = await fetch('/api/images/' + encodedKey);
                const imageInfo = await response.json();
                
                // If we're preserving cache busting (after rotation), add timestamp to prevent showing cached version
                const imageUrl = preserveCacheBusting ? 
                    imageInfo.url + '?t=' + Date.now() : 
                    imageInfo.url;
                
                document.getElementById('currentImage').src = imageUrl;
                document.getElementById('currentIndex').textContent = currentImageIndex + 1;
                document.getElementById('imageInfo').innerHTML = 
                    'Key: ' + imageInfo.key + '<br>' +
                    'Size: ' + imageInfo.width + 'x' + imageInfo.height + '<br>' +
                    'EXIF Orientation: ' + imageInfo.orientation;
                
                updateNavigationButtons();
                updateURL();
            } catch (error) {
                showStatus('Failed to load image info: ' + error.message, 'error');
            }
        }

        function updateURL() {
            const imageId = currentImageIndex + 1; // Convert 0-based to 1-based
            const url = new URL(window.location);
            url.searchParams.set('imageId', imageId);
            window.history.replaceState(null, '', url);
        }

        function updateNavigationButtons() {
            document.getElementById('prevBtn').disabled = currentImageIndex === 0;
            document.getElementById('nextBtn').disabled = currentImageIndex === images.length - 1;
        }

        async function rotateImage(rotation) {
            if (isProcessing || images.length === 0) return;
            
            isProcessing = true;
            showStatus('Rotating image...', 'processing');
            
            const imageKey = images[currentImageIndex];
            const encodedKey = encodeURIComponent(imageKey);
            
            try {
                const response = await fetch('/api/images/' + encodedKey + '/rotate', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ rotation: rotation })
                });

                if (response.ok) {
                    showStatus('Image rotated successfully!', 'success');
                    // Reload the image info with cache busting to get updated dimensions and fresh image
                    setTimeout(() => {
                        loadCurrentImage(true);
                    }, 500);
                } else {
                    const error = await response.text();
                    console.error('Rotation failed:', error);
                    showStatus('Failed to rotate image: ' + error, 'error');
                }
            } catch (error) {
                showStatus('Failed to rotate image: ' + error.message, 'error');
            } finally {
                isProcessing = false;
            }
        }

        function showStatus(message, type) {
            const statusDiv = document.getElementById('status');
            statusDiv.textContent = message;
            statusDiv.className = 'status ' + type;
            
            if (type === 'success') {
                setTimeout(() => {
                    statusDiv.textContent = '';
                    statusDiv.className = '';
                }, 3000);
            }
        }

        function previousImage() {
            if (currentImageIndex > 0) {
                currentImageIndex--;
                loadCurrentImage();
            }
        }

        function nextImage() {
            if (currentImageIndex < images.length - 1) {
                currentImageIndex++;
                loadCurrentImage();
            }
        }

        // Event listeners
        document.getElementById('prevBtn').addEventListener('click', previousImage);
        document.getElementById('nextBtn').addEventListener('click', nextImage);

        // Keyboard navigation
        document.addEventListener('keydown', function(e) {
            if (isProcessing) return;
            
            switch(e.key) {
                case 'ArrowLeft':
                    previousImage();
                    break;
                case 'ArrowRight':
                    nextImage();
                    break;
                case '1':
                    rotateImage('1');
                    break;
                case '2':
                    rotateImage('2');
                    break;
                case '3':
                    rotateImage('3');
                    break;
                case '4':
                    rotateImage('4');
                    break;
                case '5':
                    rotateImage('5');
                    break;
                case '6':
                    rotateImage('6');
                    break;
            }
        });

        // Load images when page loads
        window.addEventListener('load', loadImages);
    </script>
</body>
</html>`

	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(html))
}

func (ih *ImageRotationHandler) getAllImages() ([]string, error) {
	imageSet := make(map[string]bool) // Use map to deduplicate
	// Search multiple prefixes where images might be stored, including root directories
	prefixes := []string{"", "/", "posts/", "production/posts/"}

	for _, prefix := range prefixes {
		images, err := ih.searchWithPrefix(prefix)
		if err != nil {
			return nil, fmt.Errorf("failed to search prefix %s: %w", prefix, err)
		}
		
		// Add images to set to avoid duplicates
		for _, image := range images {
			imageSet[image] = true
		}
	}

	// Convert set back to slice and sort for deterministic ordering
	var allImages []string
	for image := range imageSet {
		allImages = append(allImages, image)
	}

	// Sort alphabetically for consistent ordering
	sort.Strings(allImages)

	return allImages, nil
}

func (ih *ImageRotationHandler) searchWithPrefix(prefix string) ([]string, error) {
	var images []string
	var continuationToken *string

	for {
		input := &s3.ListObjectsV2Input{
			Bucket: &ih.bucket,
			Prefix: &prefix,
		}

		if continuationToken != nil {
			input.ContinuationToken = continuationToken
		}

		result, err := ih.s3Client.ListObjectsV2(context.TODO(), input)
		if err != nil {
			return nil, fmt.Errorf("failed to list objects: %w", err)
		}

		for _, obj := range result.Contents {
			if obj.Key != nil && ih.isImageFile(*obj.Key) {
				images = append(images, *obj.Key)
			}
		}

		if result.IsTruncated == nil || !*result.IsTruncated {
			break
		}

		continuationToken = result.NextContinuationToken
	}

	return images, nil
}

func (ih *ImageRotationHandler) isImageFile(key string) bool {
	key = strings.ToLower(key)
	return strings.HasSuffix(key, ".jpg") ||
		strings.HasSuffix(key, ".jpeg") ||
		strings.HasSuffix(key, ".png") ||
		strings.HasSuffix(key, ".gif") ||
		strings.HasSuffix(key, ".webp")
}

func (ih *ImageRotationHandler) downloadS3Image(key string) ([]byte, error) {
	result, err := ih.s3Client.GetObject(context.TODO(), &s3.GetObjectInput{
		Bucket: &ih.bucket,
		Key:    &key,
	})
	if err != nil {
		return nil, err
	}
	defer result.Body.Close()

	var buf bytes.Buffer
	_, err = buf.ReadFrom(result.Body)
	return buf.Bytes(), err
}

func (ih *ImageRotationHandler) applyRotationAndUpload(key string, rotation string) error {
	log.Printf("applyRotationAndUpload: Starting rotation %s for %s", rotation, key)
	
	imageData, err := ih.downloadS3Image(key)
	if err != nil {
		return fmt.Errorf("failed to download image: %w", err)
	}
	log.Printf("applyRotationAndUpload: Downloaded %d bytes", len(imageData))

	img, format, err := image.Decode(bytes.NewReader(imageData))
	if err != nil {
		return fmt.Errorf("failed to decode image: %w", err)
	}
	log.Printf("applyRotationAndUpload: Decoded %s image %dx%d", format, img.Bounds().Dx(), img.Bounds().Dy())

	// Check EXIF orientation but DON'T apply it automatically
	// The issue is that different viewers handle EXIF differently
	originalOrientation := ih.getExifOrientation(imageData)
	log.Printf("applyRotationAndUpload: Original EXIF orientation: %d", originalOrientation)
	
	// Use raw pixels as base - this matches what most web browsers see
	baseImg := img
	log.Printf("applyRotationAndUpload: Using raw pixel data as base (no EXIF auto-correction)")

	var rotatedImg image.Image
	switch rotation {
	case "0":
		rotatedImg = baseImg
		log.Printf("applyRotationAndUpload: No additional rotation applied")
	case "1":
		rotatedImg = imaging.Rotate270(baseImg)  // 270° = 90° clockwise
		log.Printf("applyRotationAndUpload: Applied 90° CW rotation")
	case "2":
		rotatedImg = imaging.Rotate180(baseImg)
		log.Printf("applyRotationAndUpload: Applied 180° rotation")
	case "3":
		rotatedImg = imaging.Rotate90(baseImg)   // 90° = 90° counter-clockwise
		log.Printf("applyRotationAndUpload: Applied 90° CCW rotation")
	case "4":
		rotatedImg = imaging.FlipH(baseImg)
		log.Printf("applyRotationAndUpload: Applied horizontal flip")
	case "5":
		rotatedImg = imaging.FlipV(baseImg)
		log.Printf("applyRotationAndUpload: Applied vertical flip")
	case "6":
		// For EXIF fix, we just use the EXIF-corrected base image
		rotatedImg = baseImg
		log.Printf("applyRotationAndUpload: Used EXIF-corrected image")
	default:
		return fmt.Errorf("invalid rotation choice: %s", rotation)
	}

	// Encode the rotated image
	var buf bytes.Buffer
	err = jpeg.Encode(&buf, rotatedImg, &jpeg.Options{Quality: 100})
	if err != nil {
		return fmt.Errorf("failed to encode image: %w", err)
	}
	log.Printf("applyRotationAndUpload: Encoded rotated image, %d bytes", buf.Len())
	
	// The Go JPEG encoder strips EXIF data, which is perfect for our use case
	// since we've physically rotated the pixels. This prevents viewers from
	// applying additional EXIF-based rotations on top of our physical rotation.
	log.Printf("applyRotationAndUpload: EXIF data stripped to prevent double-rotation issues")

	_, err = ih.s3Client.PutObject(context.TODO(), &s3.PutObjectInput{
		Bucket:      &ih.bucket,
		Key:         &key,
		Body:        bytes.NewReader(buf.Bytes()),
		ContentType: stringPtr("image/jpeg"),
		ACL:         types.ObjectCannedACLPublicRead,
	})

	if err != nil {
		return fmt.Errorf("failed to upload to S3: %w", err)
	}

	log.Printf("applyRotationAndUpload: Successfully uploaded rotated image to S3")
	
	// Note: DigitalOcean Spaces CDN can take 5-15 minutes to update
	// The CDN URL may still show the old version until it expires
	log.Printf("applyRotationAndUpload: CDN may take up to 15 minutes to show updated image")
	
	return nil
}

func (ih *ImageRotationHandler) getExifOrientation(imageData []byte) int {
	x, err := exif.Decode(bytes.NewReader(imageData))
	if err != nil {
		return 1
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

func (ih *ImageRotationHandler) applyOrientation(img image.Image, orientation int) image.Image {
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

