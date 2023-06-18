# Used by tmux to get IPv4
get_tunnel_ip () {
	(ip link show type tun | cut -d' ' -f 2 | sed 's/:$//' | xargs -I {} ip -o -4 addr show {} | awk '/inet/ {print $4}' | cut -d/ -f1)}
