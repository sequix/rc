package main
import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
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
		if unicode.is_digit(rune(nc)) {
			reader.ungetc(r, nc)
			tk = parse_rational(r, c)
			return
		}
		reader.ungetc(r, nc)
		tk = parse_add_sub(c)
		return
	case '0' ..= '9':
		tk = parse_rational(r, c)
	case '$':
		tk.type = .Variable
		tk.name = u8(reader.getchar(r))
	case:
		fmt.eprintfln("invalid character '%c'", c)
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
	case "pop":
		tk.type = .Pop
	case "print", "p":
		tk.type = .Print
	case "ref", "r":
		tk.type = .RREF
	case "to_decimal":
		tk.type = .ToDeciaml
	case "inv":
		tk.type = .Inverse
	case:
		fmt.eprintfln("invalid word '%s'", word)
		os.exit(1)
	}
	return tk
}

parse_rational :: proc(r: ^reader.Reader, c: i16) -> (tk: Token) {
	c := c
	buf: [16]u8
	bufp := 0
	tk.type = .Rational
	tk.rnum.den = 1

	if c == '+' || c == '-' || unicode.is_digit(rune(c)) {
		buf[bufp] = u8(c)
		bufp += 1
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
	tk.rnum.num = i32(strconv.atoi(string(buf[:bufp])))
	bufp = 0

	if c == '/' {
		for {
			c = reader.getchar(r)
			if unicode.is_digit(rune(c)) {
				buf[bufp] = u8(c)
				bufp += 1
				continue
			}
			break
		}
		tk.rnum.den = i32(strconv.atoi(string(buf[:bufp])))
		bufp = 0
	}
	// TODO /<invalid> will not ungetc /
	reader.ungetc(r, i16(c))
	return
}

parse_assign :: proc(r: ^reader.Reader) -> (tk: Token) {
	c: i16
	buf: [16]u8
	bufp := 0
	tk.type = .Assign

	c = reader.getchar(r)
	switch c {
	case 'a' ..= 'z', 'A' ..= 'Z':
		tk.name = u8(c)
	case:
		fmt.eprintfln("expected variable name [A-Za-z] got: '%c'", c)
		os.exit(1)
	}

	c = reader.getchar(r)
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
		fmt.eprintfln("expected ')' got '%c'", c)
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
