```sh
[    0.000000] Linux version 6.18.56-d630-gentoo (d630@github-actions) (gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0, GNU ld (GNU Binutils for Ubuntu) 2.42) #1 SMP PREEMPT_DYNAMIC Tue Oct 20 22:50:19 UTC 2026
[    0.000000] Command line: BOOT_IMAGE=(hd0,msdos1)/d630-tiny/kernel quiet
[    0.000000] BIOS-provided physical RAM map:
[    0.000000] BIOS-e820: [mem 0x0000000000000000-0x000000000009efff] usable
[    0.000000] BIOS-e820: [mem 0x000000000009f000-0x000000000009ffff] reserved
[    0.000000] BIOS-e820: [mem 0x0000000000100000-0x00000000df65a7ff] usable
[    0.000000] BIOS-e820: [mem 0x00000000df65a800-0x00000000dfffffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000f8000000-0x00000000fbffffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000fec00000-0x00000000fec0ffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000fed18000-0x00000000fed1bfff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000fed20000-0x00000000fed8ffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000feda0000-0x00000000feda5fff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000fee00000-0x00000000fee0ffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000ffe00000-0x00000000ffffffff] reserved
[    0.000000] BIOS-e820: [mem 0x0000000100000000-0x000000011fffffff] usable
[    0.000000] NX (Execute Disable) protection: active
[    0.000000] APIC: Static calls initialized
[    0.000000] SMBIOS 2.4 present.
[    0.000000] DMI: Dell Inc. Latitude D630                   /0KU184, BIOS A19 06/04/2013
[    0.000000] DMI: Memory slots populated: 2/2
[    0.000000] tsc: Fast TSC calibration using PIT
[    0.000000] tsc: Detected 1995.096 MHz processor
[    0.002722] e820: update [mem 0x00000000-0x00000fff] usable ==> reserved
[    0.002730] e820: remove [mem 0x000a0000-0x000fffff] usable
[    0.002749] last_pfn = 0x120000 max_arch_pfn = 0x400000000
[    0.002767] MTRR map: 8 entries (5 fixed + 3 variable; max 21), built from 8 variable MTRRs
[    0.002773] x86/PAT: Configuration [0-7]: WB  WC  UC- UC  WB  WP  UC- WT  
[    0.003914] e820: update [mem 0xdf700000-0xffffffff] usable ==> reserved
[    0.003935] last_pfn = 0xdf65a max_arch_pfn = 0x400000000
[    0.034934] RAMDISK: [mem 0x359cd000-0x36cddfff]
[    0.034951] ACPI: Early table checksum verification disabled
[    0.034961] ACPI: RSDP 0x00000000000FBB10 000024 (v02 DELL  )
[    0.034972] ACPI: XSDT 0x00000000DF65D200 000064 (v01 DELL   M08      27DD0604 ASL  00000061)
[    0.034991] ACPI: FACP 0x00000000DF65D09C 0000F4 (v04 DELL   M08      27DD0604 ASL  00000061)
[    0.035010] ACPI: DSDT 0x00000000DF65D800 006114 (v02 INT430 SYSFexxx 00001001 INTL 20050624)
[    0.035023] ACPI: FACS 0x00000000DF66C000 000040
[    0.035032] ACPI: FACS 0x00000000DF66C000 000040
[    0.035040] ACPI: HPET 0x00000000DF65D300 000038 (v01 DELL   M08      00000001 ASL  00000061)
[    0.035052] ACPI: APIC 0x00000000DF65D400 000068 (v01 DELL   M08      27DD0604 ASL  00000047)
[    0.035064] ACPI: ASF! 0x00000000DF65D000 00007E (v32 DELL   M08      27DD0604 ASL  00000061)
[    0.035077] ACPI: MCFG 0x00000000DF65D3C0 00003E (v16 DELL   M08      27DD0604 ASL  00000061)
[    0.035087] ACPI: TCPA 0x00000000DF65D700 000032 (v01                 00000000 ASL  00000000)
[    0.035099] ACPI: SLIC 0x00000000DF65D49C 000176 (v01 DELL   M08      27DD0604 ASL  00000061)
[    0.035111] ACPI: SSDT 0x00000000DF65B9C0 0004CC (v01 PmRef  CpuPm    00003000 INTL 20050624)
[    0.035120] ACPI: Reserving FACP table memory at [mem 0xdf65d09c-0xdf65d18f]
[    0.035126] ACPI: Reserving DSDT table memory at [mem 0xdf65d800-0xdf663913]
[    0.035131] ACPI: Reserving FACS table memory at [mem 0xdf66c000-0xdf66c03f]
[    0.035133] ACPI: Reserving FACS table memory at [mem 0xdf66c000-0xdf66c03f]
[    0.035137] ACPI: Reserving HPET table memory at [mem 0xdf65d300-0xdf65d337]
[    0.035140] ACPI: Reserving APIC table memory at [mem 0xdf65d400-0xdf65d467]
[    0.035145] ACPI: Reserving ASF! table memory at [mem 0xdf65d000-0xdf65d07d]
[    0.035147] ACPI: Reserving MCFG table memory at [mem 0xdf65d3c0-0xdf65d3fd]
[    0.035152] ACPI: Reserving TCPA table memory at [mem 0xdf65d700-0xdf65d731]
[    0.035154] ACPI: Reserving SLIC table memory at [mem 0xdf65d49c-0xdf65d611]
[    0.035158] ACPI: Reserving SSDT table memory at [mem 0xdf65b9c0-0xdf65be8b]
[    0.035244] Zone ranges:
[    0.035248]   DMA      [mem 0x0000000000001000-0x0000000000ffffff]
[    0.035255]   DMA32    [mem 0x0000000001000000-0x00000000ffffffff]
[    0.035261]   Normal   [mem 0x0000000100000000-0x000000011fffffff]
[    0.035264] Movable zone start for each node
[    0.035267] Early memory node ranges
[    0.035269]   node   0: [mem 0x0000000000001000-0x000000000009efff]
[    0.035274]   node   0: [mem 0x0000000000100000-0x00000000df659fff]
[    0.035278]   node   0: [mem 0x0000000100000000-0x000000011fffffff]
[    0.035283] Initmem setup node 0 [mem 0x0000000000001000-0x000000011fffffff]
[    0.035301] On node 0, zone DMA: 1 pages in unavailable ranges
[    0.035413] On node 0, zone DMA: 97 pages in unavailable ranges
[    0.092866] On node 0, zone Normal: 2470 pages in unavailable ranges
[    0.092893] Reserving Intel graphics memory at [mem 0xdf800000-0xdfffffff]
[    0.093378] ACPI: PM-Timer IO Port: 0x1008
[    0.093407] ACPI: LAPIC_NMI (acpi_id[0x00] high edge lint[0x1])
[    0.093413] ACPI: LAPIC_NMI (acpi_id[0x01] high edge lint[0x1])
[    0.093437] IOAPIC[0]: apic_id 2, version 32, address 0xfec00000, GSI 0-23
[    0.093449] ACPI: INT_SRC_OVR (bus 0 bus_irq 0 global_irq 2 dfl dfl)
[    0.093455] ACPI: INT_SRC_OVR (bus 0 bus_irq 9 global_irq 9 high level)
[    0.093470] ACPI: Using ACPI (MADT) for SMP configuration information
[    0.093475] ACPI: HPET id: 0x8086a201 base: 0xfed00000
[    0.093509] CPU topo: Max. logical packages:   1
[    0.093511] CPU topo: Max. logical dies:       1
[    0.093514] CPU topo: Max. dies per package:   1
[    0.093535] CPU topo: Max. threads per core:   1
[    0.093538] CPU topo: Num. cores per package:     2
[    0.093539] CPU topo: Num. threads per package:   2
[    0.093542] CPU topo: Allowing 2 present CPUs plus 0 hotplug CPUs
[    0.093578] PM: hibernation: Registered nosave memory: [mem 0x00000000-0x00000fff]
[    0.093584] PM: hibernation: Registered nosave memory: [mem 0x0009f000-0x000fffff]
[    0.093590] PM: hibernation: Registered nosave memory: [mem 0xdf65a000-0xffffffff]
[    0.093596] [mem 0xe0000000-0xf7ffffff] available for PCI devices
[    0.093606] clocksource: refined-jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 7645519600211568 ns
[    0.124420] setup_percpu: NR_CPUS:64 nr_cpumask_bits:2 nr_cpu_ids:2 nr_node_ids:1
[    0.125726] percpu: Embedded 43 pages/cpu s137240 r8192 d30696 u1048576
[    0.125747] pcpu-alloc: s137240 r8192 d30696 u1048576 alloc=1*2097152
[    0.125758] pcpu-alloc: [0] 0 1 
[    0.125810] Kernel command line: BOOT_IMAGE=(hd0,msdos1)/d630-tiny/kernel quiet
[    0.125919] printk: log buffer data + meta data: 262144 + 917504 = 1179648 bytes
[    0.129534] Dentry cache hash table entries: 524288 (order: 10, 4194304 bytes, linear)
[    0.131624] Inode-cache hash table entries: 262144 (order: 9, 2097152 bytes, linear)
[    0.131777] software IO TLB: area num 2.
[    0.243727] Built 1 zonelists, mobility grouping on.  Total pages: 1046008
[    0.243741] mem auto-init: stack:all(zero), heap alloc:off, heap free:off
[    0.308713] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=2, Nodes=1
[    0.308798] Kernel/User page tables isolation: enabled
[    0.310889] Dynamic Preempt: voluntary
[    0.310992] rcu: Preemptible hierarchical RCU implementation.
[    0.310994] rcu: 	RCU restricting CPUs from NR_CPUS=64 to nr_cpu_ids=2.
[    0.311001] rcu: RCU calculated value of scheduler-enlistment delay is 25 jiffies.
[    0.311005] rcu: Adjusting geometry for rcu_fanout_leaf=16, nr_cpu_ids=2
[    0.311039] NR_IRQS: 4352, nr_irqs: 440, preallocated irqs: 16
[    0.311398] rcu: srcu_init: Setting srcu_struct sizes based on contention.
[    0.311466] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 7645041785100000 ns
[    0.313844] Console: colour VGA+ 80x25
[    0.313853] printk: legacy console [tty0] enabled
[    0.313949] ACPI: Core revision 20250807
[    0.314154] clocksource: hpet: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 133484882848 ns
[    0.314191] APIC: Switch to symmetric I/O mode setup
[    0.314867] ..TIMER: vector=0x30 apic1=0 pin1=2 apic2=-1 pin2=-1
[    0.334188] clocksource: tsc-early: mask: 0xffffffffffffffff max_cycles: 0x39842b2cf4b, max_idle_ns: 881590633472 ns
[    0.334210] Calibrating delay loop (skipped), value calculated using timer frequency.. 3990.19 BogoMIPS (lpj=7980384)
[    0.334275] CPU0: Thermal monitoring enabled (TM2)
[    0.334312] Last level iTLB entries: 4KB 128, 2MB 4, 4MB 4
[    0.334318] Last level dTLB entries: 4KB 256, 2MB 0, 4MB 32, 1GB 0
[    0.334331] process: using mwait in idle threads
[    0.334338] mitigations: Enabled attack vectors: user_kernel, user_user, guest_host, guest_guest, SMT mitigations: auto
[    0.334358] Speculative Store Bypass: Vulnerable
[    0.334365] Spectre V2 : Mitigation: Retpolines
[    0.334368] MDS: Vulnerable: Clear CPU buffers attempted, no microcode
[    0.334373] Spectre V1 : Mitigation: usercopy/swapgs barriers and __user pointer sanitization
[    0.334379] Spectre V2 : Spectre v2 / SpectreRSB: Filling RSB on context switch and VMEXIT
[    0.334392] x86/fpu: x87 FPU will use FXSAVE
[    0.395423] Freeing SMP alternatives memory: 56K
[    0.395454] pid_max: default: 32768 minimum: 301
[    0.395539] LSM: initializing lsm=capability,selinux
[    0.395621] SELinux:  Initializing.
[    0.396278] Mount-cache hash table entries: 8192 (order: 4, 65536 bytes, linear)
[    0.396322] Mountpoint-cache hash table entries: 8192 (order: 4, 65536 bytes, linear)
[    0.508137] smpboot: CPU0: Intel(R) Core(TM)2 Duo CPU     T7250  @ 2.00GHz (family: 0x6, model: 0xf, stepping: 0xd)
[    0.508990] Performance Events: PEBS fmt0+, Core2 events, 4-deep LBR, Intel PMU driver.
[    0.509031] core: PEBS disabled due to CPU errata
[    0.509036] ... version:                   2
[    0.509039] ... bit width:                 40
[    0.509044] ... generic counters:          2
[    0.509049] ... generic bitmap:            0000000000000003
[    0.509052] ... fixed-purpose counters:    3
[    0.509056] ... fixed-purpose bitmap:      0000000000000007
[    0.509059] ... value mask:                000000ffffffffff
[    0.509064] ... max period:                000000007fffffff
[    0.509069] ... global_ctrl mask:          0000000700000003
[    0.509620] signal: max sigframe size: 1440
[    0.509787] rcu: Hierarchical SRCU implementation.
[    0.509793] rcu: 	Max phase no-delay instances is 1000.
[    0.510006] Timer migration: 1 hierarchy levels; 8 children per group; 1 crossnode level
[    0.510198] smp: Bringing up secondary CPUs ...
[    0.510198] smpboot: x86: Booting SMP configuration:
[    0.510198] .... node  #0, CPUs:      #1
[    0.510277] smp: Brought up 1 node, 2 CPUs
[    0.510277] smpboot: Total of 2 processors activated (7980.38 BogoMIPS)
[    0.512426] Memory: 3988312K/4184032K available (17844K kernel code, 1588K rwdata, 5448K rodata, 2572K init, 824K bss, 193388K reserved, 0K cma-reserved)
[    0.514753] devtmpfs: initialized
[    0.515212] posixtimers hash table entries: 1024 (order: 2, 16384 bytes, linear)
[    0.515246] futex hash table entries: 512 (32768 bytes on 1 NUMA nodes, total 32 KiB, linear).
[    0.515454] PM: RTC time: 03:45:29, date: 2026-10-29
[    0.515888] NET: Registered PF_NETLINK/PF_ROUTE protocol family
[    0.516260] audit: initializing netlink subsys (disabled)
[    0.516368] audit: type=2000 audit(1793245529.200:1): state=initialized audit_enabled=0 res=1
[    0.516697] thermal_sys: Registered thermal governor 'step_wise'
[    0.516743] cpuidle: using governor menu
[    0.517035] PCI: ECAM [mem 0xf8000000-0xfbffffff] (base 0xf8000000) for domain 0000 [bus 00-3f]
[    0.517051] PCI: ECAM [mem 0xf8000000-0xfbffffff] reserved as E820 entry
[    0.517077] PCI: Using configuration type 1 for base access
[    0.518422] HugeTLB: registered 2.00 MiB page size, pre-allocated 0 pages
[    0.518430] HugeTLB: 28 KiB vmemmap can be freed for a 2.00 MiB page
[    0.586208] raid6: sse2x4   gen()  3157 MB/s
[    0.654206] raid6: sse2x2   gen()  3011 MB/s
[    0.722209] raid6: sse2x1   gen()  2442 MB/s
[    0.722215] raid6: using algorithm sse2x4 gen() 3157 MB/s
[    0.790204] raid6: .... xor() 1645 MB/s, rmw enabled
[    0.790210] raid6: using ssse3x2 recovery algorithm
[    0.790373] ACPI: Added _OSI(Module Device)
[    0.790379] ACPI: Added _OSI(Processor Device)
[    0.790383] ACPI: Added _OSI(Processor Aggregator Device)
[    0.803872] ACPI: 2 ACPI AML tables successfully acquired and loaded
[    0.810543] ACPI: [Firmware Bug]: BIOS _OSI(Linux) query ignored
[    0.819117] ACPI: Dynamic OEM Table Load:
[    0.819140] ACPI: SSDT 0xFFFF9DFB801C8180 000043 (v01 LMPWR  DELLLOM  00001001 INTL 20050624)
[    0.822562] ACPI: Dynamic OEM Table Load:
[    0.822583] ACPI: SSDT 0xFFFF9DFB8032D400 000286 (v01 PmRef  Cpu0Ist  00003000 INTL 20050624)
[    0.824341] ACPI: Dynamic OEM Table Load:
[    0.824362] ACPI: SSDT 0xFFFF9DFB8022B800 0005E5 (v01 PmRef  Cpu0Cst  00003001 INTL 20050624)
[    0.826478] ACPI: Dynamic OEM Table Load:
[    0.826495] ACPI: SSDT 0xFFFF9DFB8023A900 0000C4 (v01 PmRef  Cpu1Ist  00003000 INTL 20050624)
[    0.827759] ACPI: Dynamic OEM Table Load:
[    0.827775] ACPI: SSDT 0xFFFF9DFB8027A240 000085 (v01 PmRef  Cpu1Cst  00003000 INTL 20050624)
[    0.829838] ACPI: Interpreter enabled
[    0.829890] ACPI: PM: (supports S0 S3 S4 S5)
[    0.829897] ACPI: Using IOAPIC for interrupt routing
[    0.829977] PCI: Using host bridge windows from ACPI; if necessary, use "pci=nocrs" and report a bug
[    0.829984] PCI: Using E820 reservations for host bridge windows
[    0.830641] ACPI: Enabled 13 GPEs in block 00 to 1F
[    0.966031] acpi PNP0C15:00: ACPI dock station (docks/bays count: 1)
[    1.020685] acpi LNXIOBAY:00: ACPI dock station (docks/bays count: 2)
[    1.022059] acpi LNXIOBAY:01: ACPI dock station (docks/bays count: 3)
[    1.128071] ACPI: PCI Root Bridge [PCI0] (domain 0000 [bus 00-ff])
[    1.128095] acpi PNP0A03:00: _OSC: OS supports [ExtendedConfig ASPM ClockPM Segments MSI HPX-Type3]
[    1.128116] acpi PNP0A03:00: [Firmware Info]: ECAM [mem 0xf8000000-0xfbffffff] for domain 0000 [bus 00-3f] only partially covers this bridge
[    1.153075] PCI host bridge to bus 0000:00
[    1.153090] pci_bus 0000:00: root bus resource [io  0x0000-0x0cf7 window]
[    1.153101] pci_bus 0000:00: root bus resource [io  0x0d00-0xffff window]
[    1.153108] pci_bus 0000:00: root bus resource [mem 0x000a0000-0x000bffff window]
[    1.153114] pci_bus 0000:00: root bus resource [mem 0x000d0000-0x000dffff window]
[    1.153119] pci_bus 0000:00: root bus resource [mem 0xe0000000-0xf7ffffff window]
[    1.153125] pci_bus 0000:00: root bus resource [mem 0xfc000000-0xfebfffff window]
[    1.153132] pci_bus 0000:00: root bus resource [mem 0xfec10000-0xfecfffff window]
[    1.153138] pci_bus 0000:00: root bus resource [mem 0xfed1c000-0xfed1ffff window]
[    1.153144] pci_bus 0000:00: root bus resource [mem 0xfed90000-0xfed9ffff window]
[    1.153150] pci_bus 0000:00: root bus resource [mem 0xfed40000-0xfed44fff window]
[    1.153157] pci_bus 0000:00: root bus resource [mem 0xfeda7000-0xfedfffff window]
[    1.153163] pci_bus 0000:00: root bus resource [mem 0xfee10000-0xff9fffff window]
[    1.153170] pci_bus 0000:00: root bus resource [mem 0xffc00000-0xffdfffff window]
[    1.153177] pci_bus 0000:00: root bus resource [bus 00-ff]
[    1.153231] pci 0000:00:00.0: [8086:2a00] type 00 class 0x060000 conventional PCI endpoint
[    1.153504] pci 0000:00:02.0: [8086:2a02] type 00 class 0x030000 conventional PCI endpoint
[    1.153557] pci 0000:00:02.0: BAR 0 [mem 0xf6e00000-0xf6efffff 64bit]
[    1.153569] pci 0000:00:02.0: BAR 2 [mem 0xe0000000-0xefffffff 64bit pref]
[    1.153577] pci 0000:00:02.0: BAR 4 [io  0xeff8-0xefff]
[    1.153606] pci 0000:00:02.0: Video device with shadowed ROM at [mem 0x000c0000-0x000dffff]
[    1.153925] pci 0000:00:02.1: [8086:2a03] type 00 class 0x038000 conventional PCI endpoint
[    1.153978] pci 0000:00:02.1: BAR 0 [mem 0xf6f00000-0xf6ffffff 64bit]
[    1.154371] pci 0000:00:1a.0: [8086:2834] type 00 class 0x0c0300 conventional PCI endpoint
[    1.154481] pci 0000:00:1a.0: BAR 4 [io  0x6f20-0x6f3f]
[    1.154795] pci 0000:00:1a.1: [8086:2835] type 00 class 0x0c0300 conventional PCI endpoint
[    1.154903] pci 0000:00:1a.1: BAR 4 [io  0x6f00-0x6f1f]
[    1.155250] pci 0000:00:1a.7: [8086:283a] type 00 class 0x0c0320 conventional PCI endpoint
[    1.155349] pci 0000:00:1a.7: BAR 0 [mem 0xfed1c400-0xfed1c7ff]
[    1.155450] pci 0000:00:1a.7: PME# supported from D0 D3hot D3cold
[    1.155790] pci 0000:00:1b.0: [8086:284b] type 00 class 0x040300 PCIe Root Complex Integrated Endpoint
[    1.155892] pci 0000:00:1b.0: BAR 0 [mem 0xf6dfc000-0xf6dfffff 64bit]
[    1.156040] pci 0000:00:1b.0: PME# supported from D0 D3hot D3cold
[    1.156380] pci 0000:00:1c.0: [8086:283f] type 01 class 0x060400 PCIe Root Port
[    1.156449] pci 0000:00:1c.0: PCI bridge to [bus 0b]
[    1.156634] pci 0000:00:1c.0: PME# supported from D0 D3hot D3cold
[    1.156990] pci 0000:00:1c.1: [8086:2841] type 01 class 0x060400 PCIe Root Port
[    1.157059] pci 0000:00:1c.1: PCI bridge to [bus 0c]
[    1.157079] pci 0000:00:1c.1:   bridge window [mem 0xf6c00000-0xf6cfffff]
[    1.157251] pci 0000:00:1c.1: PME# supported from D0 D3hot D3cold
[    1.157624] pci 0000:00:1c.5: [8086:2849] type 01 class 0x060400 PCIe Root Port
[    1.157692] pci 0000:00:1c.5: PCI bridge to [bus 09]
[    1.157875] pci 0000:00:1c.5: PME# supported from D0 D3hot D3cold
[    1.158229] pci 0000:00:1d.0: [8086:2830] type 00 class 0x0c0300 conventional PCI endpoint
[    1.158337] pci 0000:00:1d.0: BAR 4 [io  0x6f80-0x6f9f]
[    1.158658] pci 0000:00:1d.1: [8086:2831] type 00 class 0x0c0300 conventional PCI endpoint
[    1.158767] pci 0000:00:1d.1: BAR 4 [io  0x6f60-0x6f7f]
[    1.159078] pci 0000:00:1d.2: [8086:2832] type 00 class 0x0c0300 conventional PCI endpoint
[    1.159187] pci 0000:00:1d.2: BAR 4 [io  0x6f40-0x6f5f]
[    1.159523] pci 0000:00:1d.7: [8086:2836] type 00 class 0x0c0320 conventional PCI endpoint
[    1.159622] pci 0000:00:1d.7: BAR 0 [mem 0xfed1c000-0xfed1c3ff]
[    1.159722] pci 0000:00:1d.7: PME# supported from D0 D3hot D3cold
[    1.160061] pci 0000:00:1e.0: [8086:2448] type 01 class 0x060401 conventional PCI bridge
[    1.160129] pci 0000:00:1e.0: PCI bridge to [bus 03] (subtractive decode)
[    1.160544] pci 0000:00:1f.0: [8086:2815] type 00 class 0x060100 conventional PCI endpoint
[    1.160703] pci 0000:00:1f.0: quirk: [io  0x1000-0x107f] claimed by ICH6 ACPI/GPIO/TCO
[    1.160719] pci 0000:00:1f.0: quirk: [io  0x1080-0x10bf] claimed by ICH6 GPIO
[    1.160729] pci 0000:00:1f.0: ICH7 LPC Generic IO decode 1 PIO at 0900 (mask 007f)
[    1.160743] pci 0000:00:1f.0: ICH7 LPC Generic IO decode 3 PIO at 0c80 (mask 003f)
[    1.161164] pci 0000:00:1f.1: [8086:2850] type 00 class 0x01018a conventional PCI endpoint
[    1.161265] pci 0000:00:1f.1: BAR 0 [io  0x01f0-0x01f7]
[    1.161273] pci 0000:00:1f.1: BAR 1 [io  0x03f4-0x03f7]
[    1.161281] pci 0000:00:1f.1: BAR 2 [io  0x0170-0x0177]
[    1.161291] pci 0000:00:1f.1: BAR 3 [io  0x0374-0x0377]
[    1.161299] pci 0000:00:1f.1: BAR 4 [io  0x6fa0-0x6faf]
[    1.161315] pci 0000:00:1f.1: BAR 0 [io  0x01f0-0x01f7]: legacy IDE quirk
[    1.161322] pci 0000:00:1f.1: BAR 1 [io  0x03f6]: legacy IDE quirk
[    1.161328] pci 0000:00:1f.1: BAR 2 [io  0x0170-0x0177]: legacy IDE quirk
[    1.161334] pci 0000:00:1f.1: BAR 3 [io  0x0376]: legacy IDE quirk
[    1.161638] pci 0000:00:1f.2: [8086:2829] type 00 class 0x010601 conventional PCI endpoint
[    1.161739] pci 0000:00:1f.2: BAR 0 [io  0x6eb0-0x6eb7]
[    1.161748] pci 0000:00:1f.2: BAR 1 [io  0x6eb8-0x6ebb]
[    1.161756] pci 0000:00:1f.2: BAR 2 [io  0x6ec0-0x6ec7]
[    1.161766] pci 0000:00:1f.2: BAR 3 [io  0x6ec8-0x6ecb]
[    1.161774] pci 0000:00:1f.2: BAR 4 [io  0x6ee0-0x6eff]
[    1.161782] pci 0000:00:1f.2: BAR 5 [mem 0xf6dfb800-0xf6dfbfff]
[    1.161881] pci 0000:00:1f.2: PME# supported from D3hot
[    1.162179] pci 0000:00:1f.3: [8086:283e] type 00 class 0x0c0500 conventional PCI endpoint
[    1.162288] pci 0000:00:1f.3: BAR 0 [mem 0xf6dfb700-0xf6dfb7ff]
[    1.162306] pci 0000:00:1f.3: BAR 4 [io  0x10c0-0x10df]
[    1.162581] pci 0000:00:1c.0: PCI bridge to [bus 0b]
[    1.162891] pci 0000:0c:00.0: [8086:4222] type 00 class 0x028000 PCIe Legacy Endpoint
[    1.163188] pci 0000:0c:00.0: BAR 0 [mem 0xf6cff000-0xf6cfffff]
[    1.163631] pci 0000:0c:00.0: PME# supported from D0 D3hot D3cold
[    1.164153] pci 0000:0c:00.0: disabling ASPM on pre-1.1 PCIe device.  You can enable it with 'pcie_aspm=force'
[    1.164258] pci 0000:00:1c.1: PCI bridge to [bus 0c]
[    1.164399] pci 0000:00:1c.5: PCI bridge to [bus 09]
[    1.164470] pci_bus 0000:03: extended config space not accessible
[    1.164611] pci 0000:00:1e.0: PCI bridge to [bus 03] (subtractive decode)
[    1.164636] pci 0000:00:1e.0:   bridge window [io  0x0000-0x0cf7 window] (subtractive decode)
[    1.164646] pci 0000:00:1e.0:   bridge window [io  0x0d00-0xffff window] (subtractive decode)
[    1.164653] pci 0000:00:1e.0:   bridge window [mem 0x000a0000-0x000bffff window] (subtractive decode)
[    1.164659] pci 0000:00:1e.0:   bridge window [mem 0x000d0000-0x000dffff window] (subtractive decode)
[    1.164666] pci 0000:00:1e.0:   bridge window [mem 0xe0000000-0xf7ffffff window] (subtractive decode)
[    1.164670] pci 0000:00:1e.0:   bridge window [mem 0xfc000000-0xfebfffff window] (subtractive decode)
[    1.164677] pci 0000:00:1e.0:   bridge window [mem 0xfec10000-0xfecfffff window] (subtractive decode)
[    1.164683] pci 0000:00:1e.0:   bridge window [mem 0xfed1c000-0xfed1ffff window] (subtractive decode)
[    1.164690] pci 0000:00:1e.0:   bridge window [mem 0xfed90000-0xfed9ffff window] (subtractive decode)
[    1.164696] pci 0000:00:1e.0:   bridge window [mem 0xfed40000-0xfed44fff window] (subtractive decode)
[    1.164703] pci 0000:00:1e.0:   bridge window [mem 0xfeda7000-0xfedfffff window] (subtractive decode)
[    1.164715] pci 0000:00:1e.0:   bridge window [mem 0xfee10000-0xff9fffff window] (subtractive decode)
[    1.164721] pci 0000:00:1e.0:   bridge window [mem 0xffc00000-0xffdfffff window] (subtractive decode)
[    1.164781] pci_bus 0000:00: on NUMA node 0
[    1.189893] ACPI: PCI: Interrupt link LNKA configured for IRQ 11
[    1.190206] ACPI: PCI: Interrupt link LNKB configured for IRQ 5
[    1.190505] ACPI: PCI: Interrupt link LNKC configured for IRQ 10
[    1.190762] ACPI: PCI: Interrupt link LNKD configured for IRQ 0
[    1.190769] ACPI: PCI: Interrupt link LNKD disabled
[    1.191064] ACPI: PCI: Interrupt link LNKE configured for IRQ 10
[    1.191361] ACPI: PCI: Interrupt link LNKF configured for IRQ 9
[    1.191658] ACPI: PCI: Interrupt link LNKG configured for IRQ 7
[    1.191917] ACPI: PCI: Interrupt link LNKH configured for IRQ 0
[    1.191924] ACPI: PCI: Interrupt link LNKH disabled
[    1.193028] iommu: Default domain type: Translated
[    1.193036] iommu: DMA domain TLB invalidation policy: lazy mode
[    1.193112] SCSI subsystem initialized
[    1.193112] libata version 3.00 loaded.
[    1.193112] ACPI: bus type USB registered
[    1.193112] usbcore: registered new interface driver usbfs
[    1.193112] usbcore: registered new interface driver hub
[    1.193112] usbcore: registered new device driver usb
[    1.193112] pps_core: LinuxPPS API ver. 1 registered
[    1.193112] pps_core: Software ver. 5.3.6 - Copyright 2005-2007 Rodolfo Giometti <giometti@linux.it>
[    1.193112] PTP clock support registered
[    1.193112] Advanced Linux Sound Architecture Driver Initialized.
[    1.194634] Bluetooth: Core ver 2.22
[    1.194663] NET: Registered PF_BLUETOOTH protocol family
[    1.194670] Bluetooth: HCI device and connection manager initialized
[    1.194678] Bluetooth: HCI socket layer initialized
[    1.194684] Bluetooth: L2CAP socket layer initialized
[    1.194704] Bluetooth: SCO socket layer initialized
[    1.194791] NetLabel: Initializing
[    1.194795] NetLabel:  domain hash size = 128
[    1.194799] NetLabel:  protocols = UNLABELED CIPSOv4 CALIPSO
[    1.194859] NetLabel:  unlabeled traffic allowed by default
[    1.194926] PCI: Using ACPI for IRQ routing
[    1.199358] PCI: pci_cache_line_size set to 64 bytes
[    1.199493] e820: reserve RAM buffer [mem 0x0009f000-0x0009ffff]
[    1.199501] e820: reserve RAM buffer [mem 0xdf65a800-0xdfffffff]
[    1.199551] pci 0000:00:02.0: vgaarb: setting as boot VGA device
[    1.199551] pci 0000:00:02.0: vgaarb: bridge control possible
[    1.199551] pci 0000:00:02.0: vgaarb: VGA device added: decodes=io+mem,owns=io+mem,locks=none
[    1.199551] vgaarb: loaded
[    1.199551] wmi_bus wmi_bus-PNP0C14:00: [Firmware Bug]: WQBC data block query control method not found
[    1.199551] hpet: 3 channels of 0 reserved for per-cpu timers
[    1.199551] hpet0: at MMIO 0xfed00000, IRQs 2, 8, 0
[    1.199551] hpet0: 3 comparators, 64-bit 14.318180 MHz counter
[    1.202273] clocksource: Switched to clocksource tsc-early
[    1.202509] VFS: Disk quotas dquot_6.6.0
[    1.202530] VFS: Dquot-cache hash table entries: 512 (order 0, 4096 bytes)
[    1.202822] pnp: PnP ACPI init
[    1.203315] system 00:02: [io  0x0c80-0x0caf] has been reserved
[    1.203343] system 00:02: [io  0x0cc0-0x0cff] could not be reserved
[    1.203616] system 00:03: [mem 0xfed00000-0xfed003ff] has been reserved
[    1.315877] system 00:04: [io  0x0cb0-0x0cbb] has been reserved
[    1.315888] system 00:04: [mem 0xfed40000-0xfed44fff] has been reserved
[    1.319413] pnp 00:05: disabling [io  0x1000-0x1005] because it overlaps 0000:00:1f.0 BAR 7 [io  0x1000-0x107f]
[    1.319427] pnp 00:05: disabling [io  0x1008-0x100f] because it overlaps 0000:00:1f.0 BAR 7 [io  0x1000-0x107f]
[    1.319528] system 00:05: [io  0x0900-0x097f] has been reserved
[    1.319540] system 00:05: [io  0x04d0-0x04d1] has been reserved
[    1.319642] pnp 00:06: disabling [io  0x1006-0x1007] because it overlaps 0000:00:1f.0 BAR 7 [io  0x1000-0x107f]
[    1.319654] pnp 00:06: disabling [io  0x100a-0x1059] because it overlaps 0000:00:1f.0 BAR 7 [io  0x1000-0x107f]
[    1.319662] pnp 00:06: disabling [io  0x1060-0x107f] because it overlaps 0000:00:1f.0 BAR 7 [io  0x1000-0x107f]
[    1.319670] pnp 00:06: disabling [io  0x1010-0x102f] because it overlaps 0000:00:1f.0 BAR 7 [io  0x1000-0x107f]
[    1.319759] system 00:06: [io  0xf400-0xf4fe] has been reserved
[    1.319769] system 00:06: [io  0x1080-0x10bf] has been reserved
[    1.319777] system 00:06: [io  0x10c0-0x10df] has been reserved
[    1.319784] system 00:06: [io  0x0809] has been reserved
[    1.352999] pnp 00:07: disabling [mem 0x000c0000-0x000cffff] because it overlaps 0000:00:02.0 BAR 6 [mem 0x000c0000-0x000dffff]
[    1.353125] system 00:07: [mem 0x00000000-0x0009efff] could not be reserved
[    1.353137] system 00:07: [mem 0x0009f000-0x0009ffff] could not be reserved
[    1.353144] system 00:07: [mem 0x000e0000-0x000fffff] could not be reserved
[    1.353151] system 00:07: [mem 0x00100000-0xdf65a7ff] could not be reserved
[    1.353158] system 00:07: [mem 0xdf65a800-0xdf6fffff] has been reserved
[    1.353165] system 00:07: [mem 0xdf700000-0xdf7fffff] has been reserved
[    1.353172] system 00:07: [mem 0xdf700000-0xdfefffff] could not be reserved
[    1.353181] system 00:07: [mem 0xffe00000-0xffffffff] has been reserved
[    1.353188] system 00:07: [mem 0xffa00000-0xffbfffff] has been reserved
[    1.353196] system 00:07: [mem 0xfec00000-0xfec0ffff] could not be reserved
[    1.353202] system 00:07: [mem 0xfee00000-0xfee0ffff] has been reserved
[    1.353209] system 00:07: [mem 0xfed20000-0xfed3ffff] has been reserved
[    1.353216] system 00:07: [mem 0xfed45000-0xfed8ffff] has been reserved
[    1.353223] system 00:07: [mem 0xfeda0000-0xfeda3fff] has been reserved
[    1.353230] system 00:07: [mem 0xfeda4000-0xfeda4fff] has been reserved
[    1.353237] system 00:07: [mem 0xfeda5000-0xfeda5fff] has been reserved
[    1.353244] system 00:07: [mem 0xfeda6000-0xfeda6fff] has been reserved
[    1.353251] system 00:07: [mem 0xfed18000-0xfed1bfff] has been reserved
[    1.353258] system 00:07: [mem 0xf8000000-0xfbffffff] has been reserved
[    1.353438] pnp: PnP ACPI: found 8 devices
[    1.364141] clocksource: acpi_pm: mask: 0xffffff max_cycles: 0xffffff, max_idle_ns: 2085701024 ns
[    1.364241] NET: Registered PF_INET protocol family
[    1.364617] IP idents hash table entries: 65536 (order: 7, 524288 bytes, linear)
[    1.367942] tcp_listen_portaddr_hash hash table entries: 2048 (order: 3, 32768 bytes, linear)
[    1.367976] Table-perturb hash table entries: 65536 (order: 6, 262144 bytes, linear)
[    1.367988] TCP established hash table entries: 32768 (order: 6, 262144 bytes, linear)
[    1.368161] TCP bind hash table entries: 32768 (order: 8, 1048576 bytes, linear)
[    1.368842] TCP: Hash tables configured (established 32768 bind 32768)
[    1.368982] UDP hash table entries: 2048 (order: 5, 131072 bytes, linear)
[    1.369108] UDP-Lite hash table entries: 2048 (order: 5, 131072 bytes, linear)
[    1.369372] NET: Registered PF_UNIX/PF_LOCAL protocol family
[    1.371097] pci 0000:00:1c.0: bridge window [io  0x1000-0x0fff] to [bus 0b] add_size 1000
[    1.371117] pci 0000:00:1c.0: bridge window [mem 0x00100000-0x000fffff 64bit pref] to [bus 0b] add_size 200000 add_align 100000
[    1.371129] pci 0000:00:1c.0: bridge window [mem 0x00100000-0x000fffff] to [bus 0b] add_size 200000 add_align 100000
[    1.371142] pci 0000:00:1c.1: bridge window [io  0x1000-0x0fff] to [bus 0c] add_size 1000
[    1.371150] pci 0000:00:1c.1: bridge window [mem 0x00100000-0x000fffff 64bit pref] to [bus 0c] add_size 200000 add_align 100000
[    1.371159] pci 0000:00:1c.5: bridge window [io  0x1000-0x0fff] to [bus 09] add_size 1000
[    1.371169] pci 0000:00:1c.5: bridge window [mem 0x00100000-0x000fffff 64bit pref] to [bus 09] add_size 200000 add_align 100000
[    1.371177] pci 0000:00:1c.5: bridge window [mem 0x00100000-0x000fffff] to [bus 09] add_size 200000 add_align 100000
[    1.371219] pci 0000:00:1c.0: bridge window [mem 0xf0000000-0xf01fffff]: assigned
[    1.371238] pci 0000:00:1c.0: bridge window [mem 0xf0200000-0xf03fffff 64bit pref]: assigned
[    1.371253] pci 0000:00:1c.1: bridge window [mem 0xf0400000-0xf05fffff 64bit pref]: assigned
[    1.371261] pci 0000:00:1c.5: bridge window [mem 0xf0600000-0xf07fffff]: assigned
[    1.371277] pci 0000:00:1c.5: bridge window [mem 0xf0800000-0xf09fffff 64bit pref]: assigned
[    1.371287] pci 0000:00:1c.0: bridge window [io  0x2000-0x2fff]: assigned
[    1.371298] pci 0000:00:1c.1: bridge window [io  0x3000-0x3fff]: assigned
[    1.371306] pci 0000:00:1c.5: bridge window [io  0x4000-0x4fff]: assigned
[    1.371319] pci 0000:00:1c.0: PCI bridge to [bus 0b]
[    1.371332] pci 0000:00:1c.0:   bridge window [io  0x2000-0x2fff]
[    1.371347] pci 0000:00:1c.0:   bridge window [mem 0xf0000000-0xf01fffff]
[    1.371357] pci 0000:00:1c.0:   bridge window [mem 0xf0200000-0xf03fffff 64bit pref]
[    1.371376] pci 0000:00:1c.1: PCI bridge to [bus 0c]
[    1.371384] pci 0000:00:1c.1:   bridge window [io  0x3000-0x3fff]
[    1.371397] pci 0000:00:1c.1:   bridge window [mem 0xf6c00000-0xf6cfffff]
[    1.371409] pci 0000:00:1c.1:   bridge window [mem 0xf0400000-0xf05fffff 64bit pref]
[    1.371425] pci 0000:00:1c.5: PCI bridge to [bus 09]
[    1.371432] pci 0000:00:1c.5:   bridge window [io  0x4000-0x4fff]
[    1.371446] pci 0000:00:1c.5:   bridge window [mem 0xf0600000-0xf07fffff]
[    1.371457] pci 0000:00:1c.5:   bridge window [mem 0xf0800000-0xf09fffff 64bit pref]
[    1.371474] pci 0000:00:1e.0: PCI bridge to [bus 03]
[    1.371502] pci_bus 0000:00: resource 4 [io  0x0000-0x0cf7 window]
[    1.371509] pci_bus 0000:00: resource 5 [io  0x0d00-0xffff window]
[    1.371516] pci_bus 0000:00: resource 6 [mem 0x000a0000-0x000bffff window]
[    1.371522] pci_bus 0000:00: resource 7 [mem 0x000d0000-0x000dffff window]
[    1.371529] pci_bus 0000:00: resource 8 [mem 0xe0000000-0xf7ffffff window]
[    1.371535] pci_bus 0000:00: resource 9 [mem 0xfc000000-0xfebfffff window]
[    1.371541] pci_bus 0000:00: resource 10 [mem 0xfec10000-0xfecfffff window]
[    1.371548] pci_bus 0000:00: resource 11 [mem 0xfed1c000-0xfed1ffff window]
[    1.371555] pci_bus 0000:00: resource 12 [mem 0xfed90000-0xfed9ffff window]
[    1.371561] pci_bus 0000:00: resource 13 [mem 0xfed40000-0xfed44fff window]
[    1.371568] pci_bus 0000:00: resource 14 [mem 0xfeda7000-0xfedfffff window]
[    1.371574] pci_bus 0000:00: resource 15 [mem 0xfee10000-0xff9fffff window]
[    1.371581] pci_bus 0000:00: resource 16 [mem 0xffc00000-0xffdfffff window]
[    1.371588] pci_bus 0000:0b: resource 0 [io  0x2000-0x2fff]
[    1.371594] pci_bus 0000:0b: resource 1 [mem 0xf0000000-0xf01fffff]
[    1.371600] pci_bus 0000:0b: resource 2 [mem 0xf0200000-0xf03fffff 64bit pref]
[    1.371607] pci_bus 0000:0c: resource 0 [io  0x3000-0x3fff]
[    1.371613] pci_bus 0000:0c: resource 1 [mem 0xf6c00000-0xf6cfffff]
[    1.371620] pci_bus 0000:0c: resource 2 [mem 0xf0400000-0xf05fffff 64bit pref]
[    1.371626] pci_bus 0000:09: resource 0 [io  0x4000-0x4fff]
[    1.371631] pci_bus 0000:09: resource 1 [mem 0xf0600000-0xf07fffff]
[    1.371637] pci_bus 0000:09: resource 2 [mem 0xf0800000-0xf09fffff 64bit pref]
[    1.371644] pci_bus 0000:03: resource 4 [io  0x0000-0x0cf7 window]
[    1.371650] pci_bus 0000:03: resource 5 [io  0x0d00-0xffff window]
[    1.371656] pci_bus 0000:03: resource 6 [mem 0x000a0000-0x000bffff window]
[    1.371663] pci_bus 0000:03: resource 7 [mem 0x000d0000-0x000dffff window]
[    1.371669] pci_bus 0000:03: resource 8 [mem 0xe0000000-0xf7ffffff window]
[    1.371676] pci_bus 0000:03: resource 9 [mem 0xfc000000-0xfebfffff window]
[    1.371682] pci_bus 0000:03: resource 10 [mem 0xfec10000-0xfecfffff window]
[    1.371689] pci_bus 0000:03: resource 11 [mem 0xfed1c000-0xfed1ffff window]
[    1.371695] pci_bus 0000:03: resource 12 [mem 0xfed90000-0xfed9ffff window]
[    1.371702] pci_bus 0000:03: resource 13 [mem 0xfed40000-0xfed44fff window]
[    1.371708] pci_bus 0000:03: resource 14 [mem 0xfeda7000-0xfedfffff window]
[    1.371712] pci_bus 0000:03: resource 15 [mem 0xfee10000-0xff9fffff window]
[    1.371718] pci_bus 0000:03: resource 16 [mem 0xffc00000-0xffdfffff window]
[    1.377016] PCI: CLS 64 bytes, default 64
[    1.377046] PCI-DMA: Using software bounce buffering for IO (SWIOTLB)
[    1.377052] software IO TLB: mapped [mem 0x00000000db65a000-0x00000000df65a000] (64MB)
[    1.377364] Unpacking initramfs...
[    1.381990] Initialise system trusted keyrings
[    1.384718] workingset: timestamp_bits=62 max_order=20 bucket_order=0
[    1.384956] squashfs: version 4.0 (2009/01/31) Phillip Lougher
[    1.384997] ntfs3: Enabled Linux POSIX ACLs support
[    1.385002] ntfs3: Warning: Activated 64 bits per cluster. Windows does not support this
[    1.443803] xor: measuring software checksum speed
[    1.444581]    prefetch64-sse  :  4323 MB/sec
[    1.445474]    generic_sse     :  3720 MB/sec
[    1.445477] xor: using function: prefetch64-sse (4323 MB/sec)
[    1.445489] Key type asymmetric registered
[    1.445495] Asymmetric key parser 'x509' registered
[    1.445594] Block layer SCSI generic (bsg) driver version 0.4 loaded (major 251)
[    1.445639] io scheduler mq-deadline registered
[    1.445646] io scheduler kyber registered
[    1.448287] ACPI: AC: AC Adapter [AC] (on-line)
[    1.448546] input: Lid Switch as /devices/LNXSYSTM:00/LNXSYBUS:00/PNP0C0D:00/input/input0
[    1.448715] ACPI: button: Lid Switch [LID]
[    1.448850] input: Power Button as /devices/LNXSYSTM:00/LNXSYBUS:00/PNP0C0C:00/input/input1
[    1.448979] ACPI: button: Power Button [PBTN]
[    1.449110] input: Sleep Button as /devices/LNXSYSTM:00/LNXSYBUS:00/PNP0C0E:00/input/input2
[    1.449217] ACPI: button: Sleep Button [SBTN]
[    1.449612] Monitor-Mwait will be used to enter C-1 state
[    1.449632] Monitor-Mwait will be used to enter C-2 state
[    1.449645] Monitor-Mwait will be used to enter C-3 state
[    1.449655] tsc: Marking TSC unstable due to TSC halts in idle
[    1.450973] clocksource: Switched to clocksource hpet
[    1.464757] thermal LNXTHERM:00: registered as thermal_zone0
[    1.464772] ACPI: thermal: Thermal Zone [THM] (58 C)
[    1.465406] Serial: 8250/16550 driver, 4 ports, IRQ sharing enabled
[    1.466961] ACPI: battery: Slot [BAT0] (battery absent)
[    1.467176] ACPI: battery: Slot [BAT1] (battery absent)
[    1.467709] Non-volatile memory driver v1.3
[    1.467721] Linux agpgart interface v0.103
[    1.468034] ACPI: bus type drm_connector registered
[    1.468609] i915 0000:00:02.0: [drm] Found i965gm (device ID 2a02) integrated display version 4.00 stepping N/A
[    1.471510] pci 0000:00:00.0: Intel 965GM Chipset
[    1.471562] pci 0000:00:00.0: detected gtt size: 524288K total, 262144K mappable
[    1.472006] pci 0000:00:00.0: detected 8192K stolen memory
[    1.472130] i915 0000:00:02.0: vgaarb: deactivate vga console
[    1.473002] Console: switching to colour dummy device 80x25
[    1.602130] i915 0000:00:02.0: vgaarb: VGA decodes changed: olddecodes=io+mem,decodes=io+mem:owns=io+mem
[    1.622292] i915 0000:00:02.0: [drm] Initialized overlay support.
[    1.623868] [drm] Initialized i915 1.6.0 for 0000:00:02.0 on minor 0
[    1.624443] ACPI: video: Video Device [VID1] (multi-head: yes  rom: no  post: no)
[    1.625024] input: Video Bus as /devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/LNXVIDEO:01/input/input3
[    1.625095] ACPI: video: [Firmware Bug]: Duplicate ACPI video bus devices for the same VGA controller, please try module parameter "video.allow_duplicates=1"if the current driver doesn't work.
[    2.159170] Freeing initrd memory: 19524K
[    2.694631] Console: switching to colour frame buffer device 180x56
[    2.713916] i915 0000:00:02.0: [drm] fb0: i915drmfb frame buffer device
[    2.719801] loop: module loaded
[    2.720261] zram: Added device: zram0
[    2.721362] ahci 0000:00:1f.2: AHCI vers 0001.0100, 32 command slots, 3 Gbps, SATA mode
[    2.721376] ahci 0000:00:1f.2: 2/3 ports implemented (port mask 0x5)
[    2.721386] ahci 0000:00:1f.2: flags: 64bit ncq sntf pm led clo pio slum part ccc ems 
[    2.727842] scsi host0: ahci
[    2.728283] scsi host1: ahci
[    2.728691] scsi host2: ahci
[    2.728885] ata1: SATA max UDMA/133 abar m2048@0xf6dfb800 port 0xf6dfb900 irq 24 lpm-pol 3
[    2.728893] ata2: DUMMY
[    2.728899] ata3: SATA max UDMA/133 abar m2048@0xf6dfb800 port 0xf6dfba00 irq 24 lpm-pol 3
[    2.731855] scsi host3: ata_piix
[    2.734279] scsi host4: ata_piix
[    2.734424] ata4: PATA max UDMA/100 cmd 0x1f0 ctl 0x3f6 bmdma 0x6fa0 irq 14 lpm-pol 0
[    2.734432] ata5: PATA max UDMA/100 cmd 0x170 ctl 0x376 bmdma 0x6fa8 irq 15 lpm-pol 0
[    2.735441] iwl3945: Intel(R) PRO/Wireless 3945ABG/BG Network Connection driver for Linux, in-tree:s
[    2.735448] iwl3945: Copyright(c) 2003-2011 Intel Corporation
[    2.735452] iwl3945: hw_scan is disabled
[    2.735570] iwl3945 0000:0c:00.0: can't disable ASPM; OS doesn't have ASPM control
[    2.797244] iwl3945 0000:0c:00.0: Tunable channels: 13 802.11bg, 23 802.11a channels
[    2.797256] iwl3945 0000:0c:00.0: Detected Intel Wireless WiFi Link 3945ABG
[    2.798400] ieee80211 phy0: Selected rate control algorithm 'iwl-3945-rs'
[    2.799166] usbcore: registered new interface driver cdc_ether
[    2.799207] usbcore: registered new interface driver net1080
[    2.799245] usbcore: registered new interface driver rndis_host
[    2.799287] usbcore: registered new interface driver zaurus
[    2.799325] usbcore: registered new interface driver cdc_ncm
[    2.799361] usbcore: registered new interface driver r8153_ecm
[    2.800405] ehci-pci 0000:00:1d.7: EHCI Host Controller
[    2.800430] ehci-pci 0000:00:1d.7: new USB bus registered, assigned bus number 1
[    2.800462] ehci-pci 0000:00:1d.7: debug port 1
[    2.804432] ehci-pci 0000:00:1d.7: irq 20, io mem 0xfed1c000
[    2.814935] ehci-pci 0000:00:1d.7: USB 2.0 started, EHCI 1.00
[    2.815145] usb usb1: New USB device found, idVendor=1d6b, idProduct=0002, bcdDevice= 6.18
[    2.815158] usb usb1: New USB device strings: Mfr=3, Product=2, SerialNumber=1
[    2.815165] usb usb1: Product: EHCI Host Controller
[    2.815171] usb usb1: Manufacturer: Linux 6.18.56-d630-gentoo ehci_hcd
[    2.815178] usb usb1: SerialNumber: 0000:00:1d.7
[    2.815793] hub 1-0:1.0: USB hub found
[    2.815820] hub 1-0:1.0: 6 ports detected
[    2.816605] ehci-pci 0000:00:1a.7: EHCI Host Controller
[    2.816631] ehci-pci 0000:00:1a.7: new USB bus registered, assigned bus number 2
[    2.816665] ehci-pci 0000:00:1a.7: debug port 1
[    2.820642] ehci-pci 0000:00:1a.7: irq 22, io mem 0xfed1c400
[    2.834913] ehci-pci 0000:00:1a.7: USB 2.0 started, EHCI 1.00
[    2.835084] usb usb2: New USB device found, idVendor=1d6b, idProduct=0002, bcdDevice= 6.18
[    2.835096] usb usb2: New USB device strings: Mfr=3, Product=2, SerialNumber=1
[    2.835103] usb usb2: Product: EHCI Host Controller
[    2.835109] usb usb2: Manufacturer: Linux 6.18.56-d630-gentoo ehci_hcd
[    2.835114] usb usb2: SerialNumber: 0000:00:1a.7
[    2.835696] hub 2-0:1.0: USB hub found
[    2.835724] hub 2-0:1.0: 4 ports detected
[    2.836344] uhci_hcd 0000:00:1a.0: UHCI Host Controller
[    2.836373] uhci_hcd 0000:00:1a.0: new USB bus registered, assigned bus number 3
[    2.836455] uhci_hcd 0000:00:1a.0: irq 20, io port 0x00006f20
[    2.836607] usb usb3: New USB device found, idVendor=1d6b, idProduct=0001, bcdDevice= 6.18
[    2.836617] usb usb3: New USB device strings: Mfr=3, Product=2, SerialNumber=1
[    2.836624] usb usb3: Product: UHCI Host Controller
[    2.836630] usb usb3: Manufacturer: Linux 6.18.56-d630-gentoo uhci_hcd
[    2.836636] usb usb3: SerialNumber: 0000:00:1a.0
[    2.837080] hub 3-0:1.0: USB hub found
[    2.837106] hub 3-0:1.0: 2 ports detected
[    2.838029] uhci_hcd 0000:00:1a.1: UHCI Host Controller
[    2.838045] uhci_hcd 0000:00:1a.1: new USB bus registered, assigned bus number 4
[    2.838120] uhci_hcd 0000:00:1a.1: irq 21, io port 0x00006f00
[    2.838261] usb usb4: New USB device found, idVendor=1d6b, idProduct=0001, bcdDevice= 6.18
[    2.838270] usb usb4: New USB device strings: Mfr=3, Product=2, SerialNumber=1
[    2.838277] usb usb4: Product: UHCI Host Controller
[    2.838283] usb usb4: Manufacturer: Linux 6.18.56-d630-gentoo uhci_hcd
[    2.838289] usb usb4: SerialNumber: 0000:00:1a.1
[    2.838715] hub 4-0:1.0: USB hub found
[    2.838920] hub 4-0:1.0: 2 ports detected
[    2.839725] uhci_hcd 0000:00:1d.0: UHCI Host Controller
[    2.839744] uhci_hcd 0000:00:1d.0: new USB bus registered, assigned bus number 5
[    2.839790] uhci_hcd 0000:00:1d.0: irq 20, io port 0x00006f80
[    2.839930] usb usb5: New USB device found, idVendor=1d6b, idProduct=0001, bcdDevice= 6.18
[    2.839942] usb usb5: New USB device strings: Mfr=3, Product=2, SerialNumber=1
[    2.839949] usb usb5: Product: UHCI Host Controller
[    2.839953] usb usb5: Manufacturer: Linux 6.18.56-d630-gentoo uhci_hcd
[    2.839959] usb usb5: SerialNumber: 0000:00:1d.0
[    2.840390] hub 5-0:1.0: USB hub found
[    2.840416] hub 5-0:1.0: 2 ports detected
[    2.841212] uhci_hcd 0000:00:1d.1: UHCI Host Controller
[    2.841232] uhci_hcd 0000:00:1d.1: new USB bus registered, assigned bus number 6
[    2.841277] uhci_hcd 0000:00:1d.1: irq 21, io port 0x00006f60
[    2.841423] usb usb6: New USB device found, idVendor=1d6b, idProduct=0001, bcdDevice= 6.18
[    2.841433] usb usb6: New USB device strings: Mfr=3, Product=2, SerialNumber=1
[    2.841440] usb usb6: Product: UHCI Host Controller
[    2.841446] usb usb6: Manufacturer: Linux 6.18.56-d630-gentoo uhci_hcd
[    2.841452] usb usb6: SerialNumber: 0000:00:1d.1
[    2.841872] hub 6-0:1.0: USB hub found
[    2.841899] hub 6-0:1.0: 2 ports detected
[    2.842681] uhci_hcd 0000:00:1d.2: UHCI Host Controller
[    2.842701] uhci_hcd 0000:00:1d.2: new USB bus registered, assigned bus number 7
[    2.842910] uhci_hcd 0000:00:1d.2: irq 22, io port 0x00006f40
[    2.843051] usb usb7: New USB device found, idVendor=1d6b, idProduct=0001, bcdDevice= 6.18
[    2.843063] usb usb7: New USB device strings: Mfr=3, Product=2, SerialNumber=1
[    2.843069] usb usb7: Product: UHCI Host Controller
[    2.843073] usb usb7: Manufacturer: Linux 6.18.56-d630-gentoo uhci_hcd
[    2.843080] usb usb7: SerialNumber: 0000:00:1d.2
[    2.843506] hub 7-0:1.0: USB hub found
[    2.843531] hub 7-0:1.0: 2 ports detected
[    2.844104] usbcore: registered new interface driver usb-storage
[    2.844254] i8042: PNP: PS/2 Controller [PNP0303:KBC,PNP0f13:PS2M] at 0x60,0x64 irq 1,12
[    2.847960] serio: i8042 KBD port at 0x60,0x64 irq 1
[    2.847979] serio: i8042 AUX port at 0x60,0x64 irq 12
[    2.849002] rtc_cmos PNP0B00:00: RTC can wake from S4
[    2.849772] rtc_cmos PNP0B00:00: registered as rtc0
[    2.849850] rtc_cmos PNP0B00:00: setting system clock to 2026-10-29T03:45:32 UTC (1793245532)
[    2.849940] rtc_cmos PNP0B00:00: alarms up to one month, y3k, 114 bytes nvram, hpet irqs
[    2.850607] input: AT Translated Set 2 keyboard as /devices/platform/i8042/serio0/input/input4
[    2.850658] i801_smbus 0000:00:1f.3: SMBus using polling
[    2.851029] device-mapper: ioctl: 4.50.0-ioctl (2025-04-28) initialised: dm-devel@lists.linux.dev
[    2.851109] usbcore: registered new interface driver btusb
[    2.851121] intel_pstate: CPU model not supported
[    2.851167] hid: raw HID events driver (C) Jiri Kosina
[    2.851424] i2c i2c-9: Successfully instantiated SPD at 0x50
[    2.852002] usbcore: registered new interface driver usbhid
[    2.852008] usbhid: USB HID core driver
[    2.854815] Initializing XFRM netlink socket
[    2.854874] NET: Registered PF_INET6 protocol family
[    2.855933] Segment Routing with IPv6
[    2.855978] In-situ OAM (IOAM) with IPv6
[    2.856081] sit: IPv6, IPv4 and MPLS over IPv4 tunneling driver
[    2.856603] NET: Registered PF_PACKET protocol family
[    2.856644] 9pnet: Installing 9P2000 support
[    2.856704] Key type dns_resolver registered
[    2.857767] microcode: Current revision: 0x000000a4
[    2.857774] microcode: Updated early from: 0x000000a1
[    2.857962] IPI shorthand broadcast: enabled
[    2.862658] snd_hda_codec_idt hdaudioC0D0: STAC9205: picked fixup  for PCI SSID 1028:01f9
[    2.863174] snd_hda_codec_idt hdaudioC0D0: autoconfig for STAC9205: line_outs=1 (0xd/0x0/0x0/0x0/0x0) type:speaker
[    2.863187] snd_hda_codec_idt hdaudioC0D0:    speaker_outs=0 (0x0/0x0/0x0/0x0/0x0)
[    2.863195] snd_hda_codec_idt hdaudioC0D0:    hp_outs=1 (0xa/0x0/0x0/0x0/0x0)
[    2.863203] snd_hda_codec_idt hdaudioC0D0:    mono: mono_out=0x0
[    2.863208] snd_hda_codec_idt hdaudioC0D0:    dig-out=0x21/0x0
[    2.863215] snd_hda_codec_idt hdaudioC0D0:    inputs:
[    2.863218] snd_hda_codec_idt hdaudioC0D0:      Mic=0xb
[    2.863224] snd_hda_codec_idt hdaudioC0D0:      Internal Mic=0xc
[    2.871869] registered taskstats version 1
[    2.871881] Loading compiled-in X.509 certificates
[    2.881069] Btrfs loaded, zoned=no, fsverity=no
[    2.881514] PM:   Magic number: 14:755:766
[    2.881737] netconsole: network logging started
[    2.884842] input: HDA Intel Mic as /devices/pci0000:00/0000:00:1b.0/sound/card0/input7
[    2.885044] input: HDA Intel Headphone as /devices/pci0000:00/0000:00:1b.0/sound/card0/input8
[    2.905848] cfg80211: Loading compiled-in X.509 certificates for regulatory database
[    2.908354] Loaded X.509 cert 'sforshee: 00b28ddf47aef9cea7'
[    2.909766] Loaded X.509 cert 'wens: 61c038651aabdcf94bd0ac7ff06c7248db18c600'
[    2.909801] ALSA device list:
[    2.910765]   #0: HDA Intel at 0xf6dfc000 irq 26
[    3.043951] ata1: SATA link up 3.0 Gbps (SStatus 123 SControl 300)
[    3.044023] ata3: SATA link down (SStatus 0 SControl 300)
[    3.044572] ata1.00: ATA-8: HFS064G38MNB-2200A, 10103L00, max UDMA/133
[    3.044691] ata1.00: 125045424 sectors, multi 8: LBA48 NCQ (depth 32), AA
[    3.044824] ata1.00: Features: HIPM DIPM
[    3.045296] ata1.00: configured for UDMA/133
[    3.045883] scsi 0:0:0:0: Direct-Access     ATA      HFS064G38MNB-220 3L00 PQ: 0 ANSI: 5
[    3.047246] sd 0:0:0:0: Attached scsi generic sg0 type 0
[    3.047300] sd 0:0:0:0: [sda] 125045424 512-byte logical blocks: (64.0 GB/59.6 GiB)
[    3.047352] sd 0:0:0:0: [sda] Write Protect is off
[    3.047365] sd 0:0:0:0: [sda] Mode Sense: 00 3a 00 00
[    3.047434] sd 0:0:0:0: [sda] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
[    3.047622] sd 0:0:0:0: [sda] Preferred minimum I/O size 512 bytes
[    3.071592]  sda: sda1 sda2 sda3
[    3.072438] sd 0:0:0:0: [sda] Attached SCSI disk
[    3.076473] Freeing unused kernel image (initmem) memory: 2572K
[    3.077000] Write protecting the kernel read-only data: 24576k
[    3.079360] Freeing unused kernel image (text/rodata gap) memory: 584K
[    3.081351] Freeing unused kernel image (rodata/data gap) memory: 696K
[    3.081829] Run /init as init process
[    3.081838]   with arguments:
[    3.081841]     /init
[    3.081849]   with environment:
[    3.081852]     HOME=/
[    3.081856]     TERM=linux
[    3.203050] usb 6-1: new low-speed USB device number 2 using uhci_hcd
[    3.389532] usb 6-1: New USB device found, idVendor=0000, idProduct=3821, bcdDevice= 1.00
[    3.389560] usb 6-1: New USB device strings: Mfr=0, Product=1, SerialNumber=0
[    3.389572] usb 6-1: Product: SiliconWin mouse
[    3.408913] input: SiliconWin mouse as /devices/pci0000:00/0000:00:1d.1/usb6/6-1/6-1:1.0/0003:0000:3821.0001/input/input9
[    3.409411] hid-generic 0003:0000:3821.0001: input,hidraw0: USB HID v1.11 Mouse [SiliconWin mouse] on usb-0000:00:1d.1-1/input0
[    3.811176] usb 1-4: new high-speed USB device number 3 using ehci-pci
[    3.966056] usb 1-4: New USB device found, idVendor=12d1, idProduct=107d, bcdDevice= 4.09
[    3.966082] usb 1-4: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[    3.966093] usb 1-4: Product: SDM450-MTP _SN:67D3502B
[    3.966104] usb 1-4: Manufacturer: HUAWEI
[    3.966110] usb 1-4: SerialNumber: 4FF6R19215003285
[    4.011703] input: AlpsPS/2 ALPS DualPoint Stick as /devices/platform/i8042/serio1/input/input10
[    4.033242] input: AlpsPS/2 ALPS DualPoint TouchPad as /devices/platform/i8042/serio1/input/input6
[    4.278960] usb 7-1: new full-speed USB device number 2 using uhci_hcd
[    4.441158] usb 7-1: New USB device found, idVendor=0b97, idProduct=7761, bcdDevice= 1.10
[    4.441187] usb 7-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    4.443218] hub 7-1:1.0: USB hub found
[    4.445148] hub 7-1:1.0: 4 ports detected
[    4.734984] usb 7-1.2: new full-speed USB device number 3 using uhci_hcd
[    4.856057] usb 7-1.2: New USB device found, idVendor=0b97, idProduct=7772, bcdDevice= 1.10
[    4.856085] usb 7-1.2: New USB device strings: Mfr=1, Product=2, SerialNumber=0
[    4.856096] usb 7-1.2: Product: O2Micro CCID SC Reader
[    4.856107] usb 7-1.2: Manufacturer: O2
[    7.538815] random: crng init done
[  139.683775] iwl3945 0000:0c:00.0: loaded firmware version 15.32.2.9
[  777.893143] exFAT-fs (sda1): invalid fs_name
[  777.897005] exFAT-fs (sda1): failed to read boot sector
[  777.900747] exFAT-fs (sda1): failed to recognize exfat type
[  787.317731] /dev/sda1: Can't open blockdev
[  787.322055] /dev/sda1: Can't open blockdev
[  787.326120] /dev/sda1: Can't open blockdev
[  787.330077] /dev/sda1: Can't open blockdev
[  787.333976] /dev/sda1: Can't open blockdev
[  787.337968] /dev/sda1: Can't open blockdev
[  787.341816] /dev/sda1: Can't open blockdev
[  787.345552] /dev/sda1: Can't open blockdev
[  787.349549] /dev/sda1: Can't open blockdev
[  834.364779] EXT4-fs (sda3): mounted filesystem 6a8dc58d-fff4-482f-8f46-a9100bfe123a r/w with ordered data mode. Quota mode: none.

```
