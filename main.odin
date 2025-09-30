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
		input, err = os.open(os.args[1], os.O_RDONLY)
		if err != nil {
			fmt.eprintfln("failed to open %s: %s", os.args[1], os.error_string(err))
			os.exit(1)
		}
	}
	defer os.close(input)

	r: reader.Reader
	buf: [1024]u8
	reader.init(&r, os.stream_from_handle(input), buf[:])

	mainLoop: for {
		tk := next_token(&r)
		//print_token(tk)
		switch tk.type {
		case .EOF:
			op_print()
			break mainLoop
		case .Pop:
			op_pop()
		case .Rational:
			op_rational(tk)
		case .Variable:
			op_variable(tk)
		case .Assign:
			op_assign(tk)
		case .Add:
			op_add()
		case .Sub:
			op_sub()
		case .Mul:
			op_mul()
		case .Div:
			op_div()
		case .RREF:
			op_rref()
		case .Print:
			op_print()
		}
	}
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
				fmt.printf("%s ", rational.to_string(v.rnum, context.temp_allocator))
			}
		}
		fmt.println()
		return
	}
	if len(variableStack) == 1 {
		print_variable(variableStack[0])
	}
}

op_pop :: proc() {
	v := pop(&variableStack)
	defer free(v)
	print_variable(v)
}

op_rational :: proc(tk: Token) {
	v := new(Variable)
	v.type = .Rational
	v.rnum = tk.rnum
	append(&variableStack, v)
}

op_variable :: proc(tk: Token) {
	v := variableMap[tk.name]
	if v == nil {
		fmt.eprintfln("variable '%c' not assigned", tk.name)
		os.exit(1)
	}
	cv := clone_variable(v^)
	append(&variableStack, cv)
}

op_assign :: proc(tk: Token) {
	if len(variableStack) == 0 {
		fmt.eprintfln("cannot assign from empty stack")
		os.exit(1)
	}

	// =X
	if tk.row == 0 {
		pv := pop(&variableStack)
		defer free_variable(pv)
		nv := clone_variable(pv^)
		variableMap[tk.name] = nv
		return
	}

	// =X(r,c)
	if len(variableStack) < tk.row * tk.col {
		fmt.eprintfln("expected %dx%d elements", tk.row, tk.col)
		os.exit(1)
	}
	m := rational.new_matrix(tk.row, tk.col)
	for i := tk.row - 1; i >= 0; i -= 1 {
		for j := tk.col - 1; j >= 0; j -= 1 {
			v := pop(&variableStack)
			defer free_variable(v)
			if v.type != .Rational {
				fmt.eprintfln("expected rational number for matrix got %s", v.type)
				os.exit(1)
			}
			m.m[i][j] = v.rnum
		}
	}
	//rational.print_matrix(m)
	nv := new(Variable)
	nv.type = .Matrix
	nv.m = m
	variableMap[tk.name] = nv
	return
}

op_add :: proc() {
	if len(variableStack) < 2 {
		fmt.eprintln("expected at least 2 elements")
		os.exit(1)
	}
	b := pop(&variableStack)
	a := pop(&variableStack)
	defer free_variable(a)
	defer free_variable(b)
	if a.type != b.type {
		fmt.eprintln("expected same type for '+'")
		os.exit(1)
	}
	nv := new(Variable)
	nv.type = a.type
	switch a.type {
	case .Rational:
		nv.rnum = rational.add(a.rnum, b.rnum)
	case .Matrix:
		nv.m = rational.matrix_add(a.m, b.m)
	}
	append(&variableStack, nv)
}

op_sub :: proc() {
	if len(variableStack) < 2 {
		fmt.eprintln("expected at least 2 elements")
		os.exit(1)
	}
	b := pop(&variableStack)
	a := pop(&variableStack)
	defer free_variable(a)
	defer free_variable(b)
	if a.type != b.type {
		fmt.eprintln("expected same type for '-'")
		os.exit(1)
	}
	nv := new(Variable)
	nv.type = a.type
	switch a.type {
	case .Rational:
		nv.rnum = rational.sub(a.rnum, b.rnum)
	case .Matrix:
		nv.m = rational.matrix_sub(a.m, b.m)
	}
	append(&variableStack, nv)
}

op_mul :: proc() {
	if len(variableStack) < 2 {
		fmt.eprintln("expected at least 2 elements")
		os.exit(1)
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
			nv.m = rational.matrix_mul(a.m, b.m)
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
}

op_div :: proc() {
	if len(variableStack) < 2 {
		fmt.eprintln("expected at least 2 elements")
		os.exit(1)
	}
	b := pop(&variableStack)
	a := pop(&variableStack)
	defer free_variable(a)
	defer free_variable(b)
	if a.type != b.type {
		fmt.eprintln("expected same type for '-'")
		os.exit(1)
	}
	if a.type == .Matrix {
		fmt.eprintfln("expected rationals for '/'")
		os.exit(1)
	}
	nv := new(Variable)
	nv.type = .Rational
	nv.rnum = rational.div(a.rnum, b.rnum)
	append(&variableStack, nv)
}

op_rref :: proc() {
	if len(variableStack) < 1 {
		fmt.eprintln("expected at least 1 elements")
		os.exit(1)
	}
	a := pop(&variableStack)
	defer free_variable(a)
	if a.type != .Matrix {
		fmt.eprintfln("expected matrix for RREF")
		os.exit(1)
	}
	nv := new(Variable)
	nv.type = .Matrix
	nv.m = rational.matrix_rref(a.m)
	append(&variableStack, nv)
}
