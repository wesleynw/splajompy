package handler

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"splajompy.com/api/v2/internal/service"
)

func TestAuthService_ValidateRegistrationData(t *testing.T) {
	authService := service.NewAuthService(nil, nil, nil, nil)

	tests := []struct {
		name     string
		email    string
		username string
		password string
		expected error
	}{
		{
			name:     "valid registration request",
			email:    "test@example.com",
			username: "testuser",
			password: "password123",
			expected: nil,
		},
		{
			name:     "valid registration with minimum username length",
			email:    "user@domain.com",
			username: "abc",
			password: "password123",
			expected: nil,
		},
		{
			name:     "valid registration with minimum password length",
			email:    "user@domain.com",
			username: "username",
			password: "12345678",
			expected: nil,
		},
		{
			name:     "valid registration with numbers in username",
			email:    "user@domain.com",
			username: "user123",
			password: "password123",
			expected: nil,
		},
		{
			name:     "valid registration with complex email",
			email:    "user.name+tag@example-domain.co.uk",
			username: "username",
			password: "password123",
			expected: nil,
		},

		// Email validation tests
		{
			name:     "empty email",
			email:    "",
			username: "testuser",
			password: "password123",
			expected: assert.AnError,
		},
		{
			name:     "invalid email - missing @",
			email:    "testexample.com",
			username: "testuser",
			password: "password123",
			expected: service.ErrInvalidEmail,
		},
		{
			name:     "invalid email - missing domain",
			email:    "test@",
			username: "testuser",
			password: "password123",
			expected: service.ErrInvalidEmail,
		},
		{
			name:     "invalid email - missing TLD",
			email:    "test@example",
			username: "testuser",
			password: "password123",
			expected: service.ErrInvalidEmail,
		},
		{
			name:     "invalid email - multiple @",
			email:    "test@@example.com",
			username: "testuser",
			password: "password123",
			expected: service.ErrInvalidEmail,
		},
		{
			name:     "invalid email - spaces",
			email:    "test @example.com",
			username: "testuser",
			password: "password123",
			expected: service.ErrInvalidEmail,
		},

		// Username validation tests
		{
			name:     "empty username",
			email:    "test@example.com",
			username: "",
			password: "password123",
			expected: service.ErrUsernameTooShort,
		},
		{
			name:     "valid registration with 1 character username",
			email:    "test@example.com",
			username: "a",
			password: "password123",
			expected: nil,
		},
		{
			name:     "valid registration with 2 character username",
			email:    "test@example.com",
			username: "ab",
			password: "password123",
			expected: nil,
		},
		{
			name:     "username with special characters",
			email:    "test@example.com",
			username: "user@name",
			password: "password123",
			expected: service.ErrUsernameInvalidFormat,
		},
		{
			name:     "username with underscore",
			email:    "test@example.com",
			username: "user_name",
			password: "password123",
			expected: service.ErrUsernameInvalidFormat,
		},
		{
			name:     "username with hyphen",
			email:    "test@example.com",
			username: "user-name",
			password: "password123",
			expected: service.ErrUsernameInvalidFormat,
		},
		{
			name:     "username with space",
			email:    "test@example.com",
			username: "user name",
			password: "password123",
			expected: service.ErrUsernameInvalidFormat,
		},
		{
			name:     "username with period",
			email:    "test@example.com",
			username: "user.name",
			password: "password123",
			expected: service.ErrUsernameInvalidFormat,
		},

		// Password validation tests
		{
			name:     "empty password",
			email:    "test@example.com",
			username: "testuser",
			password: "",
			expected: assert.AnError,
		},
		{
			name:     "password too short - 1 character",
			email:    "test@example.com",
			username: "testuser",
			password: "a",
			expected: service.ErrPasswordTooShort,
		},
		{
			name:     "password too short - 7 characters",
			email:    "test@example.com",
			username: "testuser",
			password: "1234567",
			expected: service.ErrPasswordTooShort,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := authService.ValidateRegistrationData(tt.email, tt.username, tt.password)

			switch tt.expected {
			case nil:
				assert.NoError(t, err)
			case assert.AnError:
				assert.Error(t, err)
			default:
				assert.Equal(t, tt.expected, err)
			}
		})
	}
}
