package main
import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
import "rational"
import "reader"

output: io.Writer
variableMap: map[u8]^Variable
variableStack: [dynamic]^Variable

main :: proc() {
	if len(os.args) > 2 {
		fmt.printfln("usage: %s [filename]", os.args[0])
		os.exit(1)
	}

	input := os.stdin
	output = os.stream_from_handle(os.stdout)

	if len(os.args) == 2 {
		err: os.Error
		input, err = os.open(os.args[1])
		if err != nil {
			fmt.eprintfln("failed to open %s: %s", os.args[1], os.error_string(err))
			os.exit(1)
		}
	}
	defer os.close(input)

	r: reader.Reader
	buf: [1024]u8
	reader.init(&r, os.stream_from_handle(input), buf[:])
	process(&r)
}

process :: proc(r: ^reader.Reader) {
	tk: Token
	err: Error
	processLoop: for {
		tk = next_token(r)
		switch tk.type {
		case .EOF:
			if len(variableStack) == 1 {
				op_pop()
			}
			if len(variableStack) > 1 {
				op_print_stack()
			}
			clear(&variableStack)
			clear(&variableMap)
			break processLoop
		case .PrintStack:
			op_print_stack()
		case .PrintVars:
			op_print_vars()
		case .Rational:
			op_rational(tk)
		case .PopDecimal:
			err = op_pop(decimal = true)
		case .PopQuietly:
			err = op_pop(print = false)
		case .Pop:
			err = op_pop()
		case .Variable:
			err = op_variable(tk)
		case .Assign:
			err = op_assign(tk)
		case .Add:
			err = op_add()
		case .Sub:
			err = op_sub()
		case .Mul:
			err = op_mul()
		case .Div:
			err = op_div()
		case .RREF:
			err = op_rref()
		case .Inverse:
			err = op_inverse()
		}
		if err != nil {
			print_error(r, err)
			err = nil
		}
	}
}

print_error :: proc(r: ^reader.Reader, err: Error) {
	fmt.wprintfln(output, "Error at line #%d: %s", r.lno, err)
}

op_print_vars :: proc() {
	defer free_all(context.temp_allocator)
	for name, v in variableMap {
		fmt.wprintfln(
			output,
			"%c = %s",
			name,
			variable_to_string(v, allocator = context.temp_allocator),
		)
	}
}

op_print_stack :: proc() {
	defer free_all(context.temp_allocator)
	for v in variableStack {
		fmt.wprintln(output, variable_to_string(v, allocator = context.temp_allocator))
	}
}

op_pop :: proc(decimal := false, print := true) -> Error {
	if len(variableStack) == 0 {
		return .OperandsNotEnough
	}
	v := pop(&variableStack)
	defer free(v)
	if print {
		defer free_all(context.temp_allocator)
		fmt.wprint(
			output,
			variable_to_string(
				v,
				decimal = decimal,
				single_line = false,
				allocator = context.temp_allocator,
			),
		)
	}
	return nil
}

op_rational :: proc(tk: Token) {
	v := new(Variable)
	v.type = .Rational
	v.rnum = tk.rnum
	append(&variableStack, v)
}

op_variable :: proc(tk: Token) -> Error {
	v := variableMap[tk.name]
	if v == nil {
		return .VariableNotAssigned
	}
	cv := clone_variable(v^)
	append(&variableStack, cv)
	return nil
}

op_assign :: proc(tk: Token) -> Error {
	if len(variableStack) == 0 {
		return .OperandsNotEnough
	}

	// =X
	if tk.row == 0 {
		pv := pop(&variableStack)
		defer free_variable(pv)
		nv := clone_variable(pv^)
		if tk.name != 0 {
			variableMap[tk.name] = nv
		} else {
			append(&variableStack, nv)
		}
		return nil
	}

	// =X(r,c)
	if len(variableStack) < tk.row * tk.col {
		return .OperandsNotEnough
	}
	m := rational.new_matrix(tk.row, tk.col)
	for i := tk.row - 1; i >= 0; i -= 1 {
		for j := tk.col - 1; j >= 0; j -= 1 {
			v := pop(&variableStack)
			defer free_variable(v)
			if v.type != .Rational {
				return .ExpectedRational
			}
			m.m[i][j] = v.rnum
		}
	}
	nv := new(Variable)
	nv.type = .Matrix
	nv.m = m
	if tk.name != 0 {
		variableMap[tk.name] = nv
	} else {
		append(&variableStack, nv)
	}
	return nil
}

