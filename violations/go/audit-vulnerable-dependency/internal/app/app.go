package app

import "golang.org/x/text/language"

// Greeting returns the application greeting message.
func Greeting() string {
	tag, _ := language.Parse("en")
	return "Hello from test-go-project! " + tag.String()
}
