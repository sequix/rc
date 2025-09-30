package rational
import "core:fmt"

Rational :: struct {
	num: i32,
	den: i32,
}

to_string :: proc(r: Rational, allocator := context.allocator) -> string {
	if r.den == 1 {
		return fmt.aprintf("%d", r.num, allocator = allocator)
	}
	return fmt.aprintf("%d/%d", r.num, r.den, allocator = allocator)
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

div :: proc(a, b: Rational) -> Rational {
	a := a
	a.num = a.num * b.den
	a.den = a.den * b.num
	reduce(&a)
	return a
}

cmp :: proc(a, b: Rational) -> int {
	r := sub(a, b)
	return int(r.num)
}
