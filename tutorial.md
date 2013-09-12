---
title: Getting Started with OpenRISC
---

# Getting Started with OpenRISC
 
<date class='right'>v2 - Updated 21 October 2012</date>
From FPGA to Linux Shell

Introduction
-------------

OpenRISC is a CPU architecture developed by the [OpenCores](http://opencores.org) community. OR1200 is an open-source Verilog implementation of the CPU core, and ORPSoC (OpenRISC Reference Platform System on Chip) combines the OR1200 CPU with a set of peripherals.

The system-on-chip can now synthesized on FPGAs that are now within reach of the hobbyist. This guide documents how to set up an OpenRISC build environment, load ORPSoC on an FPGA, and run Linux on the soft processor.

### Prerequisites

   * Experience with Linux systems, both on a standard distribution for the development machine, and a minimal system for the target
   * Compiling software from source
   * Basic understanding of digital logic, communications protocols, and electronics
   * Familiarity with Verilog and C (the more you know, the more you can do)

You'll also need a Linux workstation with about 15GB of free hard drive space and a fast internet connection. These instructions were developed on Debian, and updated and tested on Ubuntu 12.04. Other distributions may vary.

To use OpenRISC on physical hardware rather than just in simulation, you'll need an FPGA. This guide is built around Terasic's DE0 Nano. See the section below for more information.

You'll also need a 3.3V serial cable, such as a Nokia CA-42 clone or a FTDI cable.

### FPGA

This guide is built around [Terasic's DE0 Nano](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=139&No=593). It's a FPGA development board fairly well sized for supporting OpenRISC, at a price below $100 USD. DigiKey seems to be the best option for purchasing it in the United States. Terasic sells it directly and advertises a lower price, but will gouge you on shipping and money transfer fees.

Note that the DE0 Nano does not have a lot of peripherals on board, which is fine if you are comfortable adding on your own circuitry for things like VGA, as explained in a (currently unwritten) later chapter. The minimal configuration of ORPSoC with a serial port takes about half of the board's resources. Here's the [Altera fitter report](/openrisc/guide/fitreport.txt).

Other boards are also supported - see the [ORPSoC boards page](http://opencores.org/or1k/FPGA_Development_Boards). Some sections of this guide are specific to the DE0 Nano, and some are specific to Altera's toolchain.

### Resources

[OpenCores](http://opencores.org) - The parent site for OpenRISC and the surrounding modules that form ORPSoC. Note that opencores.org contains two sets of pages. There are the wiki pages and the older "project" pages. Some of the information on the project pages is out of date.

[git.openrisc.net](http://git.openrisc.net) hosts the source code for many OpenRISC subprojects. OpenRISC source code is scattered in a variety of other locations, including [GitHub](https://github.com/openrisc) and [OpenCores SVN](http://opencores.org/websvn,listing,openrisc).
 
Another great resource is the #opencores channel on freenode IRC. Special thanks to *stekern* (Stefan Kristiansson) for his troubleshooting help.

Toolchain & Linux
---------------------

### Dependencies

	sudo apt-get install libmpc-dev libgmp3-dev libmpfr-dev lzop libsdl1.2-dev xterm automake libtool

### Installing the Toolchain

To compile for the OpenRISC processor, you'll need a cross-compiler for the OpenRISC architecture. I've updated the [toolchain superproject](http://openrisc.net/toolchain-build.html), with more recent code, support for more recent Linux distributions, and automating additional steps.

Another option is [ORBuild](https://github.com/rdiez/orbuild), which seemed too heavyweight for the purposes of this guide, and doesn't include all of the tools.

To download and compile an OpenRISC toolchain and utilities:

	mkdir openrisc; cd openrisc/
	git clone https://github.com/kevinmehall/openrisc-tools-build.git toolchain
	cd toolchain
	git submodule update --init
	make PARALLEL=6 PREFIX=$PWD/../root

This will take a long time to download and build.

Using the new toolchain requires setting a few environment variables. Put the following in `openrisc_env.sh`, changing the install paths as appropriate:

	export OPENRISC=$HOME/openrisc
	export ALTERA_PATH=/opt/altera
	export ARCH=openrisc
	export CROSS_COMPILE=or32-linux-
	export PATH=$PATH:$OPENRISC/root/bin:$ALTERA_PATH/quartus/bin

Run `source openrisc_env.sh` to set up your shell for OpenRISC development

### Building the Kernel

The previous step already pulled down a copy of the Linux kernel source. 

	cd linux

Configure the kernel and compile it

	make defconfig
	make -j6 vmlinux

The kernel tree includes a pre-compiled copy of busybox in `arch/openrisc/support` that will be automatically used as an initial ramdisk.

### Running in Simulation

You can test out the kernel using or1ksim. Edit the file `arch/openrisc/or1ksim.cfg`, and change `channel = "tcp:10084"` to `channel = "xterm:"` around line 642 to see the output in a new terminal rather than using telnet.

Run

    or1ksim -f arch/openrisc/or1ksim.cfg vmlinux

to start the simulation. You'll see Linux boot, and you'll have a linux shell in the xterm.

<img src='/openrisc/guide/xterm-sim.png' alt='Screenshot of xterm running OpenRISC simulator' />

Running on Hardware
------------------------

### Installing Quartus

To synthesize Verilog into a bitfile to load onto the FPGA, you'll need Altera's Quartus II. [Download the 3GB installer from Altera](http://download.altera.com/akdlm/software/acds/12.0sp2/263/standalone/12.0sp2_263_quartus_free_linux.tar.gz?None&fileExt=.gz). (If the link is broken, you'll need to go to [altera.com](http://altera.com) and find the download for Quartus Free Edition for Linux. They'll make you enter an email address, but it doesn't have to be valid.)

	tar -xzvf 12.0sp2_263_quartus_free_linux.tar.gz
	12.0sp2_263_quartus_free_linux/setup

Follow the install wizard that appears after a few seconds.

If you're on a 64-bit platform, you need to make a symlink for it to be able to program the DE0 Nano's FPGA:

	ln -s altera/quartus/{linux,linux64}

### Synthesizing ORPSoC

Get a copy of the ORPSoC RTL:

    git clone git://openrisc.net/stefan/orpsoc

This includes the OpenRISC core, all the other peripherals such as the USART, VGA controller, etc., and the toplevel modules to combine them into a system on chip and integrate them with the hardware on the DE0 Nano board.

The board-specific parts for the DE0 Nano are in the `boards/altera/de0_nano` directory.

The default configuration puts the serial port on some inconvenient pins on the bottom header. Luckily, this being a soft processor, we can change that. Edit `syn/quartus/tcl/UART0_pin_assignments.tcl` to change the pins. 

	diff --git a/boards/altera/de0_nano/syn/quartus/tcl/UART0_pin_assignments.tcl b/boards/altera/de0_nano/syn/quartus/tcl/UART0_pin_assignments.tcl
	index 0b3ae0c..72f6904 100644
	--- a/boards/altera/de0_nano/syn/quartus/tcl/UART0_pin_assignments.tcl
	+++ b/boards/altera/de0_nano/syn/quartus/tcl/UART0_pin_assignments.tcl
	@@ -1,4 +1,4 @@
	-set_location_assignment PIN_C16 -to uart0_srx_pad_i
	+set_location_assignment PIN_D12 -to uart0_srx_pad_i
	 set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to uart0_srx_pad_i
	-set_location_assignment PIN_D15 -to uart0_stx_pad_o
	+set_location_assignment PIN_B12 -to uart0_stx_pad_o
	 set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to uart0_stx_pad_o

The diff above places the serial port on the far end of the GPIO-0 header:

<img src='/openrisc/guide/pins.jpg' alt='Serial pinout' />


If you've already run the makefile, `rm boards/altera/de0_nano/syn/quartus/run/orpsoc.tcl` to ensure it is regenerated with the updated pinout.

Then, run the synthesis

    cd boards/altera/de0_nano/syn/quartus/run
    make OR32_TOOL_PREFIX=or32-linux- all

You'll end up with a .sof file containing the FPGA bitstream, and several report files.

### Configuring Linux

The FPGA ORPSoC has a slightly different configuration than the simulator, which we need to tell the kernel about. Linux represents hardware as a device tree in a .dts file. I've created [a device tree for the DE0 Nano](/openrisc/guide/de0_nano.dts.txt). Put it in `arch/openrisc/boot/dts/de0_nano.dts`.

Compared to the or1ksim.dts, it sets the processor and UART clock speed to the correct 50MHz, and removes hardware like the ethernet controller that aren't present.

Tell the kernel to use it by running `make menuconfig`. Select *Processor type and Features* -> *Builtin DTB* and type de0_nano. Exit and save the configuration. Re-build with

    make vmlinux

### Serial console

You'll communicate with the OS running on the DE0 Nano with a serial cable. One of the popular choices is the Nokia CA-42 cable based on the PL2303 (clones are available for $2 on eBay), or various options based on chips from FTDI. Connect the cable with the pinout configured above.

### Putting it all together

You'll use JTAG to load the software onto the board and debug it, and a serial port to communicate with the running software. The JTAG adapter built into the DE0 Nano used for programming the FPGA can double as JTAG to the OpenRISC core.

I opened several terminal tabs to run the commands in parallel:

In `orpsoc/boards/altera/de0_nano/syn/quartus/run`, to load the ORPSoC bitstream onto the FPGA, run
	
	make pgm

You now have an OpenRISC system!

Open a serial terminal so you'll be ready to interact with it:

	screen /dev/ttyUSB0 115200

(press `ctrl-a \` to quit `screen` when you're done.)

In another terminal, start the openOCD server:

	cd ~/openrisc/toolchain/openOCD
	./src/openocd -f ./tcl/interface/altera-usb-blaster.cfg -f altera-dev.tcl
	
And finally, in a 4th terminal, use GDB in `linux/` to load and start the kernel image:

	or32-linux-gdb vmlinux --eval-command='target remote localhost:50001'

Type `load` to load the image into the FPGA's memory. This will take a minute. When it finishes, type `jump *0x100` to jump into the kernel. Switch back to the `screen` window, and you'll hopefully see Linux booting up.
