#include <stdio.h>

// requires use of firmware version 'M'

void serialBegin(int val)
{
	#asm

	ld		bc,$0007		; reset transfer buffer, prepare zxpand to receive data
	ld		a,b
	out		(c),a
	call	waitForCommandCompletion

	ld		hl,-4
	add		hl,sp
	ld		a,(hl)			; get val off the stack
	ld		bc,$4007		; send val into buffer
	out		(c),a
	call	waitForCommandCompletion

	ld		bc,$e007		; set baud = 1200 * val
	ld		a,$cb
	out		(c),a
	jp		waitForCommandCompletion

	#endasm
}


int serialAvailable(void)
{
	#asm

	ld		bc,$e007		; ask how many characters in receive buffer
	ld		a,$c5
	out		(c),a
	call	waitForCommandCompletion

	in		a,(c)			; return value should be in hl
	ld		h,0
	ld		l,a
	ret

	#endasm
}

int serialRead(void)
{
	#asm

	ld		bc,$e007		; pull a character from the receive buffer
	ld		a,$c7
	out		(c),a
	call	waitForCommandCompletion

	in		a,(c)
	ld		h,0
	ld		l,a
	ret

	#endasm
}

void serialWrite(int val)
{
	#asm

	ld		bc,$0007		; reset transfer buffer, prepare to receive data
	ld		a,b
	out		(c),a
	call	waitForCommandCompletion

	ld		hl,-4
	add		hl,sp
	ld		a,(hl)			; get val off the stack
	ld		bc,$4007		; send val into buffer
	out		(c),a
	call	waitForCommandCompletion

	ld		bc,$e007		; write to serial port
	ld		a,$c6
	out		(c),a

waitForCommandCompletion:
	in		a,($17)
	and		$80
	jr		nz,waitForCommandCompletion
	ret

	#endasm
}


void main()
{
	serialBegin(4); // 4 * 9600 = 38400
	serialWrite('h');
	serialWrite('i');
	while(1) {
		if(serialAvailable()) {
			putchar(serialRead());
		}
	}
}
