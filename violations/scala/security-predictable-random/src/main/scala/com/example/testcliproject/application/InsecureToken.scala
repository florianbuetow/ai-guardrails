package com.example.testcliproject.application

import java.util.Random

object InsecureToken:
  private val random = new Random()

  def nextToken(): Int = random.nextInt()
