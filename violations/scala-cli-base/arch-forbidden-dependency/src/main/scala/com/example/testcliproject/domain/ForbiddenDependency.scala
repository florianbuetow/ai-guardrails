package com.example.testcliproject.domain

import com.example.testcliproject.application.GreetingService

object ForbiddenDependency:
  def greeting: Either[String, Greeting] = GreetingService.create("forbidden")
