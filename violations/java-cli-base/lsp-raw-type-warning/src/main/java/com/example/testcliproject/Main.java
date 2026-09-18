package com.example.testcliproject;

import java.util.ArrayList;
import java.util.List;

/** Test CLI application. */
public final class Main {

  private Main() {}

  /** Main entry point. */
  public static void main(String[] args) {
    List list = new ArrayList();
    System.out.println("Hello from test-cli-project! " + list.size());
  }
}
