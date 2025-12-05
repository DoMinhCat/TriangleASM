; external functions from X11 library
extern XOpenDisplay
extern XDisplayName
extern XCloseDisplay
extern XCreateSimpleWindow
extern XMapWindow
extern XRootWindow
extern XSelectInput
extern XFlush
extern XCreateGC
extern XSetForeground
extern XDrawLine
extern XDrawPoint
extern XFillArc
extern XNextEvent

extern exit

; mask which events we want to receive
%define	ExposureMask		32768
%define	StructureNotifyMask	131072
%define KeyPressMask		1
%define ButtonPressMask		4
%define MapNotify		19
%define KeyPress		2
%define ButtonPress		4
%define Expose			12
%define ConfigureNotify		22
%define CreateNotify 16
%define QWORD	8
%define DWORD	4
%define WORD	2
%define BYTE	1

; ============================
;  CONSTANTES PACO
; ============================
%define NB_TRIANGLES  5       ; nombre de triangles générés
%define WIN_W         400     ; largeur de la fenêtre
%define WIN_H         400     ; hauteur de la fenêtre

; taille en bytes d'un triangle : 6 * 4 (Ax,Ay,Bx,By,Cx,Cy)
%define TRI_STRIDE    24

%define AX_OFF        0
%define AY_OFF        4
%define BX_OFF        8
%define BY_OFF        12
%define CX_OFF        16
%define CY_OFF        20


global main

section .bss
display_name:	resq	1
screen:			resd	1
depth:         	resd	1
connection:    	resd	1
width:         	resd	1
height:        	resd	1
window:		resq	1
gc:		resq	1
    ; === Données Paco : triangles + couleurs ===
    ; NB_TRIANGLES triangles * 6 coords (int32)
    ; triangles[i] = Ax,Ay,Bx,By,Cx,Cy
    triangles:      resd NB_TRIANGLES * 6

    ; une couleur 0xRRGGBB par triangle (int32)
    tri_colors:     resd NB_TRIANGLES

section .data

event:		times	24 dq 0

x1:	dd	0
x2:	dd	0
y1:	dd	0
y2:	dd	0


section .text
	
; =============================================================
; MODULE PACO : génération aléatoire des triangles + couleurs
; =============================================================

    global rand_borne
    global genere_un_triangle
    global genere_triangles_et_couleurs

; =============================================================
;  FONCTION 1 : rand_borne(max)
;  - utilise RDRAND
;  - vérifie CF = 1
;  - renvoie un entier dans [0 ; max-1]
; =============================================================
rand_borne:
    push rbp
    mov  rbp, rsp
    push rbx

.rand_retry:
    rdrand rax
    jnc .rand_retry      ; si CF = 0 → échec → retente

    mov  rbx, rdi        ; rdi = borne max
    xor  rdx, rdx
    div  rbx             ; (RDX:RAX / RBX) => reste dans RDX

    mov  rax, rdx        ; on renvoie le reste modulo max

    pop  rbx
    pop  rbp
    ret

; =============================================================
;  FONCTION 2 : genere_un_triangle(index)
;  - génère Ax,Ay,Bx,By,Cx,Cy pour un triangle donné
;  - index = rdi
; =============================================================
genere_un_triangle:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12

    mov  rbx, rdi               ; i = index du triangle

    ; base_ptr = triangles + i * TRI_STRIDE
    mov  rax, rbx
    imul rax, TRI_STRIDE
    lea  r12, [triangles + rax] ; r12 = pointeur du triangle

    ; ----- Ax -----
    mov  rdi, WIN_W
    call rand_borne
    mov  dword [r12 + AX_OFF], eax

    ; ----- Ay -----
    mov  rdi, WIN_H
    call rand_borne
    mov  dword [r12 + AY_OFF], eax

    ; ----- Bx -----
    mov  rdi, WIN_W
    call rand_borne
    mov  dword [r12 + BX_OFF], eax

    ; ----- By -----
    mov  rdi, WIN_H
    call rand_borne
    mov  dword [r12 + BY_OFF], eax

    ; ----- Cx -----
    mov  rdi, WIN_W
    call rand_borne
    mov  dword [r12 + CX_OFF], eax

    ; ----- Cy -----
    mov  rdi, WIN_H
    call rand_borne
    mov  dword [r12 + CY_OFF], eax

    pop  r12
    pop  rbx
    pop  rbp
    ret

; =============================================================
;  FONCTION 3 : genere_triangles_et_couleurs()
;  - génère tous les triangles
;  - attribue une couleur 0xRRGGBB à chacun
; =============================================================
genere_triangles_et_couleurs:
    push rbp
    mov  rbp, rsp
    push rbx

    xor  ebx, ebx                ; i = 0

