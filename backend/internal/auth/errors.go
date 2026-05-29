package auth

import "errors"

var (
	ErrValidation         = errors.New("validation failed")
	ErrPhoneTaken         = errors.New("phone already registered")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUnauthorized       = errors.New("unauthorized")
	ErrNotFound           = errors.New("not found")
)

type publicError struct {
	kind    error
	message string
}

func (e publicError) Error() string {
	return e.message
}

func (e publicError) Unwrap() error {
	return e.kind
}

func newPublicError(kind error, message string) error {
	return publicError{
		kind:    kind,
		message: message,
	}
}
