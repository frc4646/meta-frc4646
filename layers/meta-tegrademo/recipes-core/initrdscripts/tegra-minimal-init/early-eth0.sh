
# Start Ethernet autonegotiation now.  It takes 3 seconds, the robot code
# can't start until eth0 has a link, and systemd-networkd only gets to eth0
# several seconds later.  networkd configures the address when it starts,
# and leaves the link up.
ip link set eth0 up 2> /dev/null || true
