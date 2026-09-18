package app

import (
	"os/exec"
)

// Greeting returns the application greeting message.
func Greeting() string {
	cmd := exec.Command("sh", "-c", "echo hello") // #nosec G204
	output, err := cmd.Output()
	if err != nil {
		return "Hello from test-go-project!"
	}
	return string(output)
}