op_add :: proc() -> Error {
	if len(variableStack) < 2 {
		return .OperandsNotEnough
	}
	b := pop(&variableStack)
	a := pop(&variableStack)
	defer free_variable(a)
	defer free_variable(b)
	if a.type != b.type {
		return .ExpectedSameType
	}
	nv := new(Variable)
	nv.type = a.type
	switch a.type {
	case .Rational:
		nv.rnum = rational.add(a.rnum, b.rnum)
	case .Matrix:
		nv.m = rational.matrix_add(a.m, b.m) or_return
	}
	append(&variableStack, nv)
	return nil
}

op_sub :: proc() -> Error {
	if len(variableStack) < 2 {
		return .OperandsNotEnough
	}
	b := pop(&variableStack)
	a := pop(&variableStack)
	defer free_variable(a)
	defer free_variable(b)
	if a.type != b.type {
		return .ExpectedSameType
	}
	nv := new(Variable)
	nv.type = a.type
	switch a.type {
	case .Rational:
		nv.rnum = rational.sub(a.rnum, b.rnum)
	case .Matrix:
		nv.m = rational.matrix_sub(a.m, b.m) or_return
	}
	append(&variableStack, nv)
	return nil
}

op_mul :: proc() -> Error {
	if len(variableStack) < 2 {
		return .OperandsNotEnough
	}
	b := pop(&variableStack)
	a := pop(&variableStack)
	defer free_variable(a)
	defer free_variable(b)
	nv := new(Variable)
	if a.type == b.type {
		nv.type = a.type
		switch a.type {
		case .Rational:
			nv.rnum = rational.mul(a.rnum, b.rnum)
		case .Matrix:
			nv.m = rational.matrix_mul(a.m, b.m) or_return
		}
	} else {
		nv.type = .Matrix
		if a.type == .Rational {
			nv.m = rational.matrix_mul_rational(b.m, a.rnum)
		} else {
			nv.m = rational.matrix_mul_rational(a.m, b.rnum)
		}
	}
	append(&variableStack, nv)
	return nil
}

op_div :: proc() -> Error {
	if len(variableStack) < 2 {
		return .OperandsNotEnough
	}
	b := pop(&variableStack)
	a := pop(&variableStack)
	defer free_variable(a)
	defer free_variable(b)
	if a.type != b.type {
		return .ExpectedSameType
	}
	if a.type == .Matrix {
		return .ExpectedRational
	}
	nv := new(Variable)
	nv.type = .Rational
	nv.rnum = rational.div(a.rnum, b.rnum) or_return
	append(&variableStack, nv)
	return nil
}

op_rref :: proc() -> Error {
	if len(variableStack) < 1 {
		return .OperandsNotEnough
	}
	a := pop(&variableStack)
	defer free_variable(a)
	if a.type != .Matrix {
		return .ExpectedMatrix
	}
	nv := new(Variable)
	nv.type = .Matrix
	nv.m = rational.matrix_rref(a.m)
	append(&variableStack, nv)
	return nil
}

op_inverse :: proc() -> Error {
	if len(variableStack) == 0 {
		return .OperandsNotEnough
	}
	a := pop(&variableStack)
	defer free_variable(a)
	if a.type != .Matrix {
		return .ExpectedMatrix
	}
	nv := new(Variable)
	nv.type = .Matrix
	nv.m = rational.matrix_inverse(a.m) or_return
	append(&variableStack, nv)
	return nil
}
