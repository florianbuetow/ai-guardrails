package com.example.testcliproject;

import java.util.HashMap;
import java.util.Map;

/** Test CLI application. */
public final class Main {

  private Main() {}

  /** Main entry point. */
  public static void main(String[] args) {
    Map<String, String> map = new HashMap<>();
    String value = map.get("missing_key");
    // Infer detects NULL_DEREFERENCE: value is null because key doesn't exist
    System.out.println("Length: " + value.length());
  }
}
