package main
import "core:fmt"
import "rational"

// TODO support comment

VariableType :: enum {
	Matrix,
	Rational,
}

Variable :: struct {
	type: VariableType,
	rnum: rational.Rational,
	m:    ^rational.RationalMatrix,
}

clone_variable :: proc(v: Variable, allocator := context.allocator) -> ^Variable {
	nv := new(Variable, allocator)
	nv.type = v.type
	switch v.type {
	case .Matrix:
		nv.m = rational.clone_matrix(v.m, allocator)
	case .Rational:
		nv.rnum = v.rnum
	}
	return nv
}

free_variable :: proc(v: ^Variable) {
	if v == nil {
		return
	}
	if v.type == .Matrix {
		rational.free_matrix(v.m)
	}
	free(v)
}

print_variable :: proc(v: ^Variable) {
	switch v.type {
	case .Matrix:
		rational.print_matrix(v.m)
	case .Rational:
		fmt.printfln("%s", rational.to_string(v.rnum, allocator = context.temp_allocator))
	}
}

TokenType :: enum {
	EOF,
	Rational,
	Assign,
	Variable,
	ToDeciaml,
	Add,
	Sub,
	Mul,
	Div,
	RREF,
	Print,
	Pop,
}

Token :: struct {
	type: TokenType,
	rnum: rational.Rational,
	name: u8,
	row:  int,
	col:  int,
}

print_token :: proc(tk: Token) {
	defer free_all(context.temp_allocator)
	switch tk.type {
	case .EOF, .Add, .Sub, .Mul, .Div, .RREF, .Print, .Pop, .ToDeciaml:
		fmt.printfln("Token{{type=\"%s\"}}", tk.type)
	case .Rational:
		fmt.printfln(
			"Token{{type=\"%s\",rnum=\"%s\"}}",
			tk.type,
			rational.to_string(tk.rnum, allocator = context.temp_allocator),
		)
	case .Variable:
		fmt.printfln("Token{{type=\"%s\",name=\"%c\"}}", tk.type, tk.name)
	case .Assign:
		fmt.printfln(
			"Token{{type=\"%s\",name=\"%c\",row=\"%d\",col=\"%d\"}}",
			tk.type,
			tk.name,
			tk.row,
			tk.col,
		)
	}
}
