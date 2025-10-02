package rational
import "core:fmt"
import "core:slice"
import "core:strings"

// TODO inverse matrix

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

matrix_to_string :: proc(a: ^RationalMatrix, allocator := context.allocator) -> string {
	sb: strings.Builder
	strings.builder_init_len_cap(&sb, 0, 128, allocator = allocator)
	fmt.sbprintf(&sb, "Matrix(%d,%d){{", a.row, a.col)
	for i in 0 ..< a.row {
		if a.m[i][0].den == 1 {
			fmt.sbprintf(&sb, "%d", a.m[i][0].num)
		} else {
			fmt.sbprintf(&sb, "%d/%d", a.m[i][0].num, a.m[i][0].den)
		}
		for j in 1 ..< a.col {
			if a.m[i][j].den == 1 {
				fmt.sbprintf(&sb, ",%d", a.m[i][j].num)
			} else {
				fmt.sbprintf(&sb, ",%d/%d", a.m[i][j].num, a.m[i][j].den)
			}
		}
		if i < a.row - 1 {
			fmt.sbprint(&sb, ";")
		}
	}
	return fmt.sbprint(&sb, "}")
}

print_matrix :: proc(a: ^RationalMatrix) {
	fmt.printfln("Matrix(%d,%d):", a.row, a.col)
	for i in 0 ..< a.row {
		for j in 0 ..< a.col {
			if a.m[i][j].den == 1 {
				fmt.printf("%d\t", a.m[i][j].num)
			} else {
				fmt.printf("%d/%d\t", a.m[i][j].num, a.m[i][j].den)
			}
		}
		fmt.println()
	}
}

matrix_add :: proc(a, b: ^RationalMatrix, allocator := context.allocator) -> ^RationalMatrix {
	if a.row != b.row {
		return nil
	}
	if a.col != b.col {
		return nil
	}
	r := new_matrix(a.row, a.col, allocator)
	for i in 0 ..< r.row {
		for j in 0 ..< r.col {
			r.m[i][j] = add(a.m[i][j], b.m[i][j])
		}
	}
	return r
}

matrix_sub :: proc(a, b: ^RationalMatrix, allocator := context.allocator) -> ^RationalMatrix {
	if a.row != b.row {
		return nil
	}
	if a.col != b.col {
		return nil
	}
	r := new_matrix(a.row, a.col, allocator)
	for i in 0 ..< r.row {
		for j in 0 ..< r.col {
			r.m[i][j] = sub(a.m[i][j], b.m[i][j])
		}
	}
	return r
}

matrix_mul :: proc(a, b: ^RationalMatrix, allocator := context.allocator) -> ^RationalMatrix {
	if a.col != b.row {
		return nil
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
	return r
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

matrix_rref :: proc(a: ^RationalMatrix, allocator := context.allocator) -> ^RationalMatrix {
	b := clone_matrix(a)
	r := 0
	c := 0
	for r < b.row && c < b.col {
		// find row with max absolute value of column c
		rmax := r
		for ri := r + 1; ri < b.row; ri += 1 {
			if cmp(b.m[ri][c], b.m[rmax][c]) > 0 {
				rmax = ri
			}
		}
		// make rmax row current row
		if rmax != r {
			b.m[rmax], b.m[r] = b.m[r], b.m[rmax]
		}
		// make current row curent column 1
		cof := b.m[r][c]
		b.m[r][c] = Rational{1, 1}
		for ci := c + 1; ci < b.col; ci += 1 {
			b.m[r][ci] = div(b.m[r][ci], cof)
		}
		// make following row current column 0
		for ri := r + 1; ri < b.row; ri += 1 {
			cof := b.m[ri][c]
			b.m[ri][c] = Rational{0, 1}
			for ci := c + 1; ci < b.col; ci += 1 {
				t := mul(b.m[r][ci], cof)
				b.m[ri][ci] = sub(b.m[ri][ci], t)
			}
		}
		r += 1
		c += 1
	}
	for r = b.row - 1; r >= 0; r -= 1 {
		for c = 0; c < b.col; c += 1 {
			if b.m[r][c].num != 0 {
				break
			}
		}
		if c == b.col {
			continue
		}
		for ri := r - 1; ri >= 0; ri -= 1 {
			cof := b.m[ri][c]
			b.m[ri][c] = Rational{0, 1}
			for ci := c + 1; ci < b.col; ci += 1 {
				t := mul(b.m[r][ci], cof)
				b.m[ri][ci] = sub(b.m[ri][ci], t)
			}
		}
	}
	return b
}

/*
matrix_inverse :: proc(a: ^RationalMatrix) -> ^RationalMatrix {
	if a.row != a.col {
		return nil
	}
}
*/
