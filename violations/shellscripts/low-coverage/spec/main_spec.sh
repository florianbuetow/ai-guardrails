#!/bin/sh

Describe 'greeting command'
It 'checks only the successful path'
When run script src/main.sh World
The status should be success
The output should equal 'Hello, World!'
End
End
