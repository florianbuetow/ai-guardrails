package app

import "fmt"

// Greeting returns the application greeting message.
func Greeting() string {
	return "Hello from test-go-project!"
}

// Process runs application logic and returns a result.
func Process() (result string, err error) {
	result = fmt.Sprintf("processed: %s", Greeting())
	return
}
