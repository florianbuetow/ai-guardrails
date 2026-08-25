package com.example.testcliproject

object UnusedValue:
  def message(input: String): String =
    val unused = input
    "fixed"
