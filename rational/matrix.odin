package rational
import "core:fmt"
import "core:slice"
import "core:strings"

Error :: enum {
	None,
	MatrixMismatchShape,
	MatrixNotInvertible,
	MatrixNotSquare,
	DivideByZero,
}

// row-major layout
RationalMatrix :: struct {
	m:   [][]Rational,
	row: int,
	col: int,
}

new_matrix :: proc(row, col: int, allocator := context.allocator) -> ^RationalMatrix {
	m := new(RationalMatrix, allocator)
	m.row = row
	m.col = col
	m.m = make([][]Rational, row, allocator)
	for c in 0 ..< row {
		m.m[c] = make([]Rational, col, allocator)
		for r in 0 ..< col {
			m.m[c][r].den = 1
		}
	}
	return m
}

free_matrix :: proc(m: ^RationalMatrix) {
	if m == nil {
		return
	}
	for r in 0 ..< m.row {
		delete(m.m[r])
	}
	delete(m.m)
	free(m)
}

clone_matrix :: proc(a: ^RationalMatrix, allocator := context.allocator) -> ^RationalMatrix {
	r := new_matrix(a.row, a.col, allocator)
	for i in 0 ..< r.row {
		for j in 0 ..< r.col {
			r.m[i][j] = a.m[i][j]
		}
	}
	return r
}

matrix_to_string :: proc(
	a: ^RationalMatrix,
	single_line := true,
	decimal := false,
	allocator := context.allocator,
) -> string {
	sb: strings.Builder
	strings.builder_init_len_cap(&sb, 0, 128, allocator = allocator)

	if single_line {
		fmt.sbprintf(&sb, "Matrix(%d,%d){{", a.row, a.col)
		for i in 0 ..< a.row {
			fmt.sbprint(&sb, to_string(a.m[i][0], decimal = decimal, allocator = allocator))
			for j in 1 ..< a.col {
				fmt.sbprintf(
					&sb,
					",%s",
					to_string(a.m[i][j], decimal = decimal, allocator = allocator),
				)
			}
			if i < a.row - 1 {
				fmt.sbprint(&sb, ";")
			}
		}
		return fmt.sbprint(&sb, "}")
	}

	fmt.sbprintfln(&sb, "Matrix(%d,%d)", a.row, a.col)
	for i in 0 ..< a.row {
		fmt.sbprintf(&sb, "%s", to_string(a.m[i][0], decimal = decimal, allocator = allocator))
		for j in 1 ..< a.col {
			fmt.sbprintf(
				&sb,
				"\t%s",
				to_string(a.m[i][j], decimal = decimal, allocator = allocator),
			)
		}
		fmt.sbprintln(&sb)
	}
	return fmt.sbprint(&sb)
}

matrix_add :: proc(
	a, b: ^RationalMatrix,
	allocator := context.allocator,
) -> (
	^RationalMatrix,
	Error,
) {
	if a.row != b.row || a.col != b.col {
		return nil, .MatrixMismatchShape
	}
	r := new_matrix(a.row, a.col, allocator)
	for i in 0 ..< r.row {
		for j in 0 ..< r.col {
			r.m[i][j] = add(a.m[i][j], b.m[i][j])
		}
	}
	return r, nil
}

matrix_sub :: proc(
	a, b: ^RationalMatrix,
	allocator := context.allocator,
) -> (
	^RationalMatrix,
	Error,
) {
	if a.row != b.row || a.col != b.col {
		return nil, .MatrixMismatchShape
	}
	r := new_matrix(a.row, a.col, allocator)
	for i in 0 ..< r.row {
		for j in 0 ..< r.col {
			r.m[i][j] = sub(a.m[i][j], b.m[i][j])
		}
	}
	return r, nil
}

matrix_mul :: proc(
	a, b: ^RationalMatrix,
	allocator := context.allocator,
) -> (
	^RationalMatrix,
	Error,
) {
	if a.col != b.row {
		return nil, .MatrixMismatchShape
	}
	r := new_matrix(a.row, b.col, allocator)
	for i in 0 ..< r.row {
		for j in 0 ..< r.col {
			for k in 0 ..< a.col {
				t := mul(a.m[i][k], b.m[k][j])
				r.m[i][j] = add(r.m[i][j], t)
			}
		}
	}
	return r, nil
}

matrix_mul_rational :: proc(
	a: ^RationalMatrix,
	b: Rational,
	allocator := context.allocator,
) -> ^RationalMatrix {
	r := clone_matrix(a)
	for i in 0 ..< r.row {
		for j in 0 ..< r.col {
			r.m[i][j] = mul(r.m[i][j], b)
		}
	}
	return r
}

