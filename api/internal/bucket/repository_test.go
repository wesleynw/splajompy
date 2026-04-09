package bucket_test

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/bucket"
)

func TestGetDestinationKey(t *testing.T) {
	err := os.Setenv("ENVIRONMENT", "production")
	require.NoError(t, err)

	blobUrl := "blah/blah/blah/469f794b-65d2-436c-a18e-58409b47a683.jpg"

	key := bucket.GetDestinationKey(10, "posts", 10, blobUrl)

	assert.Equal(t, "production/10/posts/10/469f794b-65d2-436c-a18e-58409b47a683.jpg", key)
}
