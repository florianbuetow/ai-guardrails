package app

// Greeting returns the application greeting message.
func Greeting() string {
	x := 1
	if x == x {
		return "Hello from test-go-project!"
	}
	return ""
}