matrix_rref_in_place :: proc(a: ^RationalMatrix) {
	r := 0
	c := 0
	for ; r < a.row && c < a.col; r, c = r + 1, c + 1 {
		// find frist row with non-zero
		rn0 := -1
		for ri := r; ri < a.row; ri += 1 {
			if a.m[ri][c].num != 0 {
				rn0 = ri
				break
			}
		}
		if rn0 == -1 {
			continue
		}
		// make m[r][c] non-zero by swapping rows
		if rn0 != r {
			a.m[rn0], a.m[r] = a.m[r], a.m[rn0]
		}
		// make m[r][c] 1 by divide row with m[r][c]
		cof := a.m[r][c]
		a.m[r][c] = Rational{1, 1}
		for ci := c + 1; ci < a.col; ci += 1 {
			a.m[r][ci], _ = div(a.m[r][ci], cof)
		}
		// make following row current column 0
		for ri := r + 1; ri < a.row; ri += 1 {
			cof := a.m[ri][c]
			if cof.num != 0 {
				a.m[ri][c] = Rational{0, 1}
				for ci := c + 1; ci < a.col; ci += 1 {
					t := mul(a.m[r][ci], cof)
					a.m[ri][ci] = sub(a.m[ri][ci], t)
				}
			}
		}
	}
	for r = a.row - 1; r >= 0; r -= 1 {
		for c = 0; c < a.col; c += 1 {
			if a.m[r][c].num != 0 {
				break
			}
		}
		if c == a.col {
			continue
		}
		for ri := r - 1; ri >= 0; ri -= 1 {
			cof := a.m[ri][c]
			if cof.num != 0 {
				a.m[ri][c] = Rational{0, 1}
				for ci := c + 1; ci < a.col; ci += 1 {
					t := mul(a.m[r][ci], cof)
					a.m[ri][ci] = sub(a.m[ri][ci], t)
				}
			}
		}
	}
}

matrix_rref :: proc(a: ^RationalMatrix, allocator := context.allocator) -> ^RationalMatrix {
	b := clone_matrix(a)
	matrix_rref_in_place(b)
	return b
}

matrix_inverse :: proc(
	a: ^RationalMatrix,
	allocator := context.allocator,
) -> (
	^RationalMatrix,
	Error,
) {
	if a.row != a.col {
		return nil, .MatrixNotSquare
	}
	t := new_matrix(a.row, a.col << 1, allocator = allocator)
	defer free_matrix(t)

	for r in 0 ..< a.row {
		for c in 0 ..< a.col {
			t.m[r][c] = a.m[r][c]
		}
		t.m[r][r + a.col] = Rational{1, 1}
	}
	matrix_rref_in_place(t)

	for r in 0 ..< a.row {
		for c in 0 ..< a.col {
			if r != c {
				if t.m[r][c].num != 0 {
					return nil, .MatrixNotInvertible
				}
			} else {
				if cmp(t.m[r][c], Rational{1, 1}) != 0 {
					return nil, .MatrixNotInvertible
				}
			}
		}
	}
	ret := new_matrix(a.row, a.col, allocator = allocator)
	for r in 0 ..< ret.row {
		for c in 0 ..< ret.col {
			ret.m[r][c] = t.m[r][c + ret.col]
		}
	}
	return ret, nil
}

matrix_determinant :: proc(a: ^RationalMatrix) -> (Rational, Error) {
	if a.row != a.col {
		return {}, .MatrixNotSquare
	}
	sign := Rational{1, 1}
	t := clone_matrix(a)
	defer free_matrix(t)

	for k := 0; k < t.row; k += 1 {
		// find frist row with non-zero
		rn0 := -1
		for ri := k; ri < t.row; ri += 1 {
			if t.m[ri][k].num != 0 {
				rn0 = ri
				break
			}
		}
		if rn0 == -1 {
			return {0, 1}, nil
		}
		// make m[r][c] non-zero by swapping rows
		if rn0 != k {
			t.m[rn0], t.m[k] = t.m[k], t.m[rn0]
			sign.num = -sign.num
		}
		// make following row current column 0
		for ri := k + 1; ri < t.row; ri += 1 {
			if t.m[ri][k].num == 0 {
				continue
			}
			cof, _ := div(t.m[ri][k], t.m[k][k])
			t.m[ri][k] = Rational{0, 1}
			for ci := k + 1; ci < t.col; ci += 1 {
				tr := mul(t.m[k][ci], cof)
				t.m[ri][ci] = sub(t.m[ri][ci], tr)
			}
		}
	}

	det := Rational{1, 1}
	for k := 0; k < t.row; k += 1 {
		det = mul(det, t.m[k][k])
	}
	return mul(det, sign), nil
}
