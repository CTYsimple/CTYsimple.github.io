#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="fixed_system_performance_${TIMESTAMP}.log"

# 函数：添加小节标题
print_section() {
    echo ""
    echo "$1"
    echo "==============================="
}

print_separator() {
    echo "#-#-#-#-#-#"
}

{
print_separator
echo "生成时间: $(date)"
print_separator

# 1. 系统基本信息
print_section "1. 系统基本信息"
echo "主机名: $(hostname)"
echo "内核版本: $(uname -r)"
echo "系统架构: $(uname -m)"
echo "系统版本:"
if [ -f /etc/os-release ]; then
    grep -E "(PRETTY_NAME|VERSION)" /etc/os-release
fi

# 2. 网络信息 - 获取本地服务器IP地址
print_section "2. 网络信息 (获取本地服务器IP地址)"
echo "参数说明:"
echo "  IP地址: 网络接口分配的Internet协议地址, 用于在网络中唯一标识设备"
echo ""
echo "本地IP地址:"
hostname -I 2>/dev/null || echo "  无法获取IP地址"
echo ""
echo "网络接口详细信息:"
ip addr show 2>/dev/null | grep -E "(^[0-9]|inet )"

# 3. CPU核心数量
print_section "3. CPU核心数量"
echo "参数说明:"
echo "  物理核心数: CPU芯片上实际的处理核心数量"
echo "  逻辑核心数: 操作系统能看到的核心数量（考虑超线程技术）"
echo "  在线核心数: 当前可用的核心数量"
echo ""
echo "CPU核心数量信息:"
echo "  物理核心数: $(lscpu | grep "Core(s) per socket" | awk '{print $4}')"
echo "  逻辑核心数: $(nproc)"
echo "  在线核心数: $(lscpu | grep "On-line CPU(s) list" | awk '{print $NF+1}')"
echo ""
echo "CPU拓扑结构:"
lscpu | grep -E "(Socket|Core|Thread)"

# 4. CPU使用情况详解
print_section "4. CPU使用情况详解"
echo "参数说明:"
echo "  %us (用户空间CPU占用百分比): 用户态进程消耗的CPU时间占比 百分比 (%)"
echo "  %sy (内核空间CPU占用百分比): 内核态进程消耗的CPU时间占比 百分比 (%)"
echo "  %ni (低优先级用户态CPU占用百分比): 改变过优先级的用户态进程消耗的CPU时间占比 百分比 (%)"
echo "  %id (空闲CPU百分比): CPU完全空闲的时间占比 百分比 (%)"
echo "  %wa (等待输入输出CPU百分比): CPU等待I/O操作完成的时间占比 百分比 (%)"
echo "  %hi (硬件中断CPU百分比): 处理硬件中断消耗的CPU时间占比 百分比 (%)" 
echo "  %si (软件中断CPU百分比): 处理软件中断消耗的CPU时间占比 百分比 (%)"
echo "  %st (虚拟机偷取时间百分比): 虚拟化环境中, 其他虚拟机占用的CPU时间占比 百分比 (%)"

echo ""
echo "当前CPU使用率 (1秒采样2次):"
# 使用更准确的方法获取CPU使用率
top -bn2 -d1 | grep "Cpu(s)" | tail -n 1 | awk '{
    # 提取各项指标
    gsub(/%us,/,"",$2); gsub(/%sy,/,"",$3); gsub(/%ni,/,"",$4); 
    gsub(/%id,/,"",$5); gsub(/%wa,/,"",$6); gsub(/%hi,/,"",$7); 
    gsub(/%si,/,"",$8); gsub(/%st/,"",$9);
    printf "  用户空间: %.2f%%\n  系统空间: %.2f%%\n  低优先级用户态: %.2f%%\n  空闲: %.2f%%\n  IO等待: %.2f%%\n  硬件中断: %.2f%%\n  软件中断: %.2f%%\n  虚拟机偷取: %.2f%%\n", 
    $2, $3, $4, $5, $6, $7, $8, $9
}' || iostat -c 1 2 | grep "avg-cpu" -A 1 | tail -n 1 | awk '{
    printf "  用户空间: %.2f%%\n  系统空间: %.2f%%\n  低优先级用户态: %.2f%%\n  空闲: %.2f%%\n  IO等待: %.2f%%\n  硬件中断: %.2f%%\n  软件中断: %.2f%%\n  虚拟机偷取: %.2f%%\n", 
    $1, $3, $2, $4, $5, $6, $7, $8
}'

