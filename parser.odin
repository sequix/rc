package main
import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode"
import "rational"
import "reader"

next_token :: proc(r: ^reader.Reader) -> (tk: Token) {
	c: i16
	for {
		advance_spaces(r)
		c = reader.getchar(r)
		if c < 0 {
			if r.err == io.Error.EOF {
				tk.type = .EOF
				return
			}
			fmt.eprintfln("Error at line #%d: I/O error: %s", r.lno, r.err)
			os.exit(1)
		}
		if c != '#' {
			break
		}
		advance_comment(r)
	}
	switch c {
	case '*':
		tk.type = .Mul
	case '/':
		tk.type = .Div
	case 'a' ..= 'z':
		reader.ungetc(r, c)
		tk = parse_word(r)
	case '=':
		tk = parse_assign(r)
	case '+', '-':
		nc := reader.getchar(r)
		if nc == -1 {
			tk = parse_add_sub(c)
			return
		}
		if unicode.is_digit(rune(nc)) || nc == '.' {
			reader.ungetc(r, nc)
			tk = parse_rational(r, c)
			return
		}
		reader.ungetc(r, nc)
		tk = parse_add_sub(c)
		return
	case '0' ..= '9', '.':
		tk = parse_rational(r, c)
	case '$':
		tk.type = .Variable
		tk.name = u8(reader.getchar(r))
	case:
		fmt.eprintfln("Error at line #%d: invalid character '%c'", r.lno, c)
		os.exit(1)
	}
	return
}

parse_add_sub :: proc(c: i16) -> (tk: Token) {
	switch c {
	case '+':
		tk.type = .Add
	case '-':
		tk.type = .Sub
	}
	return
}

parse_word :: proc(r: ^reader.Reader) -> (tk: Token) {
	c: i16
	buf: [16]u8
	bufp := 0
	for {
		c = reader.getchar(r)
		if unicode.is_lower(rune(c)) || c == '_' {
			buf[bufp] = u8(c)
			bufp += 1
			continue
		}
		break
	}
	reader.ungetc(r, c)
	word := string(buf[:bufp])
	switch word {
	case "popd":
		tk.type = .PopDecimal
	case "popq":
		tk.type = .PopQuietly
	case "pop":
		tk.type = .Pop
	case "stack":
		tk.type = .PrintStack
	case "vars":
		tk.type = .PrintVars
	case "ref":
		tk.type = .RREF
	case "inv":
		tk.type = .Inverse
	case "det":
		tk.type = .Determinant
	case:
		fmt.eprintfln("Error at line #%d: invalid word '%s'", r.lno, word)
		os.exit(1)
	}
	return tk
}

parse_rational :: proc(r: ^reader.Reader, c: i16) -> (tk: Token) {
	defer free_all(context.temp_allocator)
	c := c
	sb: strings.Builder
	strings.builder_init_len_cap(&sb, 0, 16, context.temp_allocator)

	if c == '+' || c == '-' || unicode.is_digit(rune(c)) {
		fmt.sbprintf(&sb, "%c", c)
		for {
			c = reader.getchar(r)
			if unicode.is_digit(rune(c)) {
				fmt.sbprintf(&sb, "%c", c)
				continue
			}
			break
		}
	}
	switch c {
	case '/':
		fmt.sbprintf(&sb, "%c", c)
		for {
			c = reader.getchar(r)
			if unicode.is_digit(rune(c)) {
				fmt.sbprintf(&sb, "%c", c)
				continue
			}
			break
		}
		reader.ungetc(r, i16(c))
	case '.':
		fmt.sbprintf(&sb, "%c", c)
		for {
			c = reader.getchar(r)
			if unicode.is_digit(rune(c)) {
				fmt.sbprintf(&sb, "%c", c)
				continue
			}
			break
		}
		if c == '(' {
			fmt.sbprintf(&sb, "%c", c)
			for {
				c = reader.getchar(r)
				if unicode.is_digit(rune(c)) {
					fmt.sbprintf(&sb, "%c", c)
					continue
				}
				break
			}
			if c == ')' {
				fmt.sbprintf(&sb, "%c", c)
			}
		}
	}
	tk.type = .Rational
	tk.rnum = rational.from_string(fmt.sbprint(&sb))
	return
}

parse_assign :: proc(r: ^reader.Reader) -> (tk: Token) {
	c: i16
	buf: [16]u8
	bufp := 0
	tk.type = .Assign

	c = reader.getchar(r)
	switch {
	case unicode.is_letter(rune(c)):
		tk.name = u8(c)
		c = reader.getchar(r)
	case c == '(':
	// unnamed assign
	}

	if c != '(' {
		reader.ungetc(r, c)
		return
	}

	for {
		c = reader.getchar(r)
		if unicode.is_digit(rune(c)) {
			buf[bufp] = u8(c)
			bufp += 1
			continue
		}
		break
	}
	tk.row = strconv.atoi(string(buf[:bufp]))
	bufp = 0

	if c == ')' {
		tk.col = tk.row
		return
	}

	if c == ',' {
		for {
			c = reader.getchar(r)
			if unicode.is_digit(rune(c)) {
				buf[bufp] = u8(c)
				bufp += 1
				continue
			}
			break
		}
		if c == ')' {
			tk.col = strconv.atoi(string(buf[:bufp]))
			bufp = 0
			return
		}
		fmt.eprintfln("Error at line #%d: expected ')' got '%c'", r.lno, c)
		os.exit(1)
	}
	return
}

advance_spaces :: proc(r: ^reader.Reader) {
	for {
		c := reader.getchar(r)
		if c == -1 {
			return
		}
		if !unicode.is_space(rune(c)) {
			reader.ungetc(r, c)
			return
		}
	}
}

advance_comment :: proc(r: ^reader.Reader) {
	for {
		c := reader.getchar(r)
		if c == -1 {
			return
		}
		if c == '\n' {
			return
		}
	}
}
