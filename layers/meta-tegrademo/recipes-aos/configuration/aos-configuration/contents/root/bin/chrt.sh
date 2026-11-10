#!/bin/bash

set -ex

chmod a+rwx /sys/kernel/debug

# Make sure /sys/kernel/tracing is reasonably accessible so --enable_ftrace
# works.
chmod a+w /sys/kernel/tracing/trace_marker
echo 10000 > /sys/kernel/tracing/buffer_size_kb
chmod a+rw /sys/kernel/tracing/tracing_on
chmod a+rwx /sys/kernel/tracing

# PREEMPT_RT runs every threaded interrupt handler at SCHED_FIFO 50, above
# real-time AOS threads.  Nothing real-time waits on the disk, so background
# I/O (journald, logs) must not preempt them: run the NVMe handlers as
# SCHED_OTHER at nice -10.  With direct-I/O writers, a SCHED_FIFO 40 timer on
# the handlers' CPU went from 328 us late at worst to 12.5 us, for 9% less
# write throughput against a CPU hog.
for pid in $(pgrep '^irq/[0-9]+-nvme'); do
  chrt -o -p 0 "${pid}"
  renice -n -10 -p "${pid}"
done

# hwrng feeds the entropy pool from optee-rng once a minute.  Each read is one
# OP-TEE call that interrupts cannot preempt: 21 us typically, over 100 us at
# worst, on whatever CPU hwrng last ran.  Pin it to CPU 0, which takes the
# stalls; unbound kthreads only avoid the other CPUs on their own with
# nohz_full.
for pid in $(pgrep -x hwrng); do
  taskset -pc 0 "${pid}"
done
