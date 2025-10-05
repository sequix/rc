package main
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import "reader"

@(test)
test_comment :: proc(t: ^testing.T) {
	check(t, "# this is a comment", "")
}

@(test)
test_rational :: proc(t: ^testing.T) {
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

	// decimal format
	check(t, ".", "0")
	check(t, "-.", "0")
	check(t, "+.", "0")
	check(t, ".(3)", "1/3")
	check(t, "+.(3)", "1/3")
	check(t, "-.(3)", "-1/3")
	check(t, "12.34(56)", "61111/4950")
	check(t, "+12.34(56)", "61111/4950")
	check(t, "-12.34(56)", "-61111/4950")

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
	check(t, "1 0 /", `Error at line #1: DivideByZero`)

	// popd
	check(t, "0 popd", "0")
	check(t, "42 popd", "42")
	check(t, "9/8 popd", "1.125")
	check(t, "1/3 popd", "0.(3)")
	check(t, "1/7 popd", "0.(142857)")
	check(t, "17/12 popd", "1.41(6)")
	check(t, "5/28 popd", "0.17(857142)")
}

@(test)
test_matrix :: proc(t: ^testing.T) {
	// martix init
	check(t, "0 =(1)", "Matrix(1,1)\n0")
	check(t, "1 2 =(1,2)", "Matrix(1,2)\n1\t2")
	check(t, "1 2 =(2,1)", "Matrix(2,1)\n1\n2")
	check(t, "1 2 3 4 =(2)", "Matrix(2,2)\n1\t2\n3\t4")
	check(t, "1 =(2) popq", `Error at line #1: OperandsNotEnough`)

	// martix add
	check(t, "1 2 3 4 =(2) 5 4 3 2 =(2) +", "Matrix(2,2)\n6\t6\n6\t6")
	check(t, "1 2 3 4 =(2) 5 4 =(2,1) +", `Error at line #1: MatrixMismatchShape`)

	// martix sub
	check(t, "1 2 3 4 =(2) 5 4 3 2 =(2) -", "Matrix(2,2)\n-4\t-2\n0\t2")
	check(t, "1 2 3 4 =(2) 5 4 =(2,1) -", `Error at line #1: MatrixMismatchShape`)

	// martix mul
	check(t, "1 2 3 4 5 6 =(2,3) 7 8 9 =(3,1) *", "Matrix(2,1)\n50\n122")
	check(t, "1 2 3 4 5 6 =(2,3) 7 8 =(2,1) *", `Error at line #1: MatrixMismatchShape`)

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

	input = `# Hilbert Matrix
1 1/2 1/3 1/4 1/5
1/2 1/3 1/4 1/5 1/6
1/3 1/4 1/5 1/6 1/7
1/4 1/5 1/6 1/7 1/8
1/5 1/6 1/7 1/8 1/9
=(5) inv`


	output = `Matrix(5,5)
25	-300	1050	-1400	630
-300	4800	-18900	26880	-12600
1050	-18900	79380	-117600	56700
-1400	26880	-117600	179200	-88200
630	-12600	56700	-88200	44100`


	check(t, input, output)

	input = `1 1 1 2 2 2 1 4 5 =(3,3) inv`
	check(t, input, `Error at line #1: MatrixNotInvertible`)
}

@(test)
test_variable :: proc(t: ^testing.T) {
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
