//! Test Rust CLI application
#![warn(missing_docs)]

use thiserror::Error;

/// Application-specific errors.
#[derive(Error, Debug)]
pub enum AppError {
    /// An unexpected error occurred.
    #[error("unexpected error: {0}")]
    Unexpected(String),
}

#[allow(dead_code)]
fn helper() -> &'static str {
    "helper"
}

/// Run the application.
///
/// # Errors
///
/// Returns an error if the application fails to execute.
pub fn run() -> anyhow::Result<()> {
    println!("Hello from test-rust-project! {}", helper());
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_run_succeeds() {
        assert!(run().is_ok());
    }
}
