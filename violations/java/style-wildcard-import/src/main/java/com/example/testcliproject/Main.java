package com.example.testcliproject;

import java.util.*;

/** Test CLI application. */
public final class Main {

  private Main() {}

  /** Main entry point. */
  public static void main(String[] args) {
    List<String> items = new ArrayList<>();
    items.add("Hello from test-cli-project!");
    System.out.println(items.get(0));
  }
}
