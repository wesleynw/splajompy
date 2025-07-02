package main

import (
	"fmt"
)

func main() {
	// Test the prefix list
	prefixes := []string{"", "/", "posts/", "production/posts/"}
	
	fmt.Println("Testing comprehensive S3 prefix scanning:")
	for i, prefix := range prefixes {
		displayPrefix := prefix
		if displayPrefix == "" {
			displayPrefix = "[root]"
		}
		fmt.Printf("%d. Prefix: %s\n", i+1, displayPrefix)
	}
	
	// Test deduplication logic
	imageSet := make(map[string]bool)
	testImages := []string{"posts/image1.jpg", "posts/image1.jpg", "image2.jpg", "/image3.jpg"}
	
	for _, image := range testImages {
		imageSet[image] = true
	}
	
	fmt.Printf("\nDeduplication test - %d input images -> %d unique images:\n", len(testImages), len(imageSet))
	for image := range imageSet {
		fmt.Printf("  - %s\n", image)
	}
}
EOF < /dev/null