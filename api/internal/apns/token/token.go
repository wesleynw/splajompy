package token

import (
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"errors"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	TokenTimeout = 60 * 60
)

var (
	ErrMissingPrivateKey  = errors.New("missing private key")
	ErrPrivateKeyNotECDSA = errors.New("key is not ECDSA")
)

type Token struct {
	PrivateKey *ecdsa.PrivateKey
	KeyId      string
	TeamId     string
	IssuedAt   int64
	Bearer     string
}

func NewToken() *Token {
	privateKeyString := os.Getenv("APN_PRIVATE_KEY")
	keyId := os.Getenv("APN_KEY_ID")
	teamId := os.Getenv("APN_TEAM_ID")

	pKey, err := decodePrivateKey(privateKeyString)
	if err != nil {
		return nil
	}

	token := Token{
		PrivateKey: pKey,
		KeyId:      keyId,
		TeamId:     teamId,
	}

	err = token.Generate()
	if err != nil {
		return nil
	}

	return &token
}

func decodePrivateKey(privateKeyString string) (*ecdsa.PrivateKey, error) {
	pemStr, err := base64.StdEncoding.DecodeString(privateKeyString)
	if err != nil {
		return nil, err
	}

	block, _ := pem.Decode(pemStr)

	keys, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	if key, ok := keys.(*ecdsa.PrivateKey); ok {
		return key, nil
	}

	return nil, ErrPrivateKeyNotECDSA
}

func (t *Token) Generate() error {
	if t.PrivateKey == nil {
		return ErrMissingPrivateKey
	}

	issuedAt := time.Now().Unix()
	claims := jwt.MapClaims{
		"iss": t.TeamId,
		"iat": issuedAt,
	}

	jwt := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	s, err := jwt.SignedString(t.PrivateKey)
	if err != nil {
		return err
	}

	t.Bearer = s
	t.IssuedAt = issuedAt
	return nil
}

func (t *Token) IsExpired() bool {
	return time.Now().Unix() > t.IssuedAt+TokenTimeout
}

func (t *Token) GetBearerToken() (*string, error) {
	if !t.IsExpired() {
		return &t.Bearer, nil
	}

	err := t.Generate()
	if err != nil {
		return nil, err
	}

	return &t.Bearer, nil
}
