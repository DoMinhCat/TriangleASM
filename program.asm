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

; taille en bytes d'un triangle : 6 * 4 (Ax,Ay,Bx,By,Cx,Cy)
%define TRI_STRIDE  24
%define REC_STRIDE  16 ; 4*4 (min/max x/y)

; offset of index to get coords of a triangle in triangle_coord_list
%define AX_OFF        0
%define AY_OFF        4
%define BX_OFF        8
%define BY_OFF        12
%define CX_OFF        16
%define CY_OFF        20

global main

global generate_rand_nb
global generate_a_triangle
global generate_triangles_and_color

global calculate_a_determinant_rect
global calculate_all_determinant_rects


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
    ; list of all triangles coordinates: 6 coords for each triangle (int32)
    ; triangle_coord_list[i] = Ax,Ay,Bx,By,Cx,Cy
    triangle_coord_list:     resd NB_TRIANGLES * 6
    triangle_color_list:     resd NB_TRIANGLES ; list of colors for each triangle (int32)

    ; Minh Cat's variables
    rectangle_coord_list:   resd NB_TRIANGLES * 4 ; determinant rectangle - min_x, max_x, min_y, max_y for each triangle


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
;  - utilise RDRAND
;  - vérifie CF = 1
;  - renvoie un entier dans [0 ; max-1] in rax
; =============================================================
generate_rand_nb:
    push rbp
    mov  rbp, rsp
    push rbx

    .retry:
        rdrand rax
        jnc .retry      ; si CF = 0 → échec → retente

        mov  rbx, rdi        ; rdi = max value allowed for rand num
        xor  rdx, rdx
        div  rbx             ; (RDX:RAX / RBX) => reste dans RDX

        mov  rax, rdx        ; on renvoie le reste modulo max

        pop  rbx
        pop  rbp
        ret

; =============================================================
;  FONCTION 2 : generate_a_triangle(index)
;  - génère Ax,Ay,Bx,By,Cx,Cy pour un triangle donné
;  - index = rdi
; =============================================================
generate_a_triangle:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12

    mov  rbx, rdi               ; i = index du triangle

    ; base_ptr = triangle_coord_list + i * TRI_STRIDE
    mov  rax, rbx
    imul rax, TRI_STRIDE
    lea  r12, [triangle_coord_list + rax] ; r12 = pointeur du triangle

    ; ----- Ax -----
    mov  rdi, WIDTH
    call generate_rand_nb
    mov  dword [r12 + AX_OFF], eax

    ; ----- Ay -----
    mov  rdi, HEIGHT
    call generate_rand_nb
    mov  dword [r12 + AY_OFF], eax

    ; ----- Bx -----
    mov  rdi, WIDTH
    call generate_rand_nb
    mov  dword [r12 + BX_OFF], eax

    ; ----- By -----
    mov  rdi, HEIGHT
    call generate_rand_nb
    mov  dword [r12 + BY_OFF], eax

    ; ----- Cx -----
    mov  rdi, WIDTH
    call generate_rand_nb
    mov  dword [r12 + CX_OFF], eax

    ; ----- Cy -----
    mov  rdi, HEIGHT
    call generate_rand_nb
    mov  dword [r12 + CY_OFF], eax

    pop  r12
    pop  rbx
    pop  rbp
    ret

; =============================================================
;  FONCTION 3 : generate_triangles_and_color()
;  - génère tous les coords des triangle 
;  - attribue une couleur 0xRRGGBB à chacun stocké dans triangle_color_list
; =============================================================
generate_triangles_and_color:
    push rbp
    mov  rbp, rsp
    push rbx

    xor  ebx, ebx                ; initialize loop counter i = 0

    .paco_loop:
        cmp  ebx, NB_TRIANGLES ; if i > NB_TRIANGLES => end
        jge  .fin

        ; --- Génération les coords triangle i ---
        mov  rdi, rbx
        call generate_a_triangle

        ; --- Couleur aléatoire ---
        mov  rdi, 0x1000000          ; 2^24 = 0x1000000
        call generate_rand_nb        ; rax ∈ [0 ; 0xFFFFFF]

        mov  edx, ebx
        imul edx, 4                  ; offset = i*4
        mov  dword [triangle_color_list + rdx], eax ; store color in the list

        inc  ebx
        jmp  .paco_loop

    .fin:
        pop  rbx
        pop  rbp
        ret

