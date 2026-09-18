package com.example.testcliproject

object MutableVariable:
  def increment(): Int =
    var value = 0
    value += 1
    value
