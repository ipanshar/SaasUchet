package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"strconv"
	"strings"
)

const (
	passwordSaltSize   = 16
	passwordKeyLength  = 32
	passwordIterations = 120000
	passwordScheme     = "pbkdf2_sha256"
)

func HashPassword(password string) (string, error) {
	salt, err := randomBytes(passwordSaltSize)
	if err != nil {
		return "", fmt.Errorf("generate password salt: %w", err)
	}

	hash := pbkdf2SHA256([]byte(password), salt, passwordIterations, passwordKeyLength)

	return fmt.Sprintf(
		"%s$%d$%s$%s",
		passwordScheme,
		passwordIterations,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(hash),
	), nil
}

func VerifyPassword(password string, encoded string) bool {
	parts := strings.Split(encoded, "$")
	if len(parts) != 4 || parts[0] != passwordScheme {
		return false
	}

	iterations, err := strconv.Atoi(parts[1])
	if err != nil || iterations <= 0 {
		return false
	}

	salt, err := base64.RawStdEncoding.DecodeString(parts[2])
	if err != nil {
		return false
	}

	expectedHash, err := base64.RawStdEncoding.DecodeString(parts[3])
	if err != nil {
		return false
	}

	actualHash := pbkdf2SHA256([]byte(password), salt, iterations, len(expectedHash))

	return subtle.ConstantTimeCompare(actualHash, expectedHash) == 1
}

func pbkdf2SHA256(password []byte, salt []byte, iterations int, keyLength int) []byte {
	hashLength := sha256.Size
	blockCount := (keyLength + hashLength - 1) / hashLength
	derivedKey := make([]byte, 0, blockCount*hashLength)

	for blockIndex := 1; blockIndex <= blockCount; blockIndex++ {
		u := pbkdf2Block(password, salt, blockIndex)
		t := append([]byte(nil), u...)

		for iteration := 1; iteration < iterations; iteration++ {
			u = pbkdf2PRF(password, u)

			for i := range t {
				t[i] ^= u[i]
			}
		}

		derivedKey = append(derivedKey, t...)
	}

	return derivedKey[:keyLength]
}

func pbkdf2Block(password []byte, salt []byte, blockIndex int) []byte {
	blockSalt := make([]byte, len(salt)+4)
	copy(blockSalt, salt)
	blockSalt[len(salt)] = byte(blockIndex >> 24)
	blockSalt[len(salt)+1] = byte(blockIndex >> 16)
	blockSalt[len(salt)+2] = byte(blockIndex >> 8)
	blockSalt[len(salt)+3] = byte(blockIndex)

	return pbkdf2PRF(password, blockSalt)
}

func pbkdf2PRF(password []byte, payload []byte) []byte {
	mac := hmac.New(sha256.New, password)
	mac.Write(payload)
	return mac.Sum(nil)
}

func randomBytes(size int) ([]byte, error) {
	bytes := make([]byte, size)

	if _, err := rand.Read(bytes); err != nil {
		return nil, err
	}

	return bytes, nil
}