.paco_loop:
    cmp  ebx, NB_TRIANGLES
    jge  .fin

    ; --- Génération du triangle i ---
    mov  rdi, rbx
    call genere_un_triangle

    ; --- Couleur aléatoire ---
    mov  rdi, 0x1000000          ; 2^24 = 0x1000000
    call rand_borne              ; rax ∈ [0 ; 0xFFFFFF]

    mov  edx, ebx
    imul edx, 4                  ; offset = i*4
    mov  dword [tri_colors + rdx], eax

    inc  ebx
    jmp  .paco_loop

.fin:
    pop  rbx
    pop  rbp
    ret

; ====== FIN MODULE PACO ======


;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################

main:
xor     rdi,rdi
call    XOpenDisplay	; Création de display
mov     qword[display_name],rax	; rax=nom du display

; display_name structure
; screen = DefaultScreen(display_name);
mov     rax,qword[display_name]
mov     eax,dword[rax+0xe0]
mov     dword[screen],eax

; RootWindow(display, screen);
mov rdi,qword[display_name]
mov eax,dword[screen]
mov esi,eax
call XRootWindow
mov rbx,rax

mov rdi,qword[display_name]
mov rsi,rbx
mov rdx,10
mov rcx,10
mov r8,400	; largeur
mov r9,400	; hauteur
push 0xFFFFFF	; background  0xRRGGBB
push 0x00FF00
push 1
call XCreateSimpleWindow
mov qword[window],rax

mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,131077 ;131072
call XSelectInput

mov rdi,qword[display_name]
mov rsi,qword[window]
call XMapWindow

mov rsi,qword[window]
mov rdx,0
mov rcx,0
call XCreateGC
mov qword[gc],rax

mov rdi,qword[display_name]
mov rsi,qword[gc]
mov rdx,0x000000	; Couleur du crayon
call XSetForeground

boucle: ; boucle de gestion des évènements
mov rdi,qword[display_name]
mov rsi,event
call XNextEvent

cmp dword[event],ConfigureNotify	; à l'apparition de la fenêtre
je dessin							; on saute au label 'dessin'

cmp dword[event],KeyPress			; Si on appuie sur une touche
je closeDisplay						; on saute au label 'closeDisplay' qui ferme la fenêtre
jmp flush

;#########################################
;#		DEBUT DE LA ZONE DE DESSIN		 #
;#########################################
dessin:

    ; Génération des triangles et couleurs aléatoires (partie Paco)
    call genere_triangles_et_couleurs


; couleurs sous forme RRGGBB où RR esr le niveau de rouge, GG le niveua de vert et BB le niveau de bleu
; 0000000 (noir) à FFFFFF (blanc)

;couleur du point 1
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0xFF0000	; Couleur du crayon ; rouge
call XSetForeground

; Dessin d'un point rouge : coordonnées (200,200)
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,200	; coordonnée source en x
mov r8d,200	; coordonnée source en y
call XDrawPoint

;couleur du point 2
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0x00FF00	; Couleur du crayon ; vert
call XSetForeground

; Dessin d'un point vert: coordonnées (100,250)
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,100	; coordonnée source en x
mov r8d,250	; coordonnée source en y
call XDrawPoint

;couleur du point 3
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0x0000FF	; Couleur du crayon ; bleu
call XSetForeground

; Dessin d'un point bleu : coordonnées (200,200)
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,200	; coordonnée source en x
mov r8d,200	; coordonnée source en y
call XDrawPoint

;couleur du point 4
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0xFF00FF	; Couleur du crayon ; violet
call XSetForeground

; Dessin d'un point violet : coordonnées (200,250)
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,200	; coordonnée source en x
mov r8d,250	; coordonnée source en y
call XDrawPoint

;couleur de la ligne 1
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0x000000	; Couleur du crayon ; noir
call XSetForeground

; coordonnées de la ligne 1 (noire)
mov dword[x1],70
mov dword[y1],50
mov dword[x2],350
mov dword[y2],350
; dessin de la ligne 1
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,dword[x1]	; coordonnée source en x
mov r8d,dword[y1]	; coordonnée source en y
mov r9d,dword[x2]	; coordonnée destination en x
push qword[y2]		; coordonnée destination en y
call XDrawLine

;couleur de la ligne 2
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0xFFAA00	; Couleur du crayon ; orange
call XSetForeground
; coordonnées de la ligne 1 (noire)
mov dword[x1],300
mov dword[y1],50
mov dword[x2],50
mov dword[y2],350
; dessin de la ligne 1
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,dword[x1]	; coordonnée source en x
mov r8d,dword[y1]	; coordonnée source en y
mov r9d,dword[x2]	; coordonnée destination en x
push qword[y2]		; coordonnée destination en y
call XDrawLine


flush:
mov rdi,qword[display_name]
call XFlush
;jmp boucle
mov rax,34
syscall

closeDisplay:
    mov     rax,qword[display_name]
    mov     rdi,rax
    call    XCloseDisplay
    xor	    rdi,rdi
    call    exit