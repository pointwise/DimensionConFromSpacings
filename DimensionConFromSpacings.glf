#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

###############################################################################
# Select connectors and dimension them from supplied beginning, ending, and
# maximum ds values.
###############################################################################

package require PWI_Glyph 2
pw::Script loadTk

# Globals
set ds1 0.10
set ds2 0.10
set maxDs 1.0
set conList [list]

# Widget hierarchy
set w(LabelTitle)               .title
set w(FrameMain)                .main
set   w(FrameConnectors)          $w(FrameMain).connectors
set     w(ButtonPick)               $w(FrameConnectors).bPick
set     w(ButtonClear)              $w(FrameConnectors).bClear
set   w(FrameEntries)             $w(FrameMain).entries
set     w(LabelDs1)                 $w(FrameEntries).lDs1
set     w(EntryDs1)                 $w(FrameEntries).eDs1
set     w(LabelDs2)                 $w(FrameEntries).lDs2
set     w(EntryDs2)                 $w(FrameEntries).eDs2
set     w(LabelMax)                 $w(FrameEntries).lMax
set     w(EntryMax)                 $w(FrameEntries).eMax
set   w(FrameAcquire)             $w(FrameMain).acquire
set     w(ButtonAcquire)            $w(FrameAcquire).b
set w(FrameButtons)             .buttons
set   w(Logo)                     $w(FrameButtons).logo
set   w(ButtonOK)                 $w(FrameButtons).bOk
set   w(ButtonApply)              $w(FrameButtons).bApply
set   w(ButtonCancel)             $w(FrameButtons).bCancel


# Select connectors to dimension from GUI
proc pickConnectors { } {
  set result [list]
  if {[pw::Grid getCount -type pw::Connector] > 0} {
    wm withdraw .
    pw::Display selectEntities -description "Pick connectors to dimension:" \
      -selectionmask [pw::Display createSelectionMask -requireConnector {}] \
      resultArray
    set result $resultArray(Connectors)
    if {[winfo exists .]} {
      wm deiconify .
    }
  }
  return $result
}


# Compute the maximum ds of the given connector
proc getMaxDs {con} {
  set result 0
  set numPoints [$con getDimension]
  for {set n 1} {$n < $numPoints} {incr n} {
    set p0 [$con getXYZ $n]
    set p1 [$con getXYZ [expr $n + 1]]
    set dx [expr [lindex $p1 0] - [lindex $p0 0]]
    set dy [expr [lindex $p1 1] - [lindex $p0 1]]
    set dz [expr [lindex $p1 2] - [lindex $p0 2]]
    set dr [expr sqrt($dx * $dx + $dy * $dy + $dz * $dz)]
    if {$dr > $result} {
      set result $dr
    }
  }
  return $result
}


# Dimension connectors according to given parameters
proc dimensionCons {} {
  global conList ds1 ds2 maxDs

  # Check for various inacceptable situations
  if {[llength $conList] < 1} {
    tk_messageBox -icon warning \
      -message "Please pick connectors first!" -parent . \
      -title "No Connectors Picked!" -type ok
    return
  }
  if {$ds1 > $maxDs} {
    tk_messageBox -icon warning \
      -message "ds1 must be less than max ds!" -parent . \
      -title "Incorrect Parameters!" -type ok
    return
  }
  if {$ds1 <= 0} {
    tk_messageBox -icon warning \
      -message "ds1 must be greater than 0!" -parent . \
      -title "Incorrect Parameters!" -type ok
    return
  }
  if {$ds2 > $maxDs} {
    tk_messageBox -icon warning \
      -message "ds2 must be less than max ds!" -parent . \
      -title "Incorrect Parameters!" -type ok
    return
  }
  if {$ds2 <= 0} {
    tk_messageBox -icon warning \
      -message "ds2 must be greater than 0!" -parent . \
      -title "Incorrect Parameters!" -type ok
    return
  }
  if {$maxDs <= 0} {
    tk_messageBox -icon warning \
      -message "max ds must be greater than 0!" -parent . \
      -title "Incorrect Parameters!" -type ok
    return
  }

  set dimensioner [pw::Application begin Modify $conList]
  set maxIter 20
  foreach con $conList {
    #Set initial dimension
    $con setDimensionFromSpacing $maxDs

    #Set endpoint spacings
    set subConDist [$con getDistribution 1]
    $subConDist setBeginSpacing $ds1
    set numSubCons [$con getSubConnectorCount]
    set subConDist [$con getDistribution $numSubCons]
    $subConDist setEndSpacing $ds2

    #Iterate to match the given parameters
    set newDim [$con getDimension]
    set oldDim 0
    set avgDs $maxDs
    for {set i 0} {$i < $maxIter && $oldDim != $newDim} {incr i} {
      set oldDim $newDim
      set avgDs [expr $avgDs * $maxDs / [getMaxDs $con]]
      $con setDimensionFromSpacing $avgDs
      set newDim [$con getDimension]
    }
    if {$oldDim != $newDim} {
      puts "Did not converge for connector $con"
    }
  }
  $dimensioner end
}


