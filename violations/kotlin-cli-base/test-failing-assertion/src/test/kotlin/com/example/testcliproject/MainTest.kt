package com.example.testcliproject

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatCode
import org.junit.jupiter.api.Test

/** Tests for [main]. */
class MainTest {
    @Test
    fun mainRunsWithoutError() {
        assertThatCode { main() }.doesNotThrowAnyException()
    }

    @Test
    fun deliberatelyFailingAssertion() {
        assertThat(2 + 2).isEqualTo(5)
    }
}
