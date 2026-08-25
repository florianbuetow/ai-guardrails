package com.example.testcliproject

object SilentDefault:
  def load(value: String = "fallback"): String = value
