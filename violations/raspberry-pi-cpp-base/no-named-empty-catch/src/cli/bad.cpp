#include <exception>
void bad() { try { throw std::exception{}; } catch (const std::exception& failure) { /* silently ignored */ } }
