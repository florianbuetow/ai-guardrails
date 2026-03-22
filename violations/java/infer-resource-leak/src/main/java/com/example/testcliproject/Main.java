package com.example.testcliproject;

import java.io.FileInputStream;
import java.io.IOException;

/** Test CLI application. */
public final class Main {

  private Main() {}

  /** Main entry point. */
  public static void main(String[] args) throws IOException {
    // Infer detects RESOURCE_LEAK: stream is never closed
    FileInputStream stream = new FileInputStream("/dev/null");
    byte[] data = new byte[1024];
    int bytesRead = stream.read(data);
    System.out.println("Read " + bytesRead + " bytes");
  }
}
