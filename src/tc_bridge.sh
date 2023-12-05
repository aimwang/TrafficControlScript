########## environment ##########
PCAP=1
CID=6
NETIF="br-lan"
RTP_PORT=5001
RTCP_PORT=5101

R_IP="192.168.1.3"
R_DELAY=300
R_JITTER=10
R_LOST=3
R_DUP=0

L_IP="192.168.1.4"
L_DELAY=100
L_JITTER=30
L_LOST=6
L_DUP=0

########## remove from bridgr ##########
brctl addif br-lan ${R_NETIF} >/dev/null 2>&1
brctl addif br-lan ${L_NETIF} >/dev/null 2>&1

########## Set class ##########
tc qdisc del dev ${NETIF} root >/dev/null 2>&1
tc qdisc add dev ${NETIF} root handle ${CID}: htb
tc class add dev ${NETIF} parent ${CID}: classid ${CID}:1 htb rate 2500mbit
tc class add dev ${NETIF} parent ${CID}: classid ${CID}:2 htb rate 2500mbit
tc class add dev ${NETIF} parent ${CID}: classid ${CID}:3 htb rate 2500mbit
tc class add dev ${NETIF} parent ${CID}: classid ${CID}:4 htb rate 2500mbit

########## Set right tc ##########
tc qdisc add dev ${NETIF} parent ${CID}:1 netem delay ${R_DELAY}ms ${R_JITTER}ms
tc filter add dev ${NETIF} parent ${CID}:0 protocol ip u32 match ip src ${R_IP} match ip dst ${L_IP} match ip sport ${RTCP_PORT} 0xffff flowid ${CID}:1
tc qdisc add dev ${NETIF} parent ${CID}:2 netem loss ${R_LOST}% duplicate ${R_DUP}% delay ${R_DELAY}ms ${R_JITTER}ms
tc filter add dev ${NETIF} parent ${CID}:0 protocol ip u32 match ip src ${R_IP} match ip dst ${L_IP} match ip sport ${RTP_PORT} 0xffff flowid ${CID}:2

########## Set left tc ##########
tc qdisc add dev ${NETIF} parent ${CID}:3 netem delay ${L_DELAY}ms ${L_JITTER}ms
tc filter add dev ${NETIF} parent ${CID}:0 protocol ip u32 match ip src ${L_IP} match ip dst ${R_IP} match ip sport ${RTCP_PORT} 0xffff flowid ${CID}:3
tc qdisc add dev ${NETIF} parent ${CID}:4 netem loss ${L_LOST}% duplicate ${L_DUP}% delay ${L_DELAY}ms ${L_JITTER}ms
tc filter add dev ${NETIF} parent ${CID}:0 protocol ip u32 match ip src ${L_IP} match ip dst ${R_IP} match ip sport ${RTP_PORT} 0xffff flowid ${CID}:4

########## Capture packets ##########
if [ 0 -ne ${PCAP} ]; then
	tcpdump -i ${NETIF} -Q out src port ${RTCP_PORT} or ${RTP_PORT} -w /tmp/${NETIF}.pcap &
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
tc qdisc del dev ${NETIF} root
