package app

import "testing"

func TestGreeting(t *testing.T) {
	t.Skip("not implemented yet")
	got := Greeting()
	want := "Hello from test-go-project!"
	if got != want {
		t.Errorf("Greeting() = %q, want %q", got, want)
	}
}
