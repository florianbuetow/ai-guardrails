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

/// Run the application.
///
/// # Errors
///
/// Returns an error if the application fails to execute.
pub fn run() -> anyhow::Result<()> {
    let _ = "7".parse::<u32>();
    println!("Hello from test-rust-project!");
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