echo ""
echo "各核心使用率详情:"
iostat -c 1 2 | grep "avg-cpu" -A 5 | tail -n 5

# 5. CPU上下文切换和中断次数
print_section "5. CPU上下文切换和中断次数"
echo "参数说明:"
echo "  ctxt (上下文切换次数): CPU从一个进程或线程切换到另一个进程或线程的总次数"
echo "  intr (中断次数): 系统启动后处理的硬件中断总次数"
echo "  processes (进程创建数): 系统启动后创建的进程总数"
echo ""
echo "上下文切换和中断统计:"
grep -E "ctxt|intr|processes" /proc/stat | while read line; do
    param=$(echo "$line" | awk '{print $1}')
    value=$(echo "$line" | awk '{print $2}')
    case "$param" in
        ctxt)     echo "  上下文切换次数: $value 次" ;;
        intr)     echo "  中断次数: $value 次" ;;
        processes) echo "  进程创建数: $value 个" ;;
    esac
done

# 6. 系统负载平均值
print_section "6. 系统负载平均值"
echo "参数说明:"
echo "  load average (负载平均值): 在特定时间间隔内系统运行队列中的平均进程数"
echo "  1分钟平均负载: 过去1分钟内的平均负载"
echo "  5分钟平均负载: 过去5分钟内的平均负载"
echo "  15分钟平均负载: 过去15分钟内的平均负载"
echo "  单位: 无单位数值, 通常与CPU核心数比较"
echo ""
echo "系统负载平均值:"
uptime | awk -F'load average:' '{print $2}' | awk '{printf "  1分钟负载: %s\n  5分钟负载: %s\n  15分钟负载: %s\n", $1, $2, $3}' | sed 's/,//g'
echo ""
echo "负载详细信息:"
cat /proc/loadavg | awk '{
    printf "  1分钟平均负载: %s\n  5分钟平均负载: %s\n  15分钟平均负载: %s\n  运行中/总进程数: %s\n  最近进程ID: %s\n", $1, $2, $3, $4, $5
}'

# 7. 任务队列信息
print_section "7. 任务队列信息 (就绪状态等待的进程数量)"
echo "参数说明:"
echo "  procs_running (运行中进程数): 当前在CPU上运行或等待运行的进程数"
echo "  procs_blocked (阻塞进程数): 当前等待I/O操作完成的进程数"
echo "  runq-sz (运行队列长度): 在内存中等待运行的进程队列长度"
echo ""
echo "任务队列统计:"
vmstat 1 2 | tail -n 1 | awk '{printf "  运行队列长度: %s 个进程\n  阻塞进程数: %s 个进程\n", $1, $2}'

# 8. 详细CPU统计信息
print_section "8. 详细CPU统计信息"
echo "CPU时间分配参数说明:"
echo "  cpu: 所有CPU核心的统计信息"
echo "  user: 用户态时间 (单位: jiffies)"
echo "  nice: 低优先级用户态时间 (单位: jiffies)"
echo "  system: 内核态时间 (单位: jiffies)"
echo "  idle: 空闲时间 (单位: jiffies)"
echo "  iowait: IO等待时间 (单位: jiffies)"
echo "  irq: 硬件中断时间 (单位: jiffies)"
echo "  softirq: 软件中断时间 (单位: jiffies)"
echo "  steal: 虚拟机偷取时间 (单位: jiffies)"
echo "  guest: 虚拟CPU为客户操作系统服务的时间 (单位: jiffies)"

echo "CPU时间分配:"
echo "字段  user  nice  system  idle  iowait  irq  softirq  steal  guest"
grep -E "^cpu " /proc/stat

# 9. I/O等待和队列信息
print_section "9. I/O等待和队列信息"
echo "I/O等待和队列统计信息:"
iostat 1 1 | grep -A 3 avg-cpu

# 10. 内存信息
print_section "10. 内存信息"
echo "参数说明:"
echo "  MemTotal (物理内存总量): 系统安装的物理内存总量 单位: KB (千字节)"
echo "  MemFree (空闲物理内存): 当前未被使用的物理内存量 单位: KB (千字节)"
echo "  MemAvailable (可用物理内存): 估计可被应用程序使用的内存量 单位: KB (千字节)"
echo "  SwapTotal (交换分区总大小): 交换分区的总大小 单位: KB (千字节)"
echo "  SwapFree (交换分区剩余大小): 交换分区中未被使用的大小 单位: KB (千字节)"
echo ""
echo "内存使用情况:"
free -h
echo ""
echo "内存详细信息:"
grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree" /proc/meminfo

