package apns_test

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/apns"
)

func TestGenerate_ReusesUnexpiredToken(t *testing.T) {
	testKey, _ := generateTestPrivateKey(t)
	tok := apns.NewToken(testKey, "123", "456")
	require.NotEmpty(t, tok)

	bearer, err := tok.GetBearerToken()
	require.NoError(t, err)

	bearer2, err := tok.GetBearerToken()
	require.NoError(t, err)

	assert.Equal(t, bearer, bearer2)
}

func generateTestPrivateKey(t *testing.T) (string, *ecdsa.PrivateKey) {
	t.Helper()

	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("failed to generate key: %v", err)
	}

	der, err := x509.MarshalPKCS8PrivateKey(privateKey)
	if err != nil {
		t.Fatalf("failed to marshal key: %v", err)
	}

	pemBlock := pem.EncodeToMemory(&pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: der,
	})

	return base64.StdEncoding.EncodeToString(pemBlock), privateKey
}
