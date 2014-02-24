############################################################################
#				LABORATORIO ORGANIZACION DEL COMPUTADOR					   #
#								PROYECTO II 							   #
#																		   #
#				INTEGRANTES:	FERRANDO MATTEO, 09-10285				   #
#								COLS ALBERTO, 	 09-10177				   #
#																		   #
#				GRUPO:			20										   #
#																		   #
############################################################################




# SPIM S20 MIPS simulator.
# The default exception handler for spim.
#
# Copyright (c) 1990-2010, James R. Larus.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# Neither the name of the James R. Larus nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Define the exception handling code.  This must go first!

	.kdata
###################ESTRUCTURAS QUE MANEJARAN EL ROUND ROBIN########################
# head
#	head + 0: se mueve sobre las posiciones de array
#	head + 4: tiene la posicion despes ultimo elemento agregado
#	head + 8: lleva el contador de cuantos procesos estan activos
#
########
# array
#	array + 0: la direccion de instruccion donde quedo el proceso
#	array + 4
#	   ...
#	array + 116: registros R1..R25 U R28..R31 del proceso
###################################################################################

head:		.space 12				#Para saber cual fue el ultimo agregado
			.align 4
array: 		.space 2400				#Arreglo donde guardo los registros de cada porceso
			.align 12
quantum:	.space 4				#Almacena la informacion del quantum
			.align 2
at:	.word 0							#Almacena $at
ra: .word 0							#Almacena $ra
a0: .word 0							#Almacena $a0
v0:	.word 0							#Almacena $v0

quanMen: .asciiz " Introduzca el quantum (Numero positivo multiplo de 10): "
final:	 .asciiz " Todos los procesos han terminado. Fin del programa."

__m1_:	.asciiz "  Exception "
__m2_:	.asciiz " occurred and ignored\n"
__e0_:	.asciiz "  [Interrupt] "
__e1_:	.asciiz	"  [TLB]"
__e2_:	.asciiz	"  [TLB]"
__e3_:	.asciiz	"  [TLB]"
__e4_:	.asciiz	"  [Address error in inst/data fetch] "
__e5_:	.asciiz	"  [Address error in store] "
__e6_:	.asciiz	"  [Bad instruction address] "
__e7_:	.asciiz	"  [Bad data address] "
__e8_:	.asciiz	"  [Error in syscall] "
__e9_:	.asciiz	"  [Breakpoint] "
__e10_:	.asciiz	"  [Reserved instruction] "
__e11_:	.asciiz	""
__e12_:	.asciiz	"  [Arithmetic overflow] "
__e13_:	.asciiz	"  [Trap] "
__e14_:	.asciiz	""
__e15_:	.asciiz	"  [Floating point] "
__e16_:	.asciiz	""
__e17_:	.asciiz	""
__e18_:	.asciiz	"  [Coproc 2]"
__e19_:	.asciiz	""
__e20_:	.asciiz	""
__e21_:	.asciiz	""
__e22_:	.asciiz	"  [MDMX]"
__e23_:	.asciiz	"  [Watch]"
__e24_:	.asciiz	"  [Machine check]"
__e25_:	.asciiz	""
__e26_:	.asciiz	""
__e27_:	.asciiz	""
__e28_:	.asciiz	""
__e29_:	.asciiz	""
__e30_:	.asciiz	"  [Cache]"
__e31_:	.asciiz	""
__excp:	.word __e0_, __e1_, __e2_, __e3_, __e4_, __e5_, __e6_, __e7_, __e8_, __e9_
	.word __e10_, __e11_, __e12_, __e13_, __e14_, __e15_, __e16_, __e17_, __e18_,
	.word __e19_, __e20_, __e21_, __e22_, __e23_, __e24_, __e25_, __e26_, __e27_,
	.word __e28_, __e29_, __e30_, __e31_

# This is the exception handler code that the processor runs when
# an exception occurs. It only prints some information about the
# exception, but can server as a model of how to write a handler.
#
# Because we are running in the kernel, we can use $k0/$k1 without
# saving their old values.

# This is the exception vector address for MIPS-1 (R2000):
#	.ktext 0x80000080
# This is the exception vector address for MIPS32:
	.ktext 0x80000180
