package bucket

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"errors"
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

	privateKey, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	if key, ok := privateKey.(*rsa.PrivateKey); ok {
		return sign.NewURLSigner(keyPairId, key), nil
	} else {
		return nil, errors.New("unable to find private key")
	}
}
