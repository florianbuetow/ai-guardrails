package com.example.testcliproject

class SkippedSuite extends munit.FunSuite:
  test("skipped test".ignore):
    assertEquals(1, 1)