# Select the appropriate one for the mode in which SPIM is compiled.
	
	# Desactiva interrupciones
	#
	mfc0	$k0, $12
	andi	$k0, $k0, 0xfffe
	mtc0	$k0, $12
	
	.set noat
	sw	 $at, at + 0	# Carga en at el $at
	.set at
	sw $v0 v0		# Not re-entrant and we cant trust $sp
	sw $a0 a0		# But we need to use these registers

	mfc0 $k0 $13		# Cause register
	srl $a0 $k0 2		# Extract ExcCode Field
	andi $a0 $a0 0x1f
	
############################GUARDIAS POR INTERRUPCIONES##########################
	
	## Verifica si es timer
	mfc0	$k0, $13
	andi	$k1, $k0, 0x8000
	bnez	$k1, TIMER			# Salta al manejo de la interrupcion por tiempo
	
	## Verifica si es teclado
	andi	$k1, $k0, 0x0800
	bnez	$k1, KEYBOARD		# Salta al manejo de la interrupcion por teclado
	
	## Breaks
	
	mfc0	$k0, $14
	lw	$k0, 0($k0)
	
	beq	$k0, 0x100d, ADD		# break x02 Para agregar un porceso nuevo al arreglo
	beq $k0, 0x200d, FIN		# break x04 Para terminar un proceso y quitarlo del arreglo
	beq $k0, 0x400d, GIV		# break x08 Un proceso termina momentaneamente de correr
	
#########################FINAL GUARDIA POR INTERRUPCIONES#########################

	# Print information about exception.
	#
	li $v0 4		# syscall 4 (print_str)
	la $a0 __m1_
	syscall

	li $v0 1		# syscall 1 (print_int)
	srl $a0 $k0 2		# Extract ExcCode Field
	andi $a0 $a0 0x1f
	syscall

	li $v0 4		# syscall 4 (print_str)
	andi $a0 $k0 0x3c
	lw $a0 __excp($a0)
	nop
	syscall

	bne $k0 0x18 ok_pc	# Bad PC exception requires special checks
	nop

	mfc0 $a0 $14		# EPC
	andi $a0 $a0 0x3	# Is EPC word-aligned?
	beq	$a0 0 ok_pc
	nop
	
	li $v0 10		# Exit on really bad PC
	syscall

ok_pc:
	li $v0 4		# syscall 4 (print_str)
	la $a0 __m2_
	syscall

	srl $a0 $k0 2		# Extract ExcCode Field
	andi $a0 $a0 0x1f
	bne $a0 0 ret		# 0 means exception was an interrupt
	nop

# Interrupt-specific code goes here!
# Dont skip instruction at EPC since it has not executed.

##########################MANEJO DE INTERRUPCIONES##########################

#INTERRUPCION POR TIEMPO
#
TIMER:												
	
	# Busca el EPC del siguiente procedimiento a realizar  
	#
	nextProc:
		# Si solo queda un procedimiento activo, vuelve a el
		lw	$k0, head + 8
		addi	$k0, $k0, -1
		beqz	$k0, volver
	
		# Guarda la direccion del EPC
		lw	$k0, head + 0
		la	$k1, array
		add	$k0, $k0, $k1
		mfc0	$k1, $14
		sw	$k1, 0($k0)
		
		sw	$ra, ra + 0
		#Guardo los registros, $k0 = direccion del arreglo donde guarda
		jal SAVEreg
		lw	$ra, ra + 0
		
		#La direccion del recien corrido
		lw	$k0, head + 0
	endNextProc:
	
	# Revisa si debe saltar un procedimiento (por que ya culmino su proceso)
	# o si ya llego al final del arreglo (por lo que devolveria a $ko al inicio
	# de array)
	#
	getPOS:
		#Agarra la direccion del siguiente proceso
		addi $k0, $k0, 120
		
		#Si debe volver al inicio del arreglo
		lw	$k1, head + 4
		bne	$k0, $k1, NOlast			#Si no esta despues del ultimo proceso agregado
		move	$k0, $zero
	endGetPOS:
	
	# $k0 esta sobre la posicion del arreglo del proceso al que se le cargaran los reg
	#
	NOlast:
		#Coloco la nueva posicion a ver en el arreglo
		sw	$k0, head + 0
		#Carga en $k1 el EPC de esa direccion
		la	$k1, array
		add	$k0, $k0, $k1
		lw	$k1, 0($k0)
		beqz	$k1, getPOS
	endNOlast:
	
	# Carga los registros del proceso a realizar
	#
	loadREGS:
		#Carga el nuevo EPC
		mtc0	$k1, $14
	
		#Carga los registros nuevos, $k0 = direccion del arreglo donde guarda
		jal LOADreg
		lw	$31, 116($k0)
		
		b volver
	endLoadREGS:
	
