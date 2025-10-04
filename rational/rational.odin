package rational
import "core:fmt"
import "core:strings"

Rational :: struct {
	num: i32,
	den: i32,
}

to_string :: proc(r: Rational, decimal := false, allocator := context.allocator) -> string {
	r := r
	reduce(&r)
	if r.den == 1 {
		return fmt.aprintf("%d", r.num, allocator = allocator)
	}
	if !decimal {
		return fmt.aprintf("%d/%d", r.num, r.den, allocator = allocator)
	}
	sb: strings.Builder
	strings.builder_init_none(&sb, allocator = allocator)
	if r.num < 0 {
		fmt.sbprint(&sb, "-")
	}
	fmt.sbprintf(&sb, "%d.", abs(r.num) / r.den)

	num := abs(r.num) % r.den
	den := r.den
	pow2: i32 = 0
	pow5: i32 = 0
	for den & 0x1 == 0 {
		den >>= 1
		pow2 += 1
	}
	for den % 5 == 0 {
		den /= 5
		pow5 += 1
	}
	if den == 1 {
		if pow2 < pow5 {
			num *= pow(2, pow5 - pow2)
		}
		if pow5 < pow2 {
			num *= pow(5, pow2 - pow5)
		}
		fmt.sbprintf(&sb, "%d", num)
		return string(sb.buf[:])
	}
	nonLoopLen := max(pow2, pow5)
	loopLen := deciaml_loop_length(den)
	num *= 10
	den = r.den
	if nonLoopLen > 0 {
		for ; nonLoopLen > 0; nonLoopLen -= 1 {
			fmt.sbprintf(&sb, "%d", num / den)
			num = num % den * 10
		}
	}
	if loopLen > 0 {
		fmt.sbprint(&sb, "(")
		for ; loopLen > 0; loopLen -= 1 {
			fmt.sbprintf(&sb, "%d", num / den)
			num = num % den * 10
		}
		fmt.sbprint(&sb, ")")
	}
	return string(sb.buf[:])
}

pow :: proc(b, p: i32) -> i32 {
	if p < 0 {
		return -1
	}
	b := b
	p := p
	r: i32 = 1
	for p > 0 {
		if p & 0x1 == 1 {
			r *= b
		}
		b *= b
		p >>= 1
	}
	return r
}

deciaml_loop_length :: proc(b: i32) -> i32 {
	a := 10 % b
	for i: i32 = 1; i < b; i += 1 {
		if a == 1 {
			return i
		}
		a = a * 10 % b
	}
	return -1
}

gcd :: proc(a, b: i32) -> i32 {
	a := a
	b := b
	if a < 0 {
		a = -a
	}
	if b < 0 {
		b = -b
	}
	for b != 0 {
		r := a % b
		a = b
		b = r
	}
	return a
}

reduce :: proc(a: ^Rational) {
	d := gcd(a.num, a.den)
	if d > 1 {
		a.num /= d
		a.den /= d
	}
	if a.den < 0 {
		a.num = -a.num
		a.den = -a.den
	}
}

add :: proc(a, b: Rational) -> Rational {
	a := a
	if a.den == b.den {
		a.num += b.num
	} else {
		a.num = a.num * b.den + b.num * a.den
		a.den = a.den * b.den
	}
	reduce(&a)
	return a
}

sub :: proc(a, b: Rational) -> Rational {
	a := a
	if a.den == b.den {
		a.num -= b.num
	} else {
		a.num = a.num * b.den - b.num * a.den
		a.den = a.den * b.den
	}
	reduce(&a)
	return a
}

mul :: proc(a, b: Rational) -> Rational {
	a := a
	a.num = a.num * b.num
	a.den = a.den * b.den
	reduce(&a)
	return a
}

div :: proc(a, b: Rational) -> (Rational, Error) {
	if b.num == 0 {
		return {}, .DivideByZero
	}
	a := a
	a.num = a.num * b.den
	a.den = a.den * b.num
	reduce(&a)
	return a, nil
}

cmp :: proc(a, b: Rational) -> int {
	r := sub(a, b)
	return int(r.num)
}
