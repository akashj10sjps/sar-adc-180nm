; =============================================================================
; File    : layout_floorplan.il
; Module  : SKILL Script — SAR ADC Top-Level Floorplan
; Project : 8-Bit 10 MS/s SAR ADC — 180 nm CMOS
; Author  : akashj10sjps
; Date    : 2026-11-06
;
; Description:
;   Generates the top-level floorplan for the SAR ADC in Virtuoso.
;
;   Floorplan (estimated die area: 200 µm × 150 µm):
;
;     ┌─────────────────────────────────────────────┐
;     │  PAD RING (IO pads for VIN, VREF, CLK, D[]) │
;     │  ┌──────────────────────────────────────┐    │
;     │  │            Reference Buffer          │    │
;     │  │           (20 µm × 30 µm)            │    │
;     │  ├──────────────────────────────────────┤    │
;     │  │     CDAC_P      │     CDAC_N         │    │
;     │  │   (30 × 30 µm)  │   (30 × 30 µm)    │    │
;     │  ├──────────────────────────────────────┤    │
;     │  │  Bootstrap │ Comparator │ Bootstrap  │    │
;     │  │   SW_P     │  (15×20)   │  SW_N      │    │
;     │  │  (10×15)   │            │  (10×15)   │    │
;     │  ├──────────────────────────────────────┤    │
;     │  │          SAR Logic + Therm Enc       │    │
;     │  │           (60 µm × 20 µm)            │    │
;     │  ├──────────────────────────────────────┤    │
;     │  │       Decoupling Capacitors          │    │
;     │  │           (60 µm × 10 µm)            │    │
;     │  └──────────────────────────────────────┘    │
;     └─────────────────────────────────────────────┘
;
;   Key layout considerations:
;     • CDAC placed symmetrically for matching (P/N mirror image)
;     • Comparator centered between CDAC halves (minimize routing parasitics)
;     • Bootstrap switches adjacent to CDAC input nodes
;     • SAR logic below comparator (digital noise isolated from analog)
;     • Deep N-well isolation between analog and digital blocks
;     • Separate supply domains: AVDD/AVSS (analog), DVDD/DVSS (digital)
; =============================================================================

procedure(generateFloorplan(libName cellName viewName)
  let((cv x0 y0 blockDefs)

    cv = dbOpenCellViewByType(libName cellName viewName "maskLayout" "a")

    ; --- Block definitions: name, width, height, x_offset, y_offset ----------
    blockDefs = list(
      ; Decoupling caps (bottom)
      list("decap_array"    60.0  10.0  10.0   5.0)
      ; SAR logic
      list("sar_logic"      60.0  20.0  10.0  17.0)
      ; Bootstrap SW P (left)
      list("bootstrap_sw_p" 10.0  15.0  10.0  39.0)
      ; Comparator (center)
      list("comparator"     15.0  20.0  22.0  39.0)
      ; Bootstrap SW N (right)
      list("bootstrap_sw_n" 10.0  15.0  39.0  39.0)
      ; CDAC P (left)
      list("cdac_p"         30.0  30.0  10.0  57.0)
      ; CDAC N (right)
      list("cdac_n"         30.0  30.0  42.0  57.0)
      ; Reference buffer
      list("ref_buffer"     20.0  30.0  30.0  89.0)
    )

    ; --- Create placement rectangles (prBoundary) ----------------------------
    foreach(block blockDefs
      let((name w h xo yo)
        name = nth(0 block)
        w    = nth(1 block)
        h    = nth(2 block)
        xo   = nth(3 block)
        yo   = nth(4 block)

        ; prBoundary rectangle
        dbCreateRect(cv list("prBoundary" "drawing")
          list(xo:yo xo+w:yo+h))

        ; Block label
        dbCreateLabel(cv list("text" "drawing")
          (xo + w/2.0):(yo + h/2.0)
          name "centerCenter" "R0" "roman" 1.0)
      )
    )

    ; --- Deep N-well isolation trench between analog and digital domains -----
    ; Horizontal trench between SAR logic (digital) and comparator (analog)
    dbCreateRect(cv list("nwell" "drawing")
      list(10.0:37.0 70.0:39.0))
    dbCreateLabel(cv list("text" "drawing")
      40.0:38.0 "DEEP_NWELL_ISO" "centerCenter" "R0" "roman" 0.5)

    ; --- Top-level boundary --------------------------------------------------
    dbCreateRect(cv list("prBoundary" "boundary")
      list(0.0:0.0 80.0:125.0))

    ; --- Supply rings --------------------------------------------------------
    ; AVDD ring (analog blocks)
    dbCreatePath(cv list("metal1" "drawing")
      list(8.0:37.0 8.0:122.0 72.0:122.0 72.0:37.0 8.0:37.0)
      2.0)
    dbCreateLabel(cv list("metal1" "pin") 8.0:80.0 "AVDD" "centerCenter" "R0" "roman" 0.8)

    ; DVDD ring (digital blocks)
    dbCreatePath(cv list("metal1" "drawing")
      list(8.0:3.0 8.0:37.0 72.0:37.0 72.0:3.0 8.0:3.0)
      2.0)
    dbCreateLabel(cv list("metal1" "pin") 8.0:20.0 "DVDD" "centerCenter" "R0" "roman" 0.8)

    ; --- Save ----------------------------------------------------------------
    dbSave(cv)
    dbClose(cv)

    printf("Floorplan generated: %s/%s/%s\n" libName cellName viewName)
    printf("Die area: 80 µm × 125 µm = 10,000 µm²\n")
  )
)

printf("Floorplan script loaded. Run: generateFloorplan(\"SAR_ADC_lib\" \"sar_adc_top\" \"layout\")\n")
