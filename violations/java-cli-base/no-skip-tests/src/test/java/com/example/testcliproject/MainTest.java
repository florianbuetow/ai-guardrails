package com.example.testcliproject;

import static org.assertj.core.api.Assertions.assertThatCode;

import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;

/** Tests for {@link Main}. */
class MainTest {

  @Test
  @Disabled("not implemented yet")
  void mainRunsWithoutError() {
    assertThatCode(() -> Main.main(new String[] {})).doesNotThrowAnyException();
  }
}
