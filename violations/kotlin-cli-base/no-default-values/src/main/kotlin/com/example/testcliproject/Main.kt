package com.example.testcliproject

/** Entry point for test-cli-project. */
fun main() {
    val config = mapOf("greeting" to "Hello")
    val greeting = config.getOrDefault("greeting", "Hi")
    println(greeting)
}
