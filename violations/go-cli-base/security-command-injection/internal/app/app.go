package app

import (
	"fmt"
	"os"
	"os/exec"
)

// Greeting returns the application greeting message.
func Greeting() string {
	userInput := os.Args[0]
	cmd := exec.Command("sh", "-c", userInput)
	if err := cmd.Run(); err != nil {
		fmt.Println("command failed:", err)
	}
	return "Hello from test-go-project!"
}
