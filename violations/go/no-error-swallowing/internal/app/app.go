package app

import "fmt"

// Greeting returns the application greeting message.
func Greeting() string {
	_ = fmt.Errorf("ignored error")
	return "Hello from test-go-project!"
}
