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
extern XDrawArc
extern XFillArc
extern XNextEvent

; external functions from C stdio
extern scanf
extern printf
extern exit

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
%define NBTRI	1
%define BYTE	1
%define	WIDTH 400
%define HEIGHT 400

%define NB_TRIANGLES  1

global main

;============================
; PACO'S FUNCTIONS
;============================
global generate_rand_nb
global generate_a_triangle
global generate_rand_color
;============================
; MINH CAT'S FUNCTIONS
;============================
global calculate_rect_coord
global calculate_vector_coord
global determine_triangle_type
global determine_side_of_point
global determine_point_inside_triangle


section .bss
    display_name:	resq	1
    screen:			resd	1
    depth:         	resd	1
    connection:    	resd	1
    width:         	resd	1
    height:        	resd	1
    window:		resq	1
    gc:		resq	1

    ; === Données Paco  ===
    triangle_coord: resd 6
    triangle_color: resd 1

    ; Minh Cat's variables
    rectangle_coord:   resd 4 ;

section .data
    event:		times	24 dq 0

    ; Minh Cat's variables
    is_direct:  db  0
    is_left:  db  0
    is_inside:  db  0

    ;Bamba's variables
    max_x_temp: dd 0
    max_y_temp: dd 0

section .text
; =============================================================
; MODULE PACO
; =============================================================
; =============================================================
;  FONCTION 1 : generate_rand_nb(rdi)
; =============================================================
generate_rand_nb:
    push rbx

    .retry:
        rdrand rax
        jnc .retry

        mov  rbx, rdi        ; rdi = max value allowed
        xor  rdx, rdx
        div  rbx

        mov  rax, rdx

        pop  rbx
        ret

; =============================================================
;  FONCTION 2 : generate_a_triangle
; =============================================================
generate_a_triangle:
    mov  rdi, WIDTH
    call generate_rand_nb
    mov  [triangle_coord], eax

    mov  rdi, HEIGHT
    call generate_rand_nb
    mov  [triangle_coord + 1 * DWORD], eax

    mov  rdi, WIDTH
    call generate_rand_nb
    mov  [triangle_coord + 2 * DWORD], eax

    mov  rdi, HEIGHT
    call generate_rand_nb
    mov  [triangle_coord + 3 * DWORD], eax

    mov  rdi, WIDTH
    call generate_rand_nb
    mov  [triangle_coord + 4 * DWORD], eax

    mov  rdi, HEIGHT
    call generate_rand_nb
    mov  [triangle_coord + 5 * DWORD], eax

    ret

; =============================================================
;  FONCTION 3 : generate_rand_color()
; =============================================================
generate_rand_color:
    mov  rdi, 0x1000000
    call generate_rand_nb

    mov  dword[triangle_color], eax
    ret

; =============================================================
; END OF MODULE PACO
; =============================================================

; =============================================================
; MODULE MINH CAT
; =============================================================
; =============================================================
; FUNCTION 1: calculate determinant rectangle
; =============================================================
calculate_rect_coord:
    push rbx

    mov r8d, dword[triangle_coord + 0]
    mov r9d, dword[triangle_coord + 0]
    mov r10d, dword[triangle_coord + DWORD]
    mov r11d, dword[triangle_coord + DWORD]

    mov ebx, 0
    
    .loop:
        cmp ebx, 2
        jge .store

        mov ecx, ebx
        inc ecx
        imul ecx, 8

        mov edx, ecx
        add edx, 4

        cmp r8d, dword[triangle_coord + rcx]
        jl .set_max_x
        
    .cmp_min_x:
        cmp r9d, dword[triangle_coord + rcx]
        jg .set_min_x
    .cmp_max_y:
        cmp r10d, dword[triangle_coord + rdx]
        jl .set_max_y     
    .cmp_min_y:
        cmp r11d, dword[triangle_coord + rdx] 
        jg .set_min_y
    .continue:
        inc ebx
        jmp .loop

    .set_max_x:
        mov r8d, dword[triangle_coord + rcx]
        jmp .cmp_min_x
    .set_min_x:
        mov r9d, dword[triangle_coord + rcx]
        jmp .cmp_max_y      
    .set_max_y:
        mov r10d, dword[triangle_coord + rdx]
        jmp .cmp_min_y      
    .set_min_y:
        mov r11d, dword[triangle_coord + rdx]
        jmp .continue

    .store:
        mov dword[rectangle_coord], r8d
        mov dword[rectangle_coord + DWORD], r9d
        mov dword[rectangle_coord + 2 * DWORD], r10d
        mov dword[rectangle_coord + 3 * DWORD], r11d

        pop rbx
        ret

; =============================================================
; FUNCTION 2: calculate x,y of a vector from 2 points
; =============================================================
calculate_vector_coord:
    mov rax, rdx
    sub rax, rdi
    mov rdx, rcx
    sub rdx, rsi
    ret

; =============================================================
; FUNCTION 3: vect A x vect B
; =============================================================
multiply_vector:
    movsxd rdi, edi
    movsxd rsi, esi
    movsxd rdx, edx
    movsxd rcx, ecx

    imul rdi, rcx
    imul rdx, rsi

    mov rax, rdi
    sub rax, rdx
    ret

