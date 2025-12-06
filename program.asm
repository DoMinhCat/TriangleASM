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
%define	WIDTH 400	; largeur en pixels de la fenêtre
%define HEIGHT 400	; hauteur en pixels de la fenêtre
%define NB_TRIANGLES  5 ; total num of triangles

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
global determine_triangle_type:



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
    triangle_coord: resd 6
    triangle_color: resd 1

    ; Minh Cat's variables
    rectangle_coord:   resd 4 ; determinant rectangle - min_x, max_x, min_y, max_y


section .data
    event:		times	24 dq 0

    ; Minh Cat's variables
    is_direct:  db  0

section .text
;============================
;DEFINE FUNCTIONS HERE
;============================

; =============================================================
; MODULE PACO : génération aléatoire des triangles + couleurs
; =============================================================

; =============================================================
;  FONCTION 1 : generate_rand_nb(max) || rand_borne of Paco
;  - input : rdi (max)
;  - vérifie CF = 1
;  - renvoie rax : un entier dans [0 ; max-1]
; =============================================================
generate_rand_nb:
    push rbx

    .retry:
        rdrand rax
        jnc .retry      ; si CF = 0 → échec → retente

        mov  rbx, rdi        ; rdi = max value allowed for rand num
        xor  rdx, rdx
        div  rbx             ; (RDX:RAX / RBX) => reste dans RDX

        mov  rax, rdx        ; on renvoie le reste modulo max

        pop  rbx
        ret

; =============================================================
;  FONCTION 2 : generate_a_triangle
;  - génère Ax,Ay,Bx,By,Cx,Cy pour un triangle
;  - stock ses x,y dans triangle_coord
; =============================================================
generate_a_triangle:
    ; ----- Ax -----
    mov  rdi, WIDTH
    call generate_rand_nb
    mov  [triangle_coord], eax

    ; ----- Ay -----
    mov  rdi, HEIGHT
    call generate_rand_nb
    mov  [triangle_coord + 1 * DWORD], eax

    ; ----- Bx -----
    mov  rdi, WIDTH
    call generate_rand_nb
    mov  [triangle_coord + 2 * DWORD], eax

    ; ----- By -----
    mov  rdi, HEIGHT
    call generate_rand_nb
    mov  [triangle_coord + 3 * DWORD], eax

    ; ----- Cx -----
    mov  rdi, WIDTH
    call generate_rand_nb
    mov  [triangle_coord + 4 * DWORD], eax

    ; ----- Cy -----
    mov  rdi, HEIGHT
    call generate_rand_nb
    mov  [triangle_coord + 5 * DWORD], eax

    ret

; =============================================================
;  FONCTION 3 : generate_rand_color()
;  - génère une couleur aléatoirement 
;  - couleur stocké dans triangle_color
; =============================================================
generate_rand_color:
    mov  rdi, 0x1000000          ; 2^24 = 0x1000000
    call generate_rand_nb        ; rax ∈ [0 ; 0xFFFFFF]

    mov  dword[triangle_color], eax ; store color in the list
    ret

; =============================================================
; END OF MODULE PACO
; =============================================================

; =============================================================
; MODULE MINH CAT
; =============================================================

