//! Test violation: unsafe code usage.
#![forbid(unsafe_code)]
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
    let x: i32 = unsafe { std::mem::zeroed() };
    println!("Hello with unsafe value: {x}!");
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
