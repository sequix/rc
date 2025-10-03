package main
import "core:fmt"
import "core:os"
import "core:strconv"
import "rational"
import "reader"

// [a-zA-Z] -> Variable
variableMap: map[u8]^Variable
variableStack: [dynamic]^Variable

main :: proc() {
	if len(os.args) > 2 {
		fmt.printfln("usage: %s [filename]", os.args[0])
		os.exit(1)
	}

	input := os.stdin
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
	err: Error
	tk: Token
	reader.init(&r, os.stream_from_handle(input), buf[:])

	mainLoop: for {
		tk = next_token(&r)
		switch tk.type {
		case .EOF:
			op_print()
			break mainLoop
		case .Print:
			op_print()
		case .Rational:
			op_rational(tk)
		case .Pop:
			err = op_pop()
		case .ToDeciaml:
			err = op_to_decimal()
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
			print_error(&r, tk, err)
			os.exit(1)
		}
	}
}

print_error :: proc(r: ^reader.Reader, tk: Token, err: Error) {
	defer free_all(context.temp_allocator)
	ts := token_to_string(tk, allocator = context.temp_allocator)
	fmt.eprintfln("Error at line #%d: %s %s", r.lno, ts, err)
}

op_print :: proc() {
	defer free_all(context.temp_allocator)
	if len(variableStack) > 1 {
		fmt.printf("stack(%d): ", len(variableStack))
		for v in variableStack {
			//fmt.printf("%s", typeid_of(type_of(v)))
			switch v.type {
			case .Matrix:
				fmt.printf("%s ", rational.matrix_to_string(v.m, context.temp_allocator))
			case .Rational:
				fmt.printf("%s ", rational.to_string(v.rnum, allocator = context.temp_allocator))
			}
		}
		fmt.println()
		return
	}
	if len(variableStack) == 1 {
		print_variable(variableStack[0])
	}
}

op_pop :: proc() -> Error {
	if len(variableStack) == 0 {
		return .OperandsNotEnough
	}
	v := pop(&variableStack)
	defer free(v)
	print_variable(v)
	return nil
}

op_to_decimal :: proc() -> Error {
	if len(variableStack) == 0 {
		return .OperandsNotEnough
	}
	v := pop(&variableStack)
	defer free(v)
	defer free_all(context.temp_allocator)
	if v.type != .Rational {
		return .ExpectedRational
	}
	fmt.println(rational.to_string(v.rnum, decimal = true, allocator = context.temp_allocator))
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
		variableMap[tk.name] = nv
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
	//rational.print_matrix(m)
	nv := new(Variable)
	nv.type = .Matrix
	nv.m = m
	variableMap[tk.name] = nv
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
	nv.rnum = rational.div(a.rnum, b.rnum)
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