# Get beginning ending and maximum ds from given connector
proc getParametersFromConnector {refCon} {
  global ds1 maxDs ds2
  set lastPoint [$refCon getDimension]
  for {set n 2} {$n <= $lastPoint} {incr n} {
    set p0 [$refCon getXYZ -grid [expr $n - 1]]
    set p1 [$refCon getXYZ -grid $n]
    set ds [pwu::Vector3 length [pwu::Vector3 subtract $p1 $p0]]
    if {2 == $n} {
      set ds1 $ds
    }
    if {$n == $lastPoint} {
      set ds2 $ds
    }
    if {$ds > $maxDs} {
      set maxDs $ds
    }
  }
}


# Select one connector from GUI and use its parameters
proc acquireParams {} {
  global ds1 maxDs ds2

  set refCon ""
  set tempConList [pw::Grid getAll -type pw::Connector]
  
  set dimExists false
  foreach con $tempConList {
    if {[$con getDimension] > 0} {
      set dimExists true
      break
    }
  }

  if {false == $dimExists} {
    tk_messageBox -icon warning -message "There must be at least one \
      dimensioned connector to use this option!" -parent . \
      -title "No Dimensioned Connectors!" -type ok
    return
  }

  if {[pw::Grid getCount -type pw::Connector] > 0} {
    wm withdraw .
    pw::Display selectEntities -description "Pick connectors to get \
      parameters from:" -selectionmask [pw::Display createSelectionMask \
      -requireConnector Dimensioned] -single resultArray
    set refCon $resultArray(Connectors)
    if {$refCon != ""} {
      getParametersFromConnector $refCon
    }
    if {[winfo exists .]} {
      wm deiconify .
    }
  }
}


# Set the font for the title frame
proc setTitleFont { l } {
  global titleFont
  if { ! [info exists titleFont] } {
    set fontSize [font actual TkCaptionFont -size]
    set titleFont [font create -family [font actual TkCaptionFont -family] \
        -weight bold -size [expr {int(1.5 * $fontSize)}]]
  }
  $l configure -font $titleFont
}


# Build user interface
proc makeWindow { } {
  global w
  
  wm title . "Dimension Connectors"
  
  label $w(LabelTitle) -text "Dimension Connectors\nBased on End Spacings"
  setTitleFont $w(LabelTitle)

  frame $w(FrameMain)

  frame $w(FrameConnectors)
  button $w(ButtonPick) -text "Select Connectors" -command {set conList [pickConnectors]} -width 14
  button $w(ButtonClear) -text "Clear Selection" -command {set conList [list]} -width 14

  frame $w(FrameEntries)
  label $w(LabelDs1) -text "ds1" -anchor e
  entry $w(EntryDs1) -textvariable ds1
  label $w(LabelDs2) -text "ds2" -anchor e
  entry $w(EntryDs2) -textvariable ds2
  label $w(LabelMax) -text "max ds" -anchor e
  entry $w(EntryMax) -textvariable maxDs

  frame $w(FrameAcquire)
  button $w(ButtonAcquire) -text "Acquire Parameters" -command {acquireParams}

  frame $w(FrameButtons)
  button $w(ButtonCancel) -text "Cancel" -command {exit}
  button $w(ButtonApply) -text "Apply" -command {
    dimensionCons
    pw::Display update
  }
  button $w(ButtonOK) -text "OK" -command {
    $w(ButtonApply) invoke
    $w(ButtonCancel) invoke
  }
  label $w(Logo) -image [cadenceLogo] -bd 0 -relief flat
  
  pack $w(LabelTitle) -side top
  
  pack [frame .sp1 -bd 1 -height 2 -relief sunken] -side top -fill x -pady 5

  pack $w(FrameMain)

  pack $w(FrameConnectors)
  pack $w(ButtonPick) -padx 5 -side left
  pack $w(ButtonClear) -padx 5 -side right
  pack $w(FrameEntries) -pady 5 -padx 5
  grid $w(LabelDs1) $w(EntryDs1)
  grid $w(LabelDs2) $w(EntryDs2)
  grid $w(LabelMax) $w(EntryMax)
  
  pack $w(FrameAcquire) -fill both
  pack $w(ButtonAcquire) -padx 5 -side top
  
  pack [frame .sp2 -bd 1 -height 2 -relief sunken] -side top -fill x -pady 5
  
  pack $w(FrameButtons) -side bottom -fill x -ipadx 5 -ipady 2
  pack $w(ButtonCancel) -side right -padx 3
  pack $w(ButtonApply) -side right -padx 3
  pack $w(ButtonOK) -side right -padx 3
  pack $w(Logo) -side left -padx 3

  bind . <Key-Return> {$w(ButtonApply) invoke}
  bind . <Control-Key-Return> {$w(ButtonOK) invoke}
  bind . <Key-Escape> {$w(ButtonCancel) invoke}
  bind $w(ButtonOK) <Key-Return> {
    $w(ButtonOK) flash
    $w(ButtonOK) invoke
  }
  bind $w(ButtonApply) <Key-Return> {
    $w(ButtonApply) flash
    $w(ButtonApply) invoke
  }
  bind $w(ButtonCancel) <Key-Return> {
    $w(ButtonCancel) flash
    $w(ButtonCancel) invoke
  }

  wm resizable . 0 0
}



proc cadenceLogo {} {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

  return [image create photo -format GIF -data $logoData]
}

makeWindow
::tk::PlaceWindow . widget
tkwait window .

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
