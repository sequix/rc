package reader
import "core:io"

// TODO support rune

// Problem with core:bufio
// - bufio.reader_read_byte returns actual character when err != nil
// - bufio.reader_unread_byte cannot unread after bufio.reader_peek
// So this reader implements C-style getchar() and ungetc().
Reader :: struct {
	s:      io.Stream,
	// buf[p] is the next character returned by getchar()
	p:      int,
	// how many bytes in buf
	n:      int,
	buf:    []u8,
	unread: i16,
	err:    io.Error,
}

init :: proc(r: ^Reader, s: io.Stream, buf: []u8) {
	r.s = s
	r.p = 0
	r.n = 0
	r.buf = buf
	r.unread = -1
	r.err = nil
}

getchar :: proc(r: ^Reader) -> (c: i16) {
	if r.err != nil {
		return -1
	}
	if r.unread != -1 {
		c = r.unread
		r.unread = -1
		return
	}
	if r.p == r.n {
		r.n, r.err = io.read(r.s, r.buf)
		r.p = 0
	}
	if r.p < r.n {
		c = i16(r.buf[r.p])
		r.p += 1
		return
	}
	return -1
}

ungetc :: proc(r: ^Reader, c: i16) {
	r.unread = c
}
