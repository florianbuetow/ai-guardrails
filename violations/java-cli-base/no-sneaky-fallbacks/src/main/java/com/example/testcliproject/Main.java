package com.example.testcliproject;

import java.util.Objects;

/** Test CLI application. */
public final class Main {

  private Main() {}

  /** Main entry point. */
  public static void main(String[] args) {
    String name = Objects.requireNonNullElse(null, "test-cli-project");
    System.out.println("Hello from " + name + "!");
  }
}