#INTERRUPCION POR TECLADO
#
KEYBOARD:											
	lw	$k1, 0xffff0004
	
	beq	$k1, 0x73, nextProc			#Si consigue una 'S'
	beq $k1, 0x53, nextProc			#Si consigue una 's'
	beq	$k1, 0x46, finalProcs		#Si consigue una 'F'
	beq $k1, 0x66, finalProcs		#Si cosigue una 'f'

	b volver

endKEYBOARD:

########################FINAL MANEJO INTERRUPCIONES################################

#############################MANEJO DE EXCEPCIONES#################################

# Excepcion por break 0x02, agrega procedimientos al Round Robin
#
ADD:	
	#Incremento numero de procesos agregados (unidad = 120)
	lw	$k0, head + 4
	addi	$k0, $k0, 120
	sw	$k0, head + 4
	
	#Incremento numero de procesos activos
	lw	$k0, head + 8
	addi	$k0, $k0, 1
	sw	$k0, head + 8
	
	#Guardo la direccion del PC
	lw	$k0, head + 0
	la	$k1, array
	add	$k0, $k0, $k1
	lw	$k1, a0 + 0
	sw	$k1, 0($k0)
	
	sw	$ra, ra + 0
	sw	$zero, a0 + 0
	#Guardo los registros, $k0 = direccion del arreglo donde guarda
	jal SAVEreg
	lw	$ra, ra + 0
	
	#Mueve el apuntador de head a la siguiente posicion
	lw	$k0, head + 0
	addi	$k0, $k0, 120
	sw	$k0, head + 0
	
	b ret

# Excepcion por break 0x04, para finalizar un proceso (y "sacarlo" del Round Robin)
#
FIN:
	#Coloca el EPC del proceso en 0
	lw	$k0, head + 0
	lw	$k1, array
	add	$k0, $k1, $k0
	sw	$zero, 0($k0)
	
	#Decremento el numero de procesos activos
	lw	$k1, head + 8
	addi	$k1, $k1, -1
	sw	$k1, head + 8
	
	beqz	$k1, finalEND
	
	lw	$k0, head + 0
	
	b getPOS

# Excepcion por break 0x08, para parar momentaneamente el procedimiento y pasar al siguiente
#
GIV:
	mfc0	$k0, $14
	addi	$k0, $k0, 4
	mtc0	$k0, $14				# Incrementa el EPC del proceso para iniciar en la siguiente
									# instruccion cuando sea llamado de nuevo
	
	b nextProc
#################################FIN MANEJO EXCEPCIONES################################


######################################SUBRUTINAS#######################################

# Para guardar los registros del procedimiento en el Round Robin
#
SAVEreg:
	##	NO NECESITO $zero
	lw	$k1, at + 0	 #.word at
	sw	$k1, 4($k0)	 #
	lw	$k1, v0 + 0	 #.word v0
	sw	$k1, 8($k0)	 #
	sw	$3, 12($k0)
	lw	$k1, a0 + 0	 #.word a0
	sw	$k1, 16($k0) #
	sw	$5, 20($k0)	 
	sw	$6, 24($k0)
	sw	$7, 28($k0)
	sw	$8, 32($k0)
	sw	$9, 36($k0)
	sw	$10, 40($k0)
	sw	$11, 44($k0)
	sw	$12, 48($k0)
	sw	$13, 52($k0)
	sw	$14, 56($k0)
	sw	$15, 60($k0)
	sw	$16, 64($k0)
	sw	$17, 68($k0)
	sw	$18, 72($k0)
	sw	$19, 76($k0)
	sw	$20, 80($k0)
	sw	$21, 84($k0)
	sw	$22, 88($k0)
	sw	$23, 92($k0)
	sw	$24, 96($k0)
	sw	$25, 100($k0)
	##	NO NECESITO $k0
	##	NO NECESITO $k1
	sw	$28, 104($k0)
	sw	$29, 108($k0)
	sw	$30, 112($k0)
	lw	$k1, ra + 0
	sw	$k1, 116($k0)
	
	jr	$ra

endSAVEreg:

