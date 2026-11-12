# Real-time configuration

What the image does so AOS's real-time threads run on time, and why.  The
rest of the image is described in [details.md](details.md).

Disk I/O is not real-time.  Nothing real-time should wait on the disk.

## Kernel

The kernel is mainline 6.18.59 with `PREEMPT_RT` (`linux-yocto-rt`), the
newest 6.18 linux-yocto has.  The measurements below were made on 6.18.39.

`config_preempt_rt.cfg`:

* `CONFIG_HZ_PERIODIC`: the tick keeps running on idle CPUs, so there is no
  tick stop and restart on every idle entry and exit.  There is no
  `nohz_full`; every CPU takes the tick.
* The irqsoff, preempt, wakeup (sched) and hwlat tracers.
  `config_tracers.cfg` adds osnoise and timerlat.  All of them cost nothing
  until turned on through tracefs.

`config_rt_sched.cfg` turns `CONFIG_RT_GROUP_SCHED` off.  With it on, only the
root cgroup can use `SCHED_FIFO` under cgroup v2, and AOS runs in
`aos.service`'s cgroup.

`config_btf.cfg` adds BTF, so `bpftrace` can read kernel structures, and the
kernel headers as the `kheaders` module, which the bcc tools compile against.

The command line sets `kpti=0`.  KASLR otherwise forces kernel page table
isolation on, which switches page tables on every system call, and the
Cortex-A78 isn't vulnerable to Meltdown.

### Patches

In `layers/meta-tegrademo/recipes-kernel/linux/linux-yocto-6.18/`; each one's
description has the details and measurements.  Only 0001 is merged
upstream, in 6.18.60; drop it when the kernel gets there.

| Patch | What it fixes |
|---|---|
| 0001 | A real-time task waiting in `io_uring_enter()` with a timeout is woken from hard interrupt context, not from `ktimers` at FIFO 1 behind every other real-time task. |
| 0002 | A real-time io_uring waiter isn't left asleep behind a preempted task that queued work before it. |
| 0003 | Released io_uring rings waiting to be freed are bounded, so tearing down and rebuilding event loops can't build a backlog. |
| 0004 | io_uring futex waits that fail to arm go back to the cache instead of to `kfree()`. |
| 0009 | r8169 interrupts on RX overflow again; without it the RTL8168h could stop interrupting and drop the link for 5 seconds under receive bursts. |
| 0010 | The NAPI deferred-poll timer runs in hard interrupt context, not in `ktimers` at FIFO 1.  `eth0.rules`' interrupt deferral depends on it. |
| 0011 | A preempted task that owns the qdisc is boosted, so a high-priority sender's packets don't wait tens of milliseconds behind it. |
| 0012-0022 | SCTP: reassembly that isn't quadratic, partial delivery and PR-SCTP fixes, and a limit on how much a socket queues below SCTP (0014, `net.sctp.limit_output_bytes`). |
| 0023 | A real-time task preempted inside a `spinlock_t` section gets its CPU back by pushing the preempting task to another CPU, as before 6.18.53.  Without it, SCTP round trips took up to 133 ms under a `SCHED_FIFO` CPU hog while other CPUs sat idle. |

`frc-kmeta` has two more: the BPMP debugfs mirror is built in the
background (boot time), and the tegra186 timer requests its interrupt after
creating the watchdog, which fixes a crash after `kexec`.

## Priorities

AOS sets its own threads' priorities.  `aos.service` allows up to
`SCHED_FIFO` 60, nice -20 and unlimited locked memory.  Everything else:

| Thread | Policy | Set by |
|---|---|---|
| Threaded interrupt handlers (`irq/*`) | FIFO 50 | `PREEMPT_RT` default |
| eth0's NAPI thread (`napi/eth0-*`) | FIFO 50 | `napi-priority@.service` |
| NVMe interrupt handlers (`irq/*-nvme*`) | SCHED_OTHER, nice -10 | `chrt.sh` |
| Soft timers (`ktimers/N`) | FIFO 1 | `PREEMPT_RT` default |

The NVMe handlers are taken out of `SCHED_FIFO` because background writes
(journald, logs) otherwise preempt real-time threads.  With direct-I/O writers,
a FIFO 40 timer on the handlers' CPU went from 328 us late at worst to
12.5 us, for 9% less write throughput against a CPU hog.

`udevd` can't set real-time priorities (`RestrictRealtime=yes`), so
`eth0.rules` starts `napi-priority@eth0.service` to do it.  The NAPI thread
lasts until the driver removes the device, so link changes keep its priority.

## CPUs

No CPUs are isolated, and nothing is pinned except `hwrng`.  Every AOS thread
and the NAPI thread can run on any of the 6 CPUs.

* The eth0 and NVMe interrupts all arrive on CPU 0.  The PCIe controller
  collects the MSIs and hands them on from its own interrupt, so they can't
  be moved separately.
* `hwrng` is pinned to CPU 0 (`chrt.sh`).  Each read from optee-rng is an
  OP-TEE call that interrupts can't preempt: 21 us typically, over 100 us at
  worst.

## Networking

`eth0.rules` tunes the RTL8168h's receive path.  These were measured with SCTP
round trips to the systemcore while AOS ran the vision stack:

* `threaded=1`: NAPI runs in its own thread at FIFO 50, instead of in whatever
  thread raised the softirq.  With 0010, idle p99 was 337 us, against 931 us
  unthreaded.
* `napi_defer_hard_irqs=2`, `gro_flush_timeout=50000`: keep the interrupt
  masked for two empty polls, re-polling from a 50 us timer, instead of taking
  an interrupt per packet.
* BQL `limit_max=60000`: a bulk sender can queue at most about 0.5 ms at
  1 Gbit/s ahead of an SCTP packet.  With the deferral, p99 under receive load
  went from 1.84 ms to 877 us.

`eth0.network` pins the root qdisc to fq_codel, whose per-flow queues keep SCTP
from waiting behind bulk TCP.  Otherwise it depends on whether `sch_fq_codel`
is loaded when the link comes up.

SCTP is a module, loaded at boot (`modules-load.d/sctp.conf`) so its sysctls
apply:

* `net.sctp.intl_enable=1`, so the message bridge can use I-DATA interleaving.
* `net.core.wmem_max` and `rmem_max` of 8 MB, big enough for an image.
* `net.sctp.limit_output_bytes=16384` (patch 0014): once 16 KiB
  from a socket waits in the qdisc and NIC, new data stays in SCTP's stream
  scheduler, so stream priorities and fresh messages don't wait behind a whole
  congestion window.

## GPU and clocks

`jetson-clocks.service` runs every clock at its maximum, so frequency changes
don't add latency.  `jetson-clocks-emc.path` pins the memory controller's clock
too, once the BPMP's debugfs is filled in.  `jetson-clocks.service` also keeps the GPU's
graphics engine powered between frames: with power gating on, it powered down
between 60 Hz camera frames and every frame paid about 0.4 ms to wake it, more
than the AprilTag detector's GPU work.  Leaving it powered costs about 0.15 W.

## Measuring

The image has `rt-tests` (`cyclictest`), `stress-ng`, `perf`, `bpftrace` (with
its tools in `/usr/share/bpftrace/tools`), the bcc tools (in
`/usr/share/bcc/tools`), `bpftool`, `iperf3` and `linuxptp`.  The timerlat and osnoise tracers are in tracefs;
`chrt.sh` makes `/sys/kernel/tracing` writable by everyone, so AOS's
`--enable_ftrace` works without root.

An ssh login runs `sshd` and systemd on the CPUs it lands on, so stay logged
out of the orin while measuring.
