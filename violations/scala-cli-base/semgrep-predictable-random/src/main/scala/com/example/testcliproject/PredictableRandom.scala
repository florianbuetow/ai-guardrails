package com.example.testcliproject

object PredictableRandom:
  def nextValue(): Int = scala.util.Random.nextInt()