# Para cargar los registros en el arreglo al proceso
#
LOADreg:
	##	NO NECESITO $zero
	lw	$k1, 4($k0)	 #.word at
	sw	$k1, at + 0	 #
	lw	$k1, 8($k0)	 #.word v0
	sw	$k1, v0 + 0	 #
	lw	$3, 12($k0)
	lw	$k1, 16($k0) #.word a0
	sw	$k1, a0 + 0	 #
	lw	$5, 20($k0)
	lw	$6, 24($k0)
	lw	$7, 28($k0)
	lw	$8, 32($k0)
	lw	$9, 36($k0)
	lw	$10, 40($k0)
	lw	$11, 44($k0)
	lw	$12, 48($k0)
	lw	$13, 52($k0)
	lw	$14, 56($k0)
	lw	$15, 60($k0)
	lw	$16, 64($k0)
	lw	$17, 68($k0)
	lw	$18, 72($k0)
	lw	$19, 76($k0)
	lw	$20, 80($k0)
	lw	$21, 84($k0)
	lw	$22, 88($k0)
	lw	$23, 92($k0)
	lw	$24, 96($k0)
	lw	$25, 100($k0)
	##	NO NECESITO $k0
	##	NO NECESITO $k1
	lw	$28, 104($k0)
	lw	$29, 108($k0)
	lw	$30, 112($k0)
	
	jr	$ra
	
endLOADreg:

######################################FINAL SUBRUTINAS################################

ret:
# Return from (non-interrupt) exception. Skip offending instruction
# at EPC to avoid infinite loop.
#
	mfc0 $k0 $14		# Bump EPC register
	addiu $k0 $k0 4		# Skip faulting instruction
				# (Need to handle delayed branch case here)
	mtc0 $k0 $14

volver:
# Restore registers and reset procesor state
#
	lw $v0 v0		# Restore other registers
	lw $a0 a0

	.set noat
	lw	 $at, at + 0	#Restauro $at
	.set at

	mtc0 $0 $13		# Clear Cause register

	mfc0 $k0 $12		# Set Status register
	ori  $k0 0x1		# Interrupts enabled
	mtc0 $k0 $12

	# Activa interrupciones
	#
	mfc0	$k0, $12
	ori		$k0, $k0, 0x01
	mtc0	$k0, $12
	
	# Inicializa el timer
	#
	mtc0	$zero, $9

# Return from exception on MIPS32:
	eret

# Final de todos los procesos
finalEND:
	
	la	$a0, final
	li	$v0, 4
	syscall
	
	li	$v0 10
	syscall			# syscall 10 (exit)

# Return sequence for MIPS-I (R2000):
#	rfe			# Return from exception handler
				# Should be in jr delay slot
#	jr $k0
#	 nop

# Standard startup code.  Invoke the routine "main" with arguments:
#	main(argc, argv, envp)
#
	.text
	.globl __start
__start:
	lw $a0 0($sp)		# argc
	addiu $a1 $sp 4		# argv
	addiu $a2 $a1 4		# envp
	sll $v0 $a0 2
	addu $a2 $a2 $v0

# Pide el Quantum
#
askQuantum:	
	la	$a0, quanMen			#Imprime mensaje para pedir el quantum
	li	$v0, 4
	syscall
	
	li 	$v0, 5					#Pide el quantum
	syscall
	
	# Si el quantum ingresado no es positivo
	#
	ble	$v0, $zero, askQuantum
	
	# Si el quantum ingresado no es multiplo de 10
	#
	li	$t1, 10
	div $v0, $t1
	mfhi	$t1
	bne	$t1, $zero, askQuantum
	
	mflo	$v0
	sw	$v0, quantum + 0
		
	# Inicializo head con contadores en 0
	#
	sw	$zero, head + 0
	sw	$zero, head + 4
	sw	$zero, head + 8
	
	jal main
	nop

	# Guarda el quantum
	#
	lw		$v0, quantum + 0
	mtc0	$v0, $11
	
	# Activa interrupciones
	#
	mfc0	$t0, $12
	ori		$t0, $t0, 0x01
	mtc0	$t0, $12
	
	# Activa interrupciones por teclado
	#
	li 		$t1, 0xffff0000
	lw		$t0, 0($t1)
	ori		$t0, $t0, 0x2
	sw		$t0, 0($t1)
	
	# Reinicializa el apuntador de head
	#
	sw		$zero, head + 0
	
	# Busca el PC del primer proceso
	#
	lw		$t0, array + 0
	
	#Indica el nuevo PC
	#
	mtc0	$t0, $14
	
	#Inicializa el timer
	#
	mtc0	$zero, $9

	eret
	
	li	$v0 10
	syscall			# syscall 10 (exit)

	.globl __eoth
__eoth: