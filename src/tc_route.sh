########## environment ##########
PCAP=0
CID_lo=0
CID_eth0=1
CID_eth1=2
CID_eth2=3
CID_eth3=4
CID_eth4=5
CID_br-lan=6
RTP_PORT=5000
RTCP_PORT=5101

R_NETIF=eth0
R_IP=192.168.3.1
R_MASK=255.255.255.0
R_DELAY=300
R_JITTER=10
R_LOST=3
R_DUP=0

L_NETIF=eth1
L_IP=192.168.4.1
L_MASK=255.255.255.0
L_DELAY=100
L_JITTER=30
L_LOST=6
L_DUP=0

########## Enable ipv4 forward ##########
echo 1 > /proc/sys/net/ipv4/ip_forward

########## Set right interface ##########
eval "R_CID=\$CID_${R_NETIF}"
brctl delif br-lan ${R_NETIF} >/dev/null 2>&1
ifconfig ${R_NETIF} ${R_IP} netmask ${R_MASK}

########## Set right tc ##########
tc qdisc del dev ${R_NETIF} root >/dev/null 2>&1
tc qdisc add dev ${R_NETIF} root handle ${R_CID}: htb
tc class add dev ${R_NETIF} parent ${R_CID}: classid ${R_CID}:1 htb rate 2500mbit
tc class add dev ${R_NETIF} parent ${R_CID}: classid ${R_CID}:2 htb rate 2500mbit
tc qdisc add dev ${R_NETIF} parent ${R_CID}:1 netem delay ${R_DELAY}ms ${R_JITTER}ms
tc filter add dev ${R_NETIF} parent ${R_CID}:0 protocol ip u32 match ip sport ${RTCP_PORT} 0xffff flowid ${R_CID}:1
tc qdisc add dev ${R_NETIF} parent ${R_CID}:2 netem loss ${R_LOST}% duplicate ${R_DUP}% delay ${R_DELAY}ms ${R_JITTER}ms
tc filter add dev ${R_NETIF} parent ${R_CID}:0 protocol ip u32 match ip sport ${RTP_PORT} 0xffff flowid ${R_CID}:2

########## Set left interface ##########
eval "L_CID=\$CID_${L_NETIF}"
brctl delif br-lan ${L_NETIF} >/dev/null 2>&1
ifconfig ${L_NETIF} ${L_IP} netmask ${L_MASK}

########## Set left tc ##########
tc qdisc del dev ${L_NETIF} root >/dev/null 2>&1
tc qdisc add dev ${L_NETIF} root handle ${L_CID}: htb
tc class add dev ${L_NETIF} parent ${L_CID}: classid ${L_CID}:1 htb rate 2500mbit
tc class add dev ${L_NETIF} parent ${L_CID}: classid ${L_CID}:2 htb rate 2500mbit
tc qdisc add dev ${L_NETIF} parent ${L_CID}:1 netem delay ${L_DELAY}ms ${L_JITTER}ms
tc filter add dev ${L_NETIF} parent ${L_CID}:0 protocol ip u32 match ip sport ${RTCP_PORT} 0xffff flowid ${L_CID}:1
tc qdisc add dev ${L_NETIF} parent ${L_CID}:2 netem loss ${L_LOST}% duplicate ${L_DUP}% delay ${L_DELAY}ms ${L_JITTER}ms
tc filter add dev ${L_NETIF} parent ${L_CID}:0 protocol ip u32 match ip sport ${RTP_PORT} 0xffff flowid ${L_CID}:2

########## Capture packets ##########
if [ 0 -ne ${PCAP} ]; then
	tcpdump -i ${R_NETIF} -Q out src port ${RTCP_PORT} or ${RTP_PORT} -w /tmp/R2L_${R_NETIF}.pcap &
	tcpdump -i ${L_NETIF} -Q out src port ${RTCP_PORT} or ${RTP_PORT} -w /tmp/L2R_${L_NETIF}.pcap &
fi

########## waiting ##########
sleep 1
while [ 1 -eq 1 ]; do
	read -n 1 -p "Press [q] to stop." BUF
	echo -e ""
	if [ "q" == "${BUF}" ]; then
		break
	fi
done

########## Clear tc ##########
tc qdisc del dev ${R_NETIF} root
tc qdisc del dev ${L_NETIF} root
