# C vs Rust FFI vs Rust Port - IR Comparison Project

## Project Structure

```
ir-comparison/
├── Cargo.toml
├── build.rs
├── c_src/
│   ├── math_ops.c
│   └── math_ops.h
├── src/
│   ├── lib.rs
│   ├── c_wrapper.rs
│   └── rust_port.rs
├── benches/
│   └── comparison.rs
└── scripts/
    ├── generate_ir.sh
    └── compare.sh
```

## Files

### `Cargo.toml`

```toml
[package]
name = "ir-comparison"
version = "0.1.0"
edition = "2021"

[dependencies]

[build-dependencies]
bindgen = "0.70"
cc = "1.0"

[lib]
crate-type = ["lib", "staticlib"]

[[bench]]
name = "comparison"
harness = false
```

### `c_src/math_ops.h`

```c
#ifndef MATH_OPS_H
#define MATH_OPS_H

#include <stdint.h>
#include <stdbool.h>

// Simple mathematical operations for comparison
int32_t factorial(int32_t n);
double vector_dot_product(const double* a, const double* b, size_t len);
bool is_prime(uint32_t n);
void matrix_multiply_2x2(const double a[4], const double b[4], double result[4]);

#endif
```

### `c_src/math_ops.c`

```c
#include "math_ops.h"
#include <math.h>

int32_t factorial(int32_t n) {
    if (n <= 1) return 1;
    int32_t result = 1;
    for (int32_t i = 2; i <= n; i++) {
        result *= i;
    }
    return result;
}

double vector_dot_product(const double* a, const double* b, size_t len) {
    double sum = 0.0;
    for (size_t i = 0; i < len; i++) {
        sum += a[i] * b[i];
    }
    return sum;
}

bool is_prime(uint32_t n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    
    for (uint32_t i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0) {
            return false;
        }
    }
    return true;
}

void matrix_multiply_2x2(const double a[4], const double b[4], double result[4]) {
    result[0] = a[0] * b[0] + a[1] * b[2];
    result[1] = a[0] * b[1] + a[1] * b[3];
    result[2] = a[2] * b[0] + a[3] * b[2];
    result[3] = a[2] * b[1] + a[3] * b[3];
}
```

### `build.rs`

```rust
use std::env;
use std::path::PathBuf;

fn main() {
    // Compile C source
    cc::Build::new()
        .file("c_src/math_ops.c")
        .opt_level(2)
        .flag("-fPIC")
        .compile("math_ops");

    // Generate bindings
    let bindings = bindgen::Builder::default()
        .header("c_src/math_ops.h")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate()
        .expect("Unable to generate bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");

    println!("cargo:rerun-if-changed=c_src/math_ops.c");
    println!("cargo:rerun-if-changed=c_src/math_ops.h");
}
```

### `src/lib.rs`

```rust
pub mod c_wrapper;
pub mod rust_port;

// Re-export for easy access
pub use c_wrapper as c_ffi;
pub use rust_port as native;
```

### `src/c_wrapper.rs`

```rust
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]
#![allow(dead_code)]

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

// Safe wrapper functions
pub fn factorial_safe(n: i32) -> i32 {
    unsafe { factorial(n) }
}

pub fn vector_dot_product_safe(a: &[f64], b: &[f64]) -> f64 {
    assert_eq!(a.len(), b.len());
    unsafe { vector_dot_product(a.as_ptr(), b.as_ptr(), a.len()) }
}

pub fn is_prime_safe(n: u32) -> bool {
    unsafe { is_prime(n) }
}

pub fn matrix_multiply_2x2_safe(a: &[f64; 4], b: &[f64; 4]) -> [f64; 4] {
    let mut result = [0.0; 4];
    unsafe {
        matrix_multiply_2x2(a.as_ptr(), b.as_ptr(), result.as_mut_ptr());
    }
    result
}
```

### `src/rust_port.rs`

```rust
pub fn factorial(n: i32) -> i32 {
    if n <= 1 {
        return 1;
    }
    let mut result = 1;
    for i in 2..=n {
        result *= i;
    }
    result
}

pub fn vector_dot_product(a: &[f64], b: &[f64]) -> f64 {
    assert_eq!(a.len(), b.len());
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

pub fn is_prime(n: u32) -> bool {
    if n <= 1 {
        return false;
    }
    if n <= 3 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }
    
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 {
            return false;
        }
        i += 6;
    }
    true
}

pub fn matrix_multiply_2x2(a: &[f64; 4], b: &[f64; 4]) -> [f64; 4] {
    [
        a[0] * b[0] + a[1] * b[2],
        a[0] * b[1] + a[1] * b[3],
        a[2] * b[0] + a[3] * b[2],
        a[2] * b[1] + a[3] * b[3],
    ]
}
```

