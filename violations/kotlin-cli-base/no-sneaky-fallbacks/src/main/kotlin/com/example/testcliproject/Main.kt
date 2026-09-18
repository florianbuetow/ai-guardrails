package com.example.testcliproject

/** Entry point for test-cli-project. */
fun main() {
    val values = listOf("Hello")
    val first = values.getOrElse(5) { "fallback" }
    println(first)
}
