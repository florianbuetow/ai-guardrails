package com.example.testcliproject

object UncoveredBranches:
  def classify(value: Int): String =
    if value < -100 then "very negative"
    else if value < 0 then "negative"
    else if value == 0 then "zero"
    else if value < 100 then "positive"
    else "very positive"
