Describe 'greeting command'
  It 'checks the greeting'
    When run script src/main.sh World
    The status should be success
    The output should equal 'incorrect greeting'
  End
End