; =============================================================
; FUNCTION 4: check if current triangle is direct or indirect
; =============================================================
determine_triangle_type:
    mov edi, [triangle_coord + 2 * DWORD]
    mov esi, [triangle_coord + 3 * DWORD]
    mov edx, [triangle_coord]
    mov ecx, [triangle_coord + DWORD]
    call calculate_vector_coord

    mov r8, rax
    mov r9, rdx

    mov edx, [triangle_coord + 4 * DWORD]
    mov ecx, [triangle_coord + 5 * DWORD]
    call calculate_vector_coord
    mov r10, rax
    mov r11, rdx

    mov rdi, r8
    mov rsi, r9
    mov rdx, r10
    mov rcx, r11
    call multiply_vector

    cmp rax, 0
    setl byte [is_direct]
    ret

; =============================================================
; FUNCTION 5: check if the point is on the left or on the right of the vect AB
; =============================================================
determine_side_of_point:
    push r10
    push r11
    push r12
    push r13

    call calculate_vector_coord
    mov r10, rax
    mov r11, rdx

    mov rdx, r8
    mov rcx, r9
    call calculate_vector_coord

    mov r12, rax
    mov r13, rdx

    mov rdi, r10
    mov rsi, r11
    mov rdx, r12
    mov rcx, r13
    call multiply_vector

    cmp rax, 0
    setl byte [is_left]

    pop r13
    pop r12
    pop r11
    pop r10
    ret
    
; =============================================================
; FUNCTION 6: check if the point in the current triangle
; =============================================================
determine_point_inside_triangle:
    xor r10, r10

    .check_AB:
        mov rdi, [triangle_coord]
        mov rsi, [triangle_coord + DWORD]
        mov rdx, [triangle_coord + 2 * DWORD]
        mov rcx, [triangle_coord + 3 * DWORD]
        call determine_side_of_point

        cmp byte[is_left], 1
        jne .check_BC
        inc r10

    .check_BC:
        mov rdi, [triangle_coord + 2 * DWORD]
        mov rsi, [triangle_coord + 3 * DWORD]
        mov rdx, [triangle_coord + 4 * DWORD]
        mov rcx, [triangle_coord + 5 * DWORD]
        call determine_side_of_point

        cmp byte[is_left], 1
        jne .check_CA
        inc r10

    .check_CA:
        mov rdi, [triangle_coord + 4 * DWORD]
        mov rsi, [triangle_coord + 5 * DWORD]
        mov rdx, [triangle_coord]
        mov rcx, [triangle_coord + DWORD]
        call determine_side_of_point

        cmp byte[is_left], 1
        jne .final_check
        inc r10

    .final_check:
        cmp r10, 3
        je .all_left
        cmp r10, 0
        je .all_right

        jmp .false

    .all_left:
        cmp byte[is_direct], 0
        je .true
        jmp .false
    
    .all_right:
        cmp byte[is_direct], 1
        jne .false

    .true:
        mov byte[is_inside], 1
        jmp .end
    .false:
        mov byte[is_inside], 0

    .end:
        ret

; =============================================================
; END OF MODULE MINH CAT
; =============================================================

main:
    ; Sauvegarde du registre de base pour préparer les appels à printf
    push    rbp
    mov     rbp, rsp
	
    ; Récupère le nom du display par défaut (en passant NULL)
    xor     rdi, rdi          ; rdi = 0 (NULL)
    call    XDisplayName      ; Appel de la fonction XDisplayName
    ; Vérifie si le display est valide
    test    rax, rax          ; Teste si rax est NULL
    jz      closeDisplay      ; Si NULL, ferme le display et quitte

    ; Ouvre le display par défaut
    xor     rdi, rdi          ; rdi = 0 (NULL pour le display par défaut)
    call    XOpenDisplay      ; Appel de XOpenDisplay
    test    rax, rax          ; Vérifie si l'ouverture a réussi
    jz      closeDisplay      ; Si échec, ferme le display et quitte

    ; Stocke le display ouvert dans la variable globale display_name
    mov     [display_name], rax

    ; Récupère la fenêtre racine (root window) du display
    mov     rdi, qword[display_name]
    xor     esi, esi      ; screen = 0 (or use XDefaultScreen if you import it)
    call    XRootWindow               ; Appel de XRootWindow pour obtenir la fenêtre racine
    mov     rbx,rax               ; Stocke la root window dans rbx

    ; Création d'une fenêtre simple
    mov     rdi,qword[display_name]   ; display
    mov     rsi,rbx                   ; parent = root window
    mov     rdx,10                    ; position x de la fenêtre
    mov     rcx,10                    ; position y de la fenêtre
    mov     r8,WIDTH                ; largeur de la fenêtre
    mov     r9,HEIGHT           	; hauteur de la fenêtre
    push 0x000000                     ; couleur du fond (noir, 0x000000)
    push 0x00FF00                     ; couleur de fond (vert, 0x00FF00)
    push 1                          ; épaisseur du bord
    call XCreateSimpleWindow        ; Appel de XCreateSimpleWindow
	add rsp,24
	mov qword[window],rax           ; Stocke l'identifiant de la fenêtre créée dans window

    ; Sélection des événements à écouter sur la fenêtre
    mov rdi,qword[display_name]
    mov rsi,qword[window]
    mov rdx,131077                 ; Masque d'événements (ex. StructureNotifyMask + autres)
    call XSelectInput

    ; Affichage (mapping) de la fenêtre
    mov rdi,qword[display_name]
    mov rsi,qword[window]
    call XMapWindow

    ; Création du contexte graphique (GC) avec vérification d'erreur
    mov rdi, qword[display_name]
    test rdi, rdi                ; Vérifie que display n'est pas NULL
    jz closeDisplay

    mov rsi, qword[window]
    test rsi, rsi                ; Vérifie que window n'est pas NULL
    jz closeDisplay

    xor rdx, rdx                 ; Aucun masque particulier
    xor rcx, rcx                 ; Aucune valeur particulière
    call XCreateGC               ; Appel de XCreateGC pour créer le contexte graphique
    test rax, rax                ; Vérifie la création du GC
    jz closeDisplay              ; Si échec, quitte
    mov qword[gc], rax           ; Stocke le GC dans la variable gc
	
