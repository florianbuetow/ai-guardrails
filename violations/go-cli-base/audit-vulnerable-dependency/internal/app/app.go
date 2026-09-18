package app

import "golang.org/x/text/language"

// Greeting returns the application greeting message.
func Greeting() string {
	tags, _, _ := language.ParseAcceptLanguage("en;q=0.9,de;q=0.8")
	if len(tags) > 0 {
		return "Hello from test-go-project! " + tags[0].String()
	}
	return "Hello from test-go-project!"
}