; =============================================================
; END OF MODULE PACO
; =============================================================

; =============================================================
; MODULE MINH CAT
; =============================================================

; =============================================================
; FUNCTION 1: calculate determinant rectangle
; - input : index = rdi
; - output : r8d as max_x, r9d as min_x, r10d as max_y, r11d as min_y
; =============================================================
calculate_a_determinant_rect:
    push rbx
    push r12
    push rcx             ; Save RCX for use as offset register
    push rdx             ; Save RDX for use as offset register

    ; Calculate base address of the triangle
    mov rax, rdi
    imul rax, TRI_STRIDE
    lea r12, [triangle_coord_list + rax] 

    ; init min/max using point A (Offset 0)
    mov r8d, dword[r12 + 0]  ; max x 
    mov r9d, dword[r12 + 0]  ; min x
    mov r10d, dword[r12 + 4] ; max y 
    mov r11d, dword[r12 + 4] ; min y

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
        cmp r8d, dword[r12 + rcx] ; Compare current max_x to next_x (offset in RCX)
        jl .set_max_x
        
    .cmp_min_x:
        ; Compare Min X
        cmp r9d, dword[r12 + rcx] ; Compare current min_x to next_x (offset in RCX)
        jg .set_min_x
    .cmp_max_y:
        ; Compare Max Y
        cmp r10d, dword[r12 + rdx] ; Compare current max_y to next_y (offset in RDX)
        jl .set_max_y     
    .cmp_min_y:
        ; Compare Min Y
        cmp r11d, dword[r12 + rdx] 
        jg .set_min_y
    .continue:
        inc ebx                  ; Increment counter
        jmp .loop

    .set_max_x:
        mov r8d, dword[r12 + rcx] ; Set max_x
        jmp .cmp_min_x
    .set_min_x:
        mov r9d, dword[r12 + rcx] ; Set min_x
        jmp .cmp_max_y      
    .set_max_y:
        mov r10d, dword[r12 + rdx] ; Set max_y
        jmp .cmp_min_y      
    .set_min_y:
        mov r11d, dword[r12 + rdx] ; Set min_y
        jmp .continue

    .store:
        ; get base address of the rectangle in r12
        mov rax, rdi
        imul rax, REC_STRIDE
        lea r12, [rectangle_coord_list + rax] 

        ; store the results (r8d, r9d, r10d, r11d)
        mov dword[r12 + 0], r8d   ; max_x
        mov dword[r12 + 4], r9d   ; min_x
        mov dword[r12 + 8], r10d  ; max_y
        mov dword[r12 + 12], r11d ; min_y

        pop rdx
        pop rcx
        pop r12
        pop rbx
        ret

; =============================================================
; FUNCTION 2: calculate determinant rectangle of all triangles, put into rectangle_coord_list
; =============================================================
calculate_all_determinant_rects:
    push rbx
    push r12

    xor ebx, ebx ; i=0

    .loop:
        cmp ebx, NB_TRIANGLES
        jge  .end

        mov rdi, rbx
        call calculate_a_determinant_rect

        inc ebx
        jmp .loop

    .end:
        pop r12
        pop rbx
        ret

; =============================================================
; FUNCTION 3: check if the current triangle is direct or indirect
; - input : index of current triangle = rdi
; - output : set is_direct to 0 or 1
; =============================================================
determine_triangle_type:
    push rbx
    push r12

    ; Calculate base address of the current triangle
    mov rax, rdi
    imul rax, TRI_STRIDE
    lea r12, [triangle_coord_list + rax]

    

    pop r12
    pop rbx
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
    mov     r8,LARGEUR                ; largeur de la fenêtre
    mov     r9,HAUTEUR           	; hauteur de la fenêtre
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