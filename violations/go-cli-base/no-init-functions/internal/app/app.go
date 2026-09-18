package app

var loaded bool

func init() {
	loaded = true
}

// Greeting returns the application greeting message.
func Greeting() string {
	if loaded {
		return "Hello from test-go-project!"
	}
	return "Hello from test-go-project!"
}