; =============================================================
; FUNCTION 1: calculate determinant rectangle
; - calculate max/min x/y for the rectangle
; - store in rectangle_coord 
; =============================================================
calculate_rect_coord:
    push rbx

    ; init min/max using point A (Offset 0)
    mov r8d, dword[triangle_coord + 0]  ; max x 
    mov r9d, dword[triangle_coord + 0]  ; min x
    mov r10d, dword[triangle_coord + 4] ; max y 
    mov r11d, dword[triangle_coord + 4] ; min y

    mov ebx, 0               ; Loop counter (EBX)
    
    ; for ebx=0; ebx < 2 (Iterates for comparing with point B and C)
    .loop:
        cmp ebx, 2
        jge .store

        ; Calculate offset for the current point (A or B)
        ; Offset calculation: (EBX + 1) * 8
        mov ecx, ebx             ; ECX = loop counter (0 or 1)
        inc ecx                  ; ECX = (1 or 2)
        imul ecx, 8              ; ECX = offset (8 or 16)

        ; EDX = offset for Y (ECX + 4)
        mov edx, ecx
        add edx, 4

        ; Compare Max X
        cmp r8d, dword[triangle_coord + rcx] ; Compare current max_x to next_x (offset in RCX)
        jl .set_max_x
        
    .cmp_min_x:
        ; Compare Min X
        cmp r9d, dword[triangle_coord + rcx] ; Compare current min_x to next_x (offset in RCX)
        jg .set_min_x
    .cmp_max_y:
        ; Compare Max Y
        cmp r10d, dword[triangle_coord + rdx] ; Compare current max_y to next_y (offset in RDX)
        jl .set_max_y     
    .cmp_min_y:
        ; Compare Min Y
        cmp r11d, dword[triangle_coord + rdx] 
        jg .set_min_y
    .continue:
        inc ebx                  ; Increment counter
        jmp .loop

    .set_max_x:
        mov r8d, dword[triangle_coord + rcx] ; Set max_x
        jmp .cmp_min_x
    .set_min_x:
        mov r9d, dword[triangle_coord + rcx] ; Set min_x
        jmp .cmp_max_y      
    .set_max_y:
        mov r10d, dword[triangle_coord + rdx] ; Set max_y
        jmp .cmp_min_y      
    .set_min_y:
        mov r11d, dword[triangle_coord + rdx] ; Set min_y
        jmp .continue

    .store:
        ; store the results (r8d, r9d, r10d, r11d)
        mov dword[rectangle_coord], r8d   ; max_x
        mov dword[rectangle_coord + 4], r9d   ; min_x
        mov dword[rectangle_coord + 8], r10d  ; max_y
        mov dword[rectangle_coord + 12], r11d ; min_y

        pop rbx
        ret

; =============================================================
; FUNCTION 2: calculate x,y of a vector from 2 points
; - input : rdi as Ax, rsi as Ay, rdx as Bx, rcx as By
; - output : rax as ABx, rdx as ABy
; =============================================================
calculate_vector_coord:
    mov rax, rdx
    sub rax, rdi

    mov rdx, rcx
    sub rdx, rsi
    ret

; =============================================================
; FUNCTION 3: vect A x vect B
; - input : rdi as Ax, rsi as Ay, rdx as Bx, rcx as By
; - output : rax
; =============================================================
multiply_vector:
    ; rdi x rcx = rdi
    imul rdi, rcx
    ; rdx x rsi = rdx
    imul rdx, rsi

    mov rax, rdi
    sub rax, rdx
    ret

; =============================================================
; FUNCTION 4: check if the current triangle is direct or indirect
; - input : index of current triangle = rdi
; - output : set is_direct to 0 or 1
; =============================================================
determine_triangle_type:
    ; get vector BA
    mov rdi, [triangle_coord + 2 * DWORD]
    mov rsi, [triangle_coord + 3 * DWORD]
    mov rdx, [triangle_coord]
    mov rcx, [triangle_coord + DWORD]
    call calculate_vector_coord
    ; BA_x : r8
    ; BA_y : r9
    mov r8, rax
    mov r9, rdx

    ; get vector BC, rdi and rsi stays the same for B, only update for C
    mov rdx, [triangle_coord + 4 * DWORD]
    mov rcx, [triangle_coord + 5 * DWORD]
    call calculate_vector_coord
    ; BC_x : r10
    ; BC_y : r11
    mov r10, rax
    mov r11, rdx

    ; BA x BC
    mov rdi, r8
    mov rsi, r9
    mov rdx, r10
    mov rcx, r11
    call multiply_vector

    test rax, rax
    sets byte [is_direct]
    ret

; =============================================================
; END OF MODULE MINH CAT
; =============================================================

;============================
;END OF FUNCTION DEFINITIONS
;============================

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
    mov     rdi,qword[display_name]   ; Place le display dans rdi
    mov     esi,dword[screen]         ; Place le numéro d'écran dans esi
    call XRootWindow                ; Appel de XRootWindow pour obtenir la fenêtre racine
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

    cmp     dword[event], ConfigureNotify ; Si l'événement est ConfigureNotify (ex: redimensionnement)
    je      dessin                        ; Passe à la phase de dessin

    cmp     dword[event], KeyPress        ; Si une touche est pressée
    je      closeDisplay                  ; Quitte le programme
    jmp     boucle                        ; Sinon, recommence la boucle


dessin:
    ; BAMBA va dessiner ici !!

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