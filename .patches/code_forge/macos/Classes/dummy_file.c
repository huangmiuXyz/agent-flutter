// This file provides a real exported symbol so CocoaPods can build a valid
// framework with module metadata and Info.plist.
//
// code_forge is an FFI plugin — the actual implementation lives in the
// Rust library (built via cargokit).  This C stub exists solely to satisfy
// CocoaPods framework requirements on macOS / iOS.

#include "code_forge.h"

void code_forge_register(void) {
    // Intentionally empty — see comment above.
}
