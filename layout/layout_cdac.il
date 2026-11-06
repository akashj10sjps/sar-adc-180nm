; =============================================================================
; File    : layout_cdac.il
; Module  : SKILL Script — CDAC Layout Generation
; Project : 8-Bit 10 MS/s SAR ADC — 180 nm CMOS
; Author  : akashj10sjps
; Date    : 2026-11-06
;
; Description:
;   Virtuoso SKILL script for automated placement of the segmented CDAC
;   capacitor array with common-centroid layout to minimize gradient errors.
;
;   Layout strategy:
;     • MIM capacitors (metal5-metal6 stack), 50 fF unit cap ≈ 2 µm × 2 µm
;     • Common-centroid arrangement for thermometer segment (upper 4 bits)
;     • Binary segment uses 2^k × unit_cap in an interleaved pattern
;     • Dummy capacitors on all edges (2 rows) to reduce edge fringing
;     • Top-plate routing on metal6, bottom-plate switches on metal1-metal3
;     • Overall array size: ~30 µm × 30 µm (single-ended)
;
; Usage:
;   In Virtuoso CIW:   load("layout/layout_cdac.il")
;   Then:              generateCDACLayout("SAR_ADC_lib" "cdac_array" "layout")
; =============================================================================

procedure(generateCDACLayout(libName cellName viewName)
  let((cv unitW unitH pitch nRows nCols x y instName)

    ; --- Parameters ----------------------------------------------------------
    unitW  = 2.0      ; unit cap width  (µm)
    unitH  = 2.0      ; unit cap height (µm)
    pitch  = 2.5      ; placement pitch (includes spacing)
    nRows  = 12       ; array rows (including 2 dummy rows top/bottom)
    nCols  = 12       ; array columns (including 2 dummy cols left/right)

    ; --- Create layout cellview ----------------------------------------------
    cv = dbOpenCellViewByType(libName cellName viewName "maskLayout" "a")

    ; --- Place dummy capacitors on edges -------------------------------------
    for(r 0 nRows-1
      for(c 0 nCols-1
        x = c * pitch
        y = r * pitch
        instName = sprintf(nil "CAP_R%d_C%d" r c)

        ; Determine if this is a dummy cap (edge row/col)
        if((r < 2 || r >= nRows-2 || c < 2 || c >= nCols-2) then
          ; Dummy cap: both plates connected to VCM
          dbCreateInst(cv
            dbOpenCellViewByType(libName "mimcap_unit" "layout")
            instName
            list(x y)
            "R0"
          )
          ; Label as dummy
          dbCreateLabel(cv list("text" "drawing") x:y instName "centerCenter" "R0" "roman" 0.2)
        else
          ; Active cap: assigned during pattern generation below
          nil
        )
      )
    )

    ; --- Common-centroid pattern for thermometer segment (15 unit caps) -------
    ; Using a rotationally symmetric pattern within the 8×8 active region
    ; Pattern indices (row, col) within active region (0-7, 0-7):
    ;   T0  → (0,0) (7,7)    T1  → (0,7) (7,0)
    ;   T2  → (1,1) (6,6)    T3  → (1,6) (6,1)
    ;   T4  → (2,2) (5,5)    T5  → (2,5) (5,2)
    ;   T6  → (3,3) (4,4)    T7  → (3,4) (4,3)
    ;   T8  → (0,3) (7,4)    T9  → (0,4) (7,3)
    ;   T10 → (1,3) (6,4)    T11 → (1,4) (6,3)
    ;   T12 → (2,3) (5,4)    T13 → (2,4) (5,3)
    ;   T14 → (3,0) (4,7)    (15th cap)

    thermPattern = list(
      list(0 0 "T0")  list(7 7 "T0")
      list(0 7 "T1")  list(7 0 "T1")
      list(1 1 "T2")  list(6 6 "T2")
      list(1 6 "T3")  list(6 1 "T3")
      list(2 2 "T4")  list(5 5 "T4")
      list(2 5 "T5")  list(5 2 "T5")
      list(3 3 "T6")  list(4 4 "T6")
      list(3 4 "T7")  list(4 3 "T7")
      list(0 3 "T8")  list(7 4 "T8")
      list(0 4 "T9")  list(7 3 "T9")
      list(1 3 "T10") list(6 4 "T10")
      list(1 4 "T11") list(6 3 "T11")
      list(2 3 "T12") list(5 4 "T12")
      list(2 4 "T13") list(5 3 "T13")
      list(3 0 "T14") list(4 7 "T14")
    )

    ; Place thermometer caps
    foreach(entry thermPattern
      let((r c label)
        r     = nth(0 entry) + 2   ; offset by dummy rows
        c     = nth(1 entry) + 2   ; offset by dummy cols
        label = nth(2 entry)
        x = c * pitch
        y = r * pitch

        dbCreateInst(cv
          dbOpenCellViewByType(libName "mimcap_unit" "layout")
          sprintf(nil "THERM_%s_R%d_C%d" label r c)
          list(x y)
          "R0"
        )
        dbCreateLabel(cv list("text" "drawing") x:y label "centerCenter" "R0" "roman" 0.15)
      )
    )

    ; --- Binary sub-DAC caps (lower 4 bits) ----------------------------------
    ; Remaining positions in the array used for binary segment
    ; B0 (1C): 1 position,  B1 (2C): 2 positions
    ; B2 (4C): 4 positions, B3 (8C): 8 positions
    ; + 1 dummy cap
    binaryPattern = list(
      ; B0 (1 cap)
      list(0 1 "B0")
      ; B1 (2 caps)
      list(0 2 "B1") list(7 5 "B1")
      ; B2 (4 caps)
      list(1 0 "B2") list(1 7 "B2") list(6 0 "B2") list(6 7 "B2")
      ; B3 (8 caps)
      list(0 5 "B3") list(0 6 "B3") list(7 1 "B3") list(7 2 "B3")
      list(3 1 "B3") list(3 6 "B3") list(4 1 "B3") list(4 6 "B3")
      ; Attenuation cap
      list(7 6 "CATT")
      ; Internal dummy
      list(1 2 "DUM")
    )

    foreach(entry binaryPattern
      let((r c label)
        r     = nth(0 entry) + 2
        c     = nth(1 entry) + 2
        label = nth(2 entry)
        x = c * pitch
        y = r * pitch

        dbCreateInst(cv
          dbOpenCellViewByType(libName "mimcap_unit" "layout")
          sprintf(nil "BIN_%s_R%d_C%d" label r c)
          list(x y)
          "R0"
        )
        dbCreateLabel(cv list("text" "drawing") x:y label "centerCenter" "R0" "roman" 0.15)
      )
    )

    ; --- Place shield ring (guard ring around entire array) ------------------
    ; Metal1 ground ring for noise isolation
    let((ringW totalW totalH)
      ringW  = 1.0      ; guard ring width (µm)
      totalW = nCols * pitch + 2 * ringW
      totalH = nRows * pitch + 2 * ringW

      ; Bottom
      dbCreateRect(cv list("metal1" "drawing")
        list(-ringW:-ringW totalW:0))
      ; Top
      dbCreateRect(cv list("metal1" "drawing")
        list(-ringW:nRows*pitch totalW:nRows*pitch+ringW))
      ; Left
      dbCreateRect(cv list("metal1" "drawing")
        list(-ringW:0 0:nRows*pitch))
      ; Right
      dbCreateRect(cv list("metal1" "drawing")
        list(nCols*pitch:0 nCols*pitch+ringW:nRows*pitch))
    )

    ; --- Save and close ------------------------------------------------------
    dbSave(cv)
    dbClose(cv)

    printf("CDAC layout generated: %s/%s/%s\n" libName cellName viewName)
    printf("Array size: %.1f µm × %.1f µm (including dummies & guard ring)\n"
           nCols*pitch+2 nRows*pitch+2)
  )
)

printf("CDAC layout script loaded. Run: generateCDACLayout(\"SAR_ADC_lib\" \"cdac_array\" \"layout\")\n")
