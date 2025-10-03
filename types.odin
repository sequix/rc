package main
import "core:fmt"
import "rational"

Error :: union {
	MainError,
	rational.Error,
}

MainError :: enum {
	None,
	OperandsNotEnough,
	VariableNotAssigned,
	ExpectedRational,
	ExpectedMatrix,
	ExpectedSameType,
}

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
	Inverse,
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

token_to_string :: proc(tk: Token, allocator := context.allocator) -> string {
	#partial switch tk.type {
	case .Rational:
		return fmt.aprintf(
			"Token{{type=\"%s\",rnum=\"%s\"}}",
			tk.type,
			rational.to_string(tk.rnum, allocator = allocator),
			allocator = allocator,
		)
	case .Variable:
		return fmt.aprintf(
			"Token{{type=\"%s\",name=\"%c\"}}",
			tk.type,
			tk.name,
			allocator = allocator,
		)
	case .Assign:
		return fmt.aprintf(
			"Token{{type=\"%s\",name=\"%c\",row=\"%d\",col=\"%d\"}}",
			tk.type,
			tk.name,
			tk.row,
			tk.col,
			allocator = allocator,
		)
	case:
		return fmt.aprintf("Token{{type=\"%s\"}}", tk.type, allocator = context.temp_allocator)
	}
	return "unreachable"
}
