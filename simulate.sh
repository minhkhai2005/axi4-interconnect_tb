#!/bin/bash

# 1. Define variables
OUTPUT="sim_out.vvp"
LOG_FILE="compiler.log"
FLIST="flist.f"
WAVEFORM_FILE="tb_axi_interconnect.vcd"

# Default: do not show waveform
SHOW_GUI=false

# Check command line arguments
if [[ "$1" == "-gui" || "$1" == "--view" ]]; then
    SHOW_GUI=true
fi

echo "-----------------------------------------------"
echo "Starting build process with Icarus Verilog..."
echo "-----------------------------------------------"

# 2. Check if file list exists
if [ ! -f "$FLIST" ]; then
    echo "Error: File $FLIST not found!"
    exit 1
fi

# 3. Run iverilog
# -g2012: SystemVerilog support
# -f: Read file list
# -o: Output executable
iverilog -g2012 -f $FLIST -o $OUTPUT 2>&1 | tee $LOG_FILE

# 4. Check for compilation errors
if [ $? -eq 0 ]; then
    echo "-----------------------------------------------"
    echo "Build SUCCESSFUL! Running simulation..."
    echo "-----------------------------------------------"
    
    # 5. Run simulation with vvp
    vvp $OUTPUT
    
    # 6. Check GUI flag to decide whether to open GTKWave
    if [ "$SHOW_GUI" = true ]; then
        if [ -f "$WAVEFORM_FILE" ]; then
            echo "Opening GTKWave..."
            gtkwave $WAVEFORM_FILE &
        else
            echo "Warning: Waveform file $WAVEFORM_FILE not found."
        fi
    else
        echo "Simulation finished. (Use -gui flag to view waveform)"
    fi
else
    echo "-----------------------------------------------"
    echo "Build FAILED. Check $LOG_FILE for details."
    echo "-----------------------------------------------"
    exit 1
fi