#!/bin/sh

sudo yum update -y

# 2つのNetwork Namespaceを作成します。
sudo ip netns add ns1
sudo ip netns add ns2

# 仮想スイッチを作成
sudo ip link add br0 type bridge

# 仮想ネットワークインターフェース(NIC)を作成
sudo ip link add name ns-veth1 type veth peer name br-veth1
sudo ip link add name ns-veth2 type veth peer name br-veth2
sudo ip link add name rt-veth type veth peer name br-veth3

# Network Namespaceに仮想ネットワーク・インターフェースを接続する
sudo ip link set ns-veth1 netns ns1
sudo ip link set ns-veth2 netns ns2

# 仮想スイッチに仮想ネットワーク・インターフェースを接続する
sudo ip link set dev br-veth1 master br0
sudo ip link set dev br-veth2 master br0
sudo ip link set dev br-veth3 master br0

# 仮想NICと仮想スイッチのUP
sudo ip netns exec ns1 ip link set ns-veth1 up
sudo ip netns exec ns2 ip link set ns-veth2 up
sudo ip link set rt-veth up
sudo ip link set br-veth1 up
sudo ip link set br-veth2 up
sudo ip link set br-veth3 up
sudo ip link set br0 up

# ipアドレスの付与
sudo ip netns exec ns1 ip addr add 192.168.0.1/24 dev ns-veth1
sudo ip netns exec ns2 ip addr add 192.168.0.2/24 dev ns-veth2
sudo ip addr add 192.168.0.100/24 dev rt-veth

# 動作確認
sudo ip netns exec ns1 ping -c 3 192.168.0.2
sudo ip netns exec ns1 ping -c 3 192.168.0.100

# googleのパブリックDNSにping打ってみる
## 必ず失敗する。原因は3つ。
## 1. IP転送が有効になっていない
## 2. Network Namespace内で デフォルトゲートウェイが設定されてない
## 3. NATされていない
sudo ip netns exec ns1 ping 8.8.8.8

# IP転送が有効にする
## rt-veth → 物理nic
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Network Namespace内でデフォルトゲートウェイを設定する
sudo ip netns exec ns1 ip route add default via 192.168.0.100
sudo ip netns exec ns2 ip route add default via 192.168.0.100

# NATする
## ルーティングが終わった後に、送信元が192.168.0.0/24で、かつeth0というネットワークデバイスから出ていくパケットの送信元アドrスをeth0のアドレス(物理NICのアドレスに変更する)
sudo iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o eth0 -j MASQUERADE

