package main
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import "reader"

// Odin runs a thread for every @(test) procedure.
// But variableStack is global.
// Problem arises even with -define:ODIN_TEST_THREADS=1.
// So have to put everything in one procedure.

@(test)
test :: proc(t: ^testing.T) {
	// comment
	check(t, "# this is a comment", "")

	// init
	check(t, "0", "0")
	check(t, "+0", "0")
	check(t, "-0", "0")
	check(t, "12", "12")
	check(t, "+12", "12")
	check(t, "-12", "-12")
	check(t, "13/22", "13/22")
	check(t, "+13/22", "13/22")
	check(t, "-13/22", "-13/22")
	check(t, "2/4", "1/2")
	check(t, "-2/4", "-1/2")

	// add
	check(t, "1/2  1/2   +", "1")
	check(t, "1/2  -1/2  +", "0")
	check(t, "1/2  1/3   +", "5/6")

	// sub
	check(t, "1/2  1/2   -", "0")
	check(t, "1/2  -1/2  -", "1")
	check(t, "1/2  1/3   -", "1/6")

	// mul
	check(t, "2/7  7/18   *", "1/9")
	check(t, "2/7  -7/18  *", "-1/9")
	check(t, "1/2  0      *", "0")

	// div
	check(t, "2/7   18/7  /", "1/9")
	check(t, "-2/7  18/7  /", "-1/9")
	check(t, "0 1 /", "0")
	check(t, "1 0 /", `Error at line #1: Token{type="Div"} DivideByZero`)

	// to_decimal
	check(t, "0 to_decimal", "0")
	check(t, "42 to_decimal", "42")
	check(t, "9/8 to_decimal", "1.125")
	check(t, "1/3 to_decimal", "0.(3)")
	check(t, "1/7 to_decimal", "0.(142857)")
	check(t, "17/12 to_decimal", "1.41(6)")
	check(t, "5/28 to_decimal", "0.17(857142)")

	// martix init
	check(t, "0 =(1)", "Matrix(1,1)\n0")
	check(t, "1 2 =(1,2)", "Matrix(1,2)\n1\t2")
	check(t, "1 2 =(2,1)", "Matrix(2,1)\n1\n2")
	check(t, "1 2 3 4 =(2)", "Matrix(2,2)\n1\t2\n3\t4")
	check(
		t,
		"1 =(2) popq",
		`Error at line #1: Token{type="Assign",row="2",col="2"} OperandsNotEnough`,
	)

	// martix add
	check(t, "1 2 3 4 =(2) 5 4 3 2 =(2) +", "Matrix(2,2)\n6\t6\n6\t6")
	check(
		t,
		"1 2 3 4 =(2) 5 4 =(2,1) +",
		`Error at line #1: Token{type="Add"} MatrixMismatchShape`,
	)

	// martix sub
	check(t, "1 2 3 4 =(2) 5 4 3 2 =(2) -", "Matrix(2,2)\n-4\t-2\n0\t2")
	check(
		t,
		"1 2 3 4 =(2) 5 4 =(2,1) -",
		`Error at line #1: Token{type="Sub"} MatrixMismatchShape`,
	)

	// martix mul
	check(t, "1 2 3 4 5 6 =(2,3) 7 8 9 =(3,1) *", "Matrix(2,1)\n50\n122")
	check(
		t,
		"1 2 3 4 5 6 =(2,3) 7 8 =(2,1) *",
		`Error at line #1: Token{type="Mul"} MatrixMismatchShape`,
	)

	// martix mul rational
	check(t, "1 2 3 4 =(2) 2 *", "Matrix(2,2)\n2\t4\n6\t8")

	// martix rref
	check(t, "1 2 3 4 1 6 =(2,3) ref", "Matrix(2,3)\n1\t0\t9/7\n0\t1\t6/7")

	// martix inverse
	input := `1 1 1 1 2 3 1 4 5 =(3,3) inv`
	output := `Matrix(3,3)
1	1/2	-1/2
1	-2	1
-1	3/2	-1/2`


	check(t, input, output)

	input = `1 1 1 2 2 2 1 4 5 =(3,3) inv`
	check(t, input, `Error at line #1: Token{type="Inverse"} MatrixNotInvertible`)

	// named variable
	check(t, "1 =a 2 =b $a $b /", "1/2")
	check(t, "1 2 3 4 5 6 =A(2,3) 7 8 9 =B(3,1) $A $B *", "Matrix(2,1)\n50\n122")
}

@(private)
check :: proc(t: ^testing.T, input, want: string) {
	inBuf: [256]u8
	outBuf: [256]u8

	sr := strings.Reader{}
	strings.reader_init(&sr, input)
	ir: reader.Reader
	reader.init(&ir, strings.reader_to_stream(&sr), inBuf[:])

	sb := strings.builder_from_slice(outBuf[:])
	output = strings.to_writer(&sb)

	process(&ir)
	got := strings.trim_space(fmt.sbprint(&sb))
	testing.expect_value(t, got, want)

	for v in variableStack {
		free_variable(v)
	}
	clear(&variableStack)

	for _, v in variableMap {
		free_variable(v)
	}
	clear(&variableMap)
}
