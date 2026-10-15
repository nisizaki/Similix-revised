; Similix load file for Chez Scheme
; Copyright (C) 1993 Anders Bondorf
; Please see the file README for copyright notice, license and disclaimer.
;
; Revised for modern Chez Scheme (v9/v10) in Similix-revised:
;  - source-only loading (no compile-file bootstrap), like sim-scm.scm
;  - _sim-remove-file uses delete-file (no shell-out)
;  - _sim-error formats messages with Chez format


;----------------------------------------------------------------------------


; Chez 3.x, for which Similix was written, read symbols case-insensitively
; (folding to lowercase).  Modern Chez is case-sensitive by default; restore
; the historical behavior so that e.g. **similix-library** (in the generated
; cogen.sim) and **Similix-library** (in loadsysf) denote the same variable.
; This must be the first form of the file: load reads and evaluates one form
; at a time, so every definition below is then read with folding enabled.
(case-sensitive #f)
;****************************************************************************
;**** The system directory is auto-detected below (see also the note there):
(define **Similix-path**
  (cond ((file-exists? "sim-chez.ss") "./")                  ; session in system/
        ((file-exists? "../system/sim-chez.ss") "../system/") ; session in examples/
        (else (error 'sim-chez.ss
                     "could not locate the Similix system directory; set **Similix-path** to an absolute path string"))))
; If neither default fits, replace the definition above with an absolute path,
; e.g. "/usr/local/lib/Similix/system/".

;****************************************************************************



;============================================================================
;======== Scheme system dependent definitions begin here: ===================

(define **Similix-source-suffix** ".scm")
(define **Similix-compiled-suffix** ".scm")       ; load system files from source
(define **Similix-compiled-sim-suffix** ".sim")  ; load spec/cogen/residuals from source


(define _sim-flush-output-port flush-output-port)

(define (_sim-remove-file file)
  (if (file-exists? file)
      (delete-file file)))

(define (_sim-compile-file file)  ; no separate compilation pass in this setup
  'done)

(define _sim-garbage-collect collect)

(define (_sim-ntimes suspension n)
  (_sim-garbage-collect)
  (time (begin
	  (let loop ((i 1))
	    (if (< i n)
		(begin (suspension)
		       (loop (+ i 1)))))
	  (suspension))))

(define _sim-pretty-print pretty-print)

(define (_sim-error who fmt . args)
  (error who (apply format #f fmt args)))

;-----------------------------------------------------------------------------

;======== Scheme system dependent definitions end here ======================
;============================================================================



(load (string-append **Similix-path** "loadsysf" **Similix-compiled-suffix**))

;----------------------------------------------------------------------------
