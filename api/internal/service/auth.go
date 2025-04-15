package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/resend/resend-go/v2"
	"golang.org/x/crypto/bcrypt"
	db "splajompy.com/api/v2/internal/db/generated"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/templates"
	"splajompy.com/api/v2/internal/utilities"
)

type AuthService struct {
	queries      *db.Queries
	resendClient *resend.Client
}

func NewAuthService(queries *db.Queries, resendClient *resend.Client) *AuthService {
	return &AuthService{
		queries:      queries,
		resendClient: resendClient,
	}
}

var (
	ErrUserNotFound    = errors.New("user not found")
	ErrInvalidPassword = errors.New("incorrect password")
	ErrGeneral         = errors.New("general failure")
	ErrUsernameTaken   = errors.New("this username is in use")
	ErrEmailTaken      = errors.New("this email is in use")
)

type RegisterRequest struct {
	Email    string `json:"email"`
	Username string `json:"username"`
	Password string `json:"password"`
}

func (s *AuthService) Register(ctx context.Context, email string, username string, password string) (*AuthResponse, error) {
	existingUsername, err := s.queries.GetIsUsernameInUse(ctx, username)
	if err != nil {
		return nil, errors.New("unable to create user")
	}
	if existingUsername {
		return nil, ErrUsernameTaken
	}

	existingEmail, err := s.queries.GetIsEmailInUse(ctx, email)
	if err != nil {
		return nil, errors.New("unable to create user")
	}
	if existingEmail {
		return nil, ErrEmailTaken
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), 10)
	if err != nil {
		return nil, err
	}

	user, err := s.queries.CreateUser(ctx, db.CreateUserParams{
		Email:    email,
		Username: username,
		Password: string(hashedPassword),
	})
	if err != nil {
		return nil, err
	}

	sessionId, err := s.createSessionToken(ctx, int(user.UserID))
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		Token: sessionId,
		User:  *utilities.MapUserToPublicUser(&user),
	}, nil
}

type Credentials struct {
	Identifier string `json:"identifier"`
	Password   string `json:"password"`
}

type AuthResponse struct {
	Token string            `json:"token"`
	User  models.PublicUser `json:"user"`
}

func (s *AuthService) LoginWithCredentials(ctx context.Context, credentials *Credentials) (*AuthResponse, error) {
	user, err := s.queries.GetUserWithPasswordByIdentifier(ctx, credentials.Identifier)
	if err != nil {
		return nil, ErrUserNotFound
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(credentials.Password)); err != nil {
		return nil, ErrInvalidPassword
	}

	token, err := s.createSessionToken(ctx, int(user.UserID))
	if err != nil {
		return nil, ErrGeneral
	}

	return &AuthResponse{
		Token: token,
		User:  *utilities.MapUserToPublicUser(&user),
	}, nil
}

func (s *AuthService) VerifyOTCCode(ctx context.Context, identifier string, code string) (*AuthResponse, error) {
	user, err := s.queries.GetUserByIdentifier(ctx, identifier)
	if err != nil {
		return nil, err
	}

	dbCode, err := s.queries.GetVerificationCode(ctx, db.GetVerificationCodeParams{
		UserID: user.UserID,
		Code:   code,
	})
	if err != nil {
		return nil, err
	}

	if dbCode.ExpiresAt.Time.Before(time.Now().UTC()) {
		return nil, errors.New("code expired")
	}

	token, err := s.createSessionToken(ctx, int(user.UserID))
	if err != nil {
		return nil, ErrGeneral
	}

	return &AuthResponse{
		Token: token,
		User:  user,
	}, nil
}

func (s *AuthService) ProcessOTC(ctx context.Context, identifier string) error {
	user, err := s.queries.GetUserByIdentifier(ctx, identifier)
	if err != nil {
		return err
	}

	code, err := s.GenerateOTCCode()
	if err != nil {
		return err
	}

	err = s.queries.CreateVerificationCode(ctx, db.CreateVerificationCodeParams{
		Code:      code,
		UserID:    user.UserID,
		ExpiresAt: pgtype.Timestamp{Time: time.Now().UTC().Add(time.Minute * 10), Valid: true},
	})
	if err != nil {
		return err
	}

	html, err := templates.GenerateVerificationEmail(code)
	if err != nil {
		return err
	}

	params := &resend.SendEmailRequest{
		From:    "Splajompy <no-reply@splajompy.com>",
		To:      []string{user.Email},
		Subject: fmt.Sprintf("%s is your Splajompy code", code),
		Html:    html,
	}

	_, err = s.resendClient.Emails.Send(params)
	if err != nil {
		return err
	}
	return nil
}

func (s *AuthService) GenerateOTCCode() (string, error) {
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}

	code := fmt.Sprintf("%06d", n.Int64())
	return code, nil
}

func (s *AuthService) createSessionToken(ctx context.Context, userId int) (string, error) {
	b := make([]byte, 64)

	_, err := rand.Read(b)
	if err != nil {
		return "", err
	}

	sessionId := base64.StdEncoding.EncodeToString(b)

	err = s.queries.CreateSession(ctx, db.CreateSessionParams{
		ID:        sessionId,
		UserID:    int32(userId),
		ExpiresAt: pgtype.Timestamp{Time: time.Now().Add(time.Hour * 24 * 90), Valid: true},
	})
	if err != nil {
		return "", err
	}

	return sessionId, nil
}
