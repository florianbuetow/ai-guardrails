package com.example.testcliproject;

import java.util.Random;

/** Test CLI application. */
public final class Main {

  private Main() {}

  /** Main entry point. */
  public static void main(String[] args) {
    Random random = new Random();
    String token = String.valueOf(random.nextLong());
    System.out.println("Hello from test-cli-project! Token: " + token);
  }
}
