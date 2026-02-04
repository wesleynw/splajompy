package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"math/big"
	"regexp"
	"strings"
	"time"

	"splajompy.com/api/v2/internal/repositories"

	"github.com/google/uuid"
	"github.com/resend/resend-go/v3"
	"golang.org/x/crypto/bcrypt"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/templates"
)

type AuthService struct {
	userRepository   repositories.UserRepository
	postRepository   repositories.PostRepository
	bucketRepository repositories.BucketRepository
	resendClient     *resend.Client
}

func NewAuthService(userRepository repositories.UserRepository, postRepository repositories.PostRepository, bucketRepository repositories.BucketRepository, resendClient *resend.Client) *AuthService {
	return &AuthService{
		userRepository:   userRepository,
		postRepository:   postRepository,
		bucketRepository: bucketRepository,
		resendClient:     resendClient,
	}
}

var (
	ErrUserNotFound          = errors.New("user not found")
	ErrInvalidPassword       = errors.New("incorrect password")
	ErrGeneral               = errors.New("general failure")
	ErrUsernameTaken         = errors.New("this username is in use")
	ErrEmailTaken            = errors.New("this email is in use")
	ErrUsernameInvalidFormat = errors.New("username can only contain letters, numbers, and periods")
	ErrUsernameTooShort      = errors.New("username must be at least 1 character")
	ErrUsernameTooLong       = errors.New("username must be 25 characters or less")
	ErrPasswordTooShort      = errors.New("password must be at least 8 characters")
	ErrInvalidEmail          = errors.New("please enter a valid email address")
)

type RegisterRequest struct {
	Email    string `json:"email"`
	Username string `json:"username"`
	Password string `json:"password"`
}

// Register performs all the necessary actions to set up a user in the system.
func (s *AuthService) Register(ctx context.Context, email string, username string, password string) (*AuthResponse, error) {
	if err := s.ValidateRegistrationData(email, username, password); err != nil {
		return nil, err
	}

	username = strings.ToLower(username)

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

	referralCode, err := s.generateReferralCode(ctx)
	if err != nil {
		return nil, err
	}

	user, err := s.userRepository.CreateUser(ctx, username, email, string(hashedPassword), *referralCode)
	if err != nil {
		return nil, err
	}

	sessionId, err := s.createSessionToken(ctx, user.UserID)
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		Token: sessionId,
		User:  user,
	}, nil
}

func (s *AuthService) ValidateRegistrationData(email, username, password string) error {
	if email == "" {
		return errors.New("email cannot be empty")
	}

	if len(username) < 1 {
		return ErrUsernameTooShort
	}

	if len(username) > 25 {
		return ErrUsernameTooLong
	}

	alphanumericRegex := regexp.MustCompile(`^[a-zA-Z0-9.]+$`)
	if !alphanumericRegex.MatchString(username) {
		return ErrUsernameInvalidFormat
	}

	if password == "" {
		return errors.New("password cannot be empty")
	}

	if len(password) < 8 {
		return ErrPasswordTooShort
	}

	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	if !emailRegex.MatchString(email) {
		return ErrInvalidEmail
	}

	return nil
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
	identifier = strings.ToLower(identifier)

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
	credentials.Identifier = strings.ToLower(credentials.Identifier)

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
	identifier = strings.ToLower(identifier)

	user, err := s.userRepository.GetUserByIdentifier(ctx, identifier)
	if err != nil {
		return nil, err
	}

	dbCode, err := s.userRepository.GetVerificationCode(ctx, user.UserID, code)
	if err != nil {
		return nil, err
	}

	if dbCode.ExpiresAt.Time.Before(time.Now().UTC()) {
		return nil, errors.New("code expired")
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

func (s *AuthService) ProcessOTC(ctx context.Context, identifier string) error {
	identifier = strings.ToLower(identifier)

	user, err := s.userRepository.GetUserByIdentifier(ctx, identifier)
	if err != nil {
		return err
	}

	code, err := s.GenerateOTCCode()
	if err != nil {
		return err
	}

	err = s.userRepository.CreateVerificationCode(ctx, user.UserID, code, time.Now().UTC().Add(time.Minute*10))
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

// generateReferralCode returns a unique referral code, generated by taking the prefix of a UUID
// and confirming that there are no collisions in the database.
func (s *AuthService) generateReferralCode(ctx context.Context) (*string, error) {
	code := uuid.New().String()[0:5]
	isInUse, err := s.userRepository.GetIsReferralCodeInUse(ctx, code)
	if err != nil {
		return nil, err
	}

	for isInUse {
		code = uuid.New().String()[0:5]
		isInUse, err = s.userRepository.GetIsReferralCodeInUse(ctx, code)
		if err != nil {
			return nil, err
		}
	}

	formattedCode := strings.ToUpper(code)
	return &formattedCode, nil
}

func (s *AuthService) DeleteAccount(ctx context.Context, currentUser models.PublicUser) error {
	images, err := s.postRepository.GetAllImagesForUser(ctx, currentUser.UserID)
	if err != nil {
		return fmt.Errorf("failed to get user images: %w", err)
	}

	var s3Keys []string
	for _, image := range images {
		if image.ImageBlobUrl != "" {
			s3Keys = append(s3Keys, image.ImageBlobUrl)
		}
	}

	// Delete the user account (this will CASCADE delete all related data)
	err = s.userRepository.DeleteAccount(ctx, currentUser.UserID)
	if err != nil {
		return fmt.Errorf("failed to delete user account: %w", err)
	}

	// Delete images from S3 (best effort - don't fail if this fails)
	if len(s3Keys) > 0 {
		err = s.bucketRepository.DeleteObjects(ctx, s3Keys)
		if err != nil {
			fmt.Printf("Warning: Failed to delete %d images from S3 for user %d: %v\n", len(s3Keys), currentUser.UserID, err)
		}
	}

	return nil
}
