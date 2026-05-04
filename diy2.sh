#!/bin/bash

# ========== 1. 自适应网络端口检测（修复首页端口显示） ==========
echo "正在注入自适应网络端口检测脚本..."

cat > package/base-files/files/etc/uci-defaults/99-fix-net-ports << "EOF"
#!/bin/sh

# 等待驱动完全加载（避免 eth1/2/3 尚未出现）
sleep 5

# 1. 自动生成 /etc/board.json
/bin/board_detect

# 2. 确保配置文件和目录可写
CONFIG_FILE="/etc/config/network"
BOARD_JSON="/etc/board.json"
BOARD_D_DIR="/etc/board.d"

# 3. 等待系统就绪
sleep 2

# 4. 获取所有以太网接口 (排除虚拟和特殊设备)
ALL_ETH=$(ls /sys/class/net/ | grep -E '^eth[0-9]+$' | sort -V)

# 如果没找到任何接口，则退出
[ -z "$ALL_ETH" ] && exit 0

# 5. 动态构建新的 board.json 'network' 部分
WAN_PORT=$(echo "$ALL_ETH" | head -n 1)
LAN_PORTS=$(echo "$ALL_ETH" | tail -n +2 | tr '\n' ', ' | sed 's/, $//')

# 6. 调用官方函数库生成配置
. /lib/functions/uci-defaults.sh
board_config_update

# 7. 使用官方函数定义接口
ucidef_set_interface_lan "$LAN_PORTS"
ucidef_set_interface_wan "$WAN_PORT"

# 8. 更新 board.json
board_config_flush

# 9. 重新生成网络配置文件 /etc/config/network
/bin/config_generate

# 10. 重启网络服务
/etc/init.d/network restart

exit 0
EOF

chmod +x package/base-files/files/etc/uci-defaults/99-fix-net-ports
echo "✅ 自适应网络端口检测脚本已添加"

# ========== 2. 清理 Go 模块缓存 ==========
echo "🗑️ 清理 Go 模块缓存..."
rm -rf dl/go-mod-cache 2>/dev/null || true
echo "✅ Go 缓存已清理"

# ========== 3. 替换官方 Golang 为 26.x 版本 ==========
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
echo "✅ Golang 已更新至 26.x"

# ========== 4. 设置默认主题为 Argon ==========
if [ -f "feeds/luci/collections/luci/Makefile" ]; then
    sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
    echo "✅ 默认主题已设置为 Argon"
fi

echo "✅ diy2.sh 执行完成"
