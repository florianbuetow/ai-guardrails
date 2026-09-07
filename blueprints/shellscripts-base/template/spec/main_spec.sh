#!/bin/sh

Describe 'greeting command'
It 'greets a name with whitespace'
When run script src/main.sh 'Shell World'
The status should be success
The output should equal 'Hello, Shell World!'
End

It 'rejects a missing name'
When run script src/main.sh
The status should equal 1
The stderr should include 'Usage:'
End

It 'rejects an empty name'
When run script src/main.sh ''
The status should equal 1
The stderr should equal 'error: NAME must not be empty'
End
End
