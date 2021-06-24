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
  label $w(Logo) -image [pwLogo] -bd 0 -relief flat
  
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



proc pwLogo {} {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

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
