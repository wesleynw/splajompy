package bucket

import (
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"os"

	"github.com/aws/aws-sdk-go-v2/feature/cloudfront/sign"
)

func NewCloudfrontSigner() (*sign.URLSigner, error) {
	keyPairId := os.Getenv("CLOUDFRONT_KEYPAIR_ID")
	privateKeyEncoded := os.Getenv("CLOUDFRONT_PRIVATE_KEY")
	privateKeyBytes, err := base64.StdEncoding.DecodeString(privateKeyEncoded)
	if err != nil {
		return nil, err
	}

	block, _ := pem.Decode(privateKeyBytes)

	privateKey, err := x509.ParseECPrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	return sign.NewURLSigner(keyPairId, privateKey), nil
}