# 11. 磁盘信息详解
print_section "11. 磁盘信息详解"
echo "磁盘参数说明:"
echo "  Filesystem: 文件系统类型和设备路径"
echo "  Size: 分区总大小"
echo "  Used: 已使用空间大小"
echo "  Avail: 可用空间大小"
echo "  Use%: 空间使用百分比"
echo "  Mounted on: 挂载点"
echo ""
echo "磁盘使用情况:"
df -h | grep -E "(Filesystem|/dev/)"
echo ""
echo "磁盘I/O统计参数说明:"
echo "  rrqm/s: 每秒合并的读请求数"
echo "  wrqm/s: 每秒合并的写请求数"
echo "  r/s: 每秒完成的读请求数"
echo "  w/s: 每秒完成的写请求数"
echo "  rMB/s: 每秒读取的兆字节数"
echo "  wMB/s: 每秒写入的兆字节数"
echo "  avgrq-sz: 平均请求大小(扇区)"
echo "  avgqu-sz: 平均队列长度"
echo "  await: 平均等待时间(毫秒)"
echo "  r_await: 读请求平均等待时间(毫秒)"
echo "  w_await: 写请求平均等待时间(毫秒)"
echo "  svctm: 平均服务时间(毫秒)"
echo "  %util: 设备使用百分比"
echo ""
echo "磁盘I/O统计:"
# 获取磁盘I/O统计信息，排除loop设备
iostat -x 1 2 | grep -v "loop" | grep -E "(Device|sd|nvme)"

# 12. 系统温度信息
print_section "12. 系统温度信息"
echo "参数说明:"
echo "  CPU温度: 处理器核心的当前温度"
echo "  主板温度: 主板芯片组的当前温度"
echo ""
echo "硬件温度传感器信息:"
if command -v sensors >/dev/null 2>&1; then
    sensors 2>/dev/null
else
    echo "  未安装lm-sensors工具, 无法获取温度信息"
    echo "  安装命令: sudo apt-get install lm-sensors && sudo sensors-detect"
fi

# 13. CPU详细信息
print_section "13. CPU详细信息"
echo "CPU型号和频率信息:"
lscpu | grep -E "(Model name|CPU.*MHz)"

# 14. 进程信息
print_section "14. 进程信息"
echo "参数说明:"
echo "  R (Running): 正在运行或可运行的进程"
echo "  S (Sleeping): 可中断睡眠的进程"
echo "  D (Uninterruptible Sleep): 不可中断睡眠的进程"
echo "  T (Stopped): 停止或被追踪的进程"
echo "  Z (Zombie): 僵尸进程"
echo ""
echo "进程状态统计:"
ps aux | awk 'NR>1 {print $8}' | sort | uniq -c | while read count state; do
    echo "  状态 $state: $count 个进程"
done | sort -k4 -n -r
echo ""
echo "占用CPU最高的5个进程:"
ps aux --sort=-%cpu | head -n 6 | awk '{printf "  %-8s %-8s %-6s %-6s %s\n", $1, $2, $3, $4, $11}'

# 15. 网络连接信息
print_section "15. 网络连接信息"
echo "网络连接统计:"
ss -s 2>/dev/null || echo "  无法获取网络连接统计信息"

# 16. 系统运行时间
print_section "16. 系统运行时间"
echo "系统启动时间:"
echo "  系统启动于: $(uptime -s)"
echo "系统运行时间:"
uptime -p

print_separator
echo "修复版系统性能监控完成"
echo "报告已保存到: $OUTPUT_FILE"
print_separator

echo ""
echo "注意: 如果某些部分显示为空或错误信息，请确保已安装相应的工具:"
echo "  - lm-sensors: 用于温度监控 (sudo apt install lm-sensors)"
echo "  - sysstat: 用于iostat等命令 (sudo apt install sysstat)"
echo "  - iproute2: 用于网络信息 (通常默认安装)"

} > "$OUTPUT_FILE"
echo "报告已保存到: $OUTPUT_FILE"