### `scripts/generate_ir.sh`

```bash
#!/bin/bash

set -e

echo "Generating intermediate representations..."

# Create output directory
mkdir -p ir_output

# Compile C source to LLVM IR and assembly
echo "=== C Source ==="
clang -S -emit-llvm -O2 -o ir_output/math_ops.ll c_src/math_ops.h
clang -S -O2 -o ir_output/math_ops.s c_src/math_ops.h
echo "Generated: ir_output/math_ops.ll and ir_output/math_ops.s"

# Build Rust and generate IR
echo "=== Rust (FFI wrapper and native port) ==="
cargo rustc --release --lib -- --emit=llvm-ir,asm

# Copy generated files to output directory
RUST_TARGET="target/release/deps"
LIB_NAME=$(cargo metadata --no-deps --format-version 1 | grep -oP '"name":"\K[^"]+' | head -1| tr '-' '_')

# Find the generated files
find target/release/deps -name "${LIB_NAME}*.ll" -exec cp {} ir_output/rust_full.ll \;
find target/release/deps -name "${LIB_NAME}*.s" -exec cp {} ir_output/rust_full.s \;

echo "Generated: ir_output/rust_full.ll and ir_output/rust_full.s"

# Generate IR for specific optimization levels
for opt in 0 1 2 3; do
    echo "Generating C with -O${opt}..."
    clang -S -emit-llvm -O${opt} -o ir_output/math_ops_O${opt}.ll c_src/math_ops.c
    clang -S -O${opt} -o ir_output/math_ops_O${opt}.s c_src/math_ops.c
done

echo ""
echo "All IR files generated in ir_output/"
echo ""
echo "Key files:"
echo "  - ir_output/math_ops.ll       : C LLVM IR (O2)"
echo "  - ir_output/math_ops.s        : C Assembly (O2)"
echo "  - ir_output/rust_full.ll      : Rust LLVM IR (release)"
echo "  - ir_output/rust_full.s       : Rust Assembly (release)"
```

### `scripts/compare.sh`

```bash
#!/bin/bash

echo "=== IR Comparison Analysis ==="
echo ""

if [ ! -d "ir_output" ]; then
    echo "IR files not found. Run ./scripts/generate_ir.sh first."
    exit 1
fi

echo "File sizes:"
ls -lh ir_output/*.ll | awk '{print $9, $5}'
echo ""

echo "Instruction counts in LLVM IR:"
for file in ir_output/*.ll; do
    count=$(grep -c "^  " "$file" || echo "0")
    echo "  $(basename $file): $count instructions"
done
echo ""

echo "Function definitions in C IR:"
grep "define" ir_output/math_ops.ll
echo ""

echo "Looking for factorial function in Rust IR:"
grep -A 20 "factorial" ir_output/rust_full.ll | head -25 || echo "Not found or inlined"
echo ""

echo "Assembly comparison (factorial function):"
echo "--- C version ---"
grep -A 15 "factorial:" ir_output/math_ops.s | head -20 || echo "Not found"
echo ""
echo "--- Rust version ---"
grep -A 15 "factorial" ir_output/rust_full.s | head -20 || echo "Not found or inlined"
```

## Usage

1. **Setup the project:**
   ```bash
   chmod +x scripts/*.sh
   cargo build --release
   ```

2. **Generate IR files:**
   ```bash
   ./scripts/generate_ir.sh
   ```

3. **Compare outputs:**
   ```bash
   ./scripts/compare.sh
   ```

4. **Manual inspection:**
   - Open files in `ir_output/` directory
   - Compare `math_ops.ll` (C) with `rust_full.ll`
   - Look for specific functions using grep
   - Use `llvm-dis` or `llvm-as` for further analysis

5. **View specific function IR:**
   ```bash
   grep -A 30 "define.*factorial" ir_output/math_ops.ll
   grep -A 30 "factorial" ir_output/rust_full.ll
   ```

## What to Look For

1. **Inlining**: Rust may inline more aggressively
2. **Bounds checking**: Rust adds safety checks
3. **Calling conventions**: FFI boundaries add overhead
4. **Optimization patterns**: Different compilers optimize differently
5. **SIMD usage**: Look for vector instructions
6. **Stack layout**: Compare stack frame setup

## Additional Analysis Tools

```bash
# Compare optimized vs unoptimized
diff -u ir_output/math_ops_O0.ll ir_output/math_ops_O2.ll

# Count specific instruction types
grep "mul" ir_output/math_ops.ll | wc -l

# Extract just function names
grep "define" ir_output/*.ll
```