package com.example.testcliproject

/** Entry point for test-cli-project. */
fun main() {
    println("Hello from test-cli-project!")
}

/**
 * Public, untested helper. No test exercises any of these lines, so overall
 * line coverage drops below the configured Kover threshold and koverVerify
 * fails.
 */
fun describeValue(value: Int): String {
    val doubled = value + value
    val size =
        if (doubled > value) {
            "positive"
        } else {
            "non-positive"
        }
    val prefix = size.uppercase()
    val suffix = doubled.toString()
    val combined = "$prefix-$suffix"
    return combined.trim()
}
