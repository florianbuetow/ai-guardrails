package com.example.testcliproject

object SneakyFallback:
  def load(value: Option[String]): String = value.getOrElse("fallback")
