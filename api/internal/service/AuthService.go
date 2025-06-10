package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"math/big"
	"splajompy.com/api/v2/internal/repositories"
	"time"

	"github.com/resend/resend-go/v2"
	"golang.org/x/crypto/bcrypt"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/templates"
)

type AuthService struct {
	userRepository repositories.UserRepository
	resendClient   *resend.Client
}

func NewAuthService(userRepository repositories.UserRepository, resendClient *resend.Client) *AuthService {
	return &AuthService{
		userRepository: userRepository,
		resendClient:   resendClient,
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
	existingUsername, err := s.userRepository.GetIsUsernameInUse(ctx, username)
	if err != nil {
		return nil, errors.New("unable to create user")
	}
	if existingUsername {
		return nil, ErrUsernameTaken
	}

	existingEmail, err := s.userRepository.GetIsEmailInUse(ctx, email)
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

	user, err := s.userRepository.CreateUser(ctx, username, email, string(hashedPassword))
	if err != nil {
		return nil, err
	}

	sessionId, err := s.createSessionToken(ctx, int(user.UserID))
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		Token: sessionId,
		User:  user,
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

func (s *AuthService) VerifyPassword(ctx context.Context, identifier string, password string) (bool, error) {
	storedPassword, err := s.userRepository.GetUserPasswordByIdentifier(ctx, identifier)
	if err != nil {
		return false, ErrInvalidPassword
	}

	if err := bcrypt.CompareHashAndPassword([]byte(storedPassword), []byte(password)); err != nil {
		return false, ErrInvalidPassword
	}

	return true, nil
}

func (s *AuthService) LoginWithCredentials(ctx context.Context, credentials *Credentials) (*AuthResponse, error) {
	password, err := s.userRepository.GetUserPasswordByIdentifier(ctx, credentials.Identifier)
	if err != nil {
		return nil, ErrUserNotFound
	}

	if err := bcrypt.CompareHashAndPassword([]byte(password), []byte(credentials.Password)); err != nil {
		return nil, ErrInvalidPassword
	}

	user, err := s.userRepository.GetUserByIdentifier(ctx, credentials.Identifier)
	if err != nil {
		return nil, ErrUserNotFound
	}

	token, err := s.createSessionToken(ctx, user.UserID)
	if err != nil {
		return nil, ErrGeneral
	}

	return &AuthResponse{
		Token: token,
		User:  user,
	}, nil
}

func (s *AuthService) VerifyOTCCode(ctx context.Context, identifier string, code string) (*AuthResponse, error) {
	user, err := s.userRepository.GetUserByIdentifier(ctx, identifier)
	if err != nil {
		return nil, err
	}

	dbCode, err := s.userRepository.GetVerificationCode(ctx, int(user.UserID), code)
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
	user, err := s.userRepository.GetUserByIdentifier(ctx, identifier)
	if err != nil {
		return err
	}

	code, err := s.GenerateOTCCode()
	if err != nil {
		return err
	}

	err = s.userRepository.CreateVerificationCode(ctx, int(user.UserID), code, time.Now().UTC().Add(time.Minute*10))
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
	return err
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

	err = s.userRepository.CreateSession(ctx, sessionId, userId,
		time.Now().Add(time.Hour*24*90))
	if err != nil {
		return "", err
	}

	return sessionId, nil
}

func (s *AuthService) DeleteAccount(ctx context.Context, currentUser models.PublicUser) error {
	return s.userRepository.DeleteAccount(ctx, currentUser.UserID)
}
