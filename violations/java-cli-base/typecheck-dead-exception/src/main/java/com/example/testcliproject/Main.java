package com.example.testcliproject;

/** Test CLI application. */
public final class Main {

  private Main() {}

  /** Main entry point. */
  public static void main(String[] args) {
    new RuntimeException("something went wrong");
    System.out.println("Hello from test-cli-project!");
  }
}
