package com.example.testcliproject

import org.assertj.core.api.Assertions.assertThatCode
import org.junit.jupiter.api.Disabled
import org.junit.jupiter.api.Test

/** Tests for [main]. */
class MainTest {
    @Disabled("temporarily disabled")
    @Test
    fun mainRunsWithoutError() {
        assertThatCode { main() }.doesNotThrowAnyException()
    }
}
