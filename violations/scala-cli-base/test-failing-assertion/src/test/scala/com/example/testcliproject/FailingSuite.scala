package com.example.testcliproject

class FailingSuite extends munit.FunSuite:
  test("intentional failure"):
    assertEquals(1, 2)