boucle: ; Boucle de gestion des événements
    mov     rdi, qword[display_name]
    cmp     rdi, 0              ; Vérifie que le display est toujours valide
    je      closeDisplay        ; Si non, quitte
    mov     rsi, event          ; Passe l'adresse de la structure d'événement
    call    XNextEvent          ; Attend et récupère le prochain événement
    
    cmp     dword[event], KeyPress        ; Si une touche est pressée
    je      closeDisplay                  ; Quitte le programme

    ;cmp     dword[event], ConfigureNotify ; Si l'événement est ConfigureNotify (ex: redimensionnement)
    ;je      dessin                        ; Passe à la phase de dessin

    jmp boucle

dessin:
    ; === BAMBA: CODE DE DESSIN DES TRIANGLES ===
    push r12
    push r13
    push r14
    push r15
    
    mov r12, 0                  
    
.triangle_loop:
    cmp r12, NB_TRIANGLES
    jge .end_dessin
    
    call generate_a_triangle
    call generate_rand_color
    call calculate_rect_coord
    call determine_triangle_type
    
    mov rdi, qword[display_name]
    mov rsi, qword[gc]
    mov rdx, 0x000000
    call XSetForeground
    
    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov ecx, dword[triangle_coord]
    mov r8d, dword[triangle_coord + DWORD]
    mov r9d, dword[triangle_coord + 2 * DWORD]
    push qword[triangle_coord + 3 * DWORD]
    call XDrawLine
    add rsp, 8 
    
    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov ecx, dword[triangle_coord + 2*DWORD] 
    mov r8d, dword[triangle_coord + 3*DWORD]
    mov r9d, dword[triangle_coord + 4*DWORD]
    push qword[triangle_coord + 5*DWORD]
    call XDrawLine
    add rsp, 8
    
    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov ecx, dword[triangle_coord + 4*DWORD]
    mov r8d, dword[triangle_coord + 5*DWORD]
    mov r9d, dword[triangle_coord]
    push qword[triangle_coord + DWORD]
    call XDrawLine
    add rsp, 8
    
    mov rdi, qword[display_name]
    mov rsi, qword[gc]
    mov edx, dword[triangle_color]
    call XSetForeground
    
    
    mov r13d, dword[rectangle_coord + DWORD]
    mov r14d, dword[rectangle_coord + 3 * DWORD]
    
    mov eax, dword[rectangle_coord]
    mov dword[max_x_temp], eax
    mov eax, dword[rectangle_coord + 2 * DWORD]
    mov dword[max_y_temp], eax
    
.y_loop:
    mov eax, dword[max_y_temp]
    cmp r14d, eax
    jg .next_triangle
    
    mov r13d, dword[rectangle_coord + DWORD]
    
.x_loop:
    mov eax, dword[max_x_temp]
    cmp r13d, eax
    jg .next_y
    
    mov r8, r13
    mov r9, r14
    call determine_point_inside_triangle
    
    cmp byte[is_inside], 1
    jne .skip_point
    
    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov ecx, r13d ; x
    mov r8d, r14d ; y
    call XDrawPoint
    
.skip_point:
    inc r13d
    jmp .x_loop
    
.next_y:
    inc r14d
    jmp .y_loop
    
.next_triangle:
    inc r12
    jmp .triangle_loop

.end_dessin:
    pop r15
    pop r14
    pop r13
    pop r12
    
    jmp flush

flush:
    mov rdi,qword[display_name]
    call XFlush
    jmp boucle
    mov rax,34
    syscall

closeDisplay:
    mov     rax,qword[display_name]
    mov     rdi,rax
    call    XCloseDisplay
    xor	    rdi,rdi
    call    exit