package token

import (
	"crypto/ecdsa"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	TokenTimeout = 60 * 60
)

var (
	ErrMissingPrivateKey = errors.New("missing private key")
)

type Token struct {
	PrivateKey *ecdsa.PrivateKey
	KeyId      string
	TeamId     string
	IssuedAt   int64
	Bearer     string
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
