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
