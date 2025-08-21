#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认参数
INTERVAL=5
DURATION=60
CONTINUOUS_MODE=false

# 日志文件
LOG_FILE="optimized_system_performance_$(date +%Y%m%d_%H%M%S).log"

# 显示标题
show_header() {
    echo -e "${CYAN}=================================${NC}"
    echo -e "${CYAN}   系统性能监控脚本${NC}"
    echo -e "${CYAN}=================================${NC}"
    echo ""
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -c, --continuous    启用持续监控模式"
    echo "  -i, --interval SEC  设置监控间隔秒数 (默认: 5)"
    echo "  -d, --duration SEC  设置监控持续时间秒数 (默认: 60, 0表示无限)"
    echo "  -h, --help          显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                  一次性监控"
    echo "  $0 -c               持续监控，默认参数"
    echo "  $0 -c -i 10 -d 300  每10秒监控一次，持续300秒"
    echo "  $0 -c -i 5 -d 0     每5秒监控一次，无限持续"
}

# 获取CPU信息
get_cpu_info() {
    echo -e "${GREEN}>>> CPU信息${NC}"
    echo "---------------------------------"
    
    # CPU型号
    cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    echo "CPU型号: $cpu_model"
    
    # CPU核心数
    cpu_cores=$(nproc)
    echo "CPU核心数: $cpu_cores"
    
    # CPU使用率 (使用top命令获取1秒内的快照)
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    echo "CPU使用率: $cpu_usage"
    
    # CPU负载
    read load1 load5 load15 <<< $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1 $2 $3}' | sed 's/,/ /g')
    echo "系统负载 (1min): $load1"
    echo "系统负载 (5min): $load5" 
    echo "系统负载 (15min): $load15"
    
    echo ""
}

# 获取内存信息
get_memory_info() {
    echo -e "${YELLOW}>>> 内存信息${NC}"
    echo "---------------------------------"
    
    # 内存信息
    mem_info=$(free -h | grep Mem)
    mem_total=$(echo $mem_info | awk '{print $2}')
    mem_used=$(echo $mem_info | awk '{print $3}')
    mem_free=$(echo $mem_info | awk '{print $4}')
    mem_usage_percent=$(echo $mem_info | awk '{printf "%.1f", $3/$2 * 100}')
    
    echo "总内存: $mem_total"
    echo "已使用: $mem_used"
    echo "可用内存: $mem_free"
    echo "内存使用率: $mem_usage_percent%"
    
    echo ""
}

# 获取磁盘信息
get_disk_info() {
    echo -e "${BLUE}>>> 磁盘信息${NC}"
    echo "---------------------------------"
    
    # 磁盘使用情况
    disk_info=$(df -h / | tail -1)
    disk_total=$(echo $disk_info | awk '{print $2}')
    disk_used=$(echo $disk_info | awk '{print $3}')
    disk_available=$(echo $disk_info | awk '{print $4}')
    disk_usage_percent=$(echo $disk_info | awk '{print $5}' | sed 's/%//')
    
    echo "总磁盘空间: $disk_total"
    echo "已使用空间: $disk_used"
    echo "可用空间: $disk_available"
    echo "磁盘使用率: $disk_usage_percent%"
    
    echo ""
}

# 获取GPU信息
get_gpu_info() {
    echo -e "${PURPLE}>>> GPU信息${NC}"
    echo "---------------------------------"
    
    if command -v nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name,pci.bus_id,utilization.gpu,memory.used,memory.total,temperature.gpu,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,power.draw,power.limit --format=csv,noheader,nounits)
        
        gpu_name=$(echo $gpu_info | cut -d',' -f1 | xargs)
        gpu_bus_id=$(echo $gpu_info | cut -d',' -f2 | xargs)
        gpu_util=$(echo $gpu_info | cut -d',' -f3 | xargs)
        gpu_mem_used=$(echo $gpu_info | cut -d',' -f4 | xargs)
        gpu_mem_total=$(echo $gpu_info | cut -d',' -f5 | xargs)
        gpu_temp=$(echo $gpu_info | cut -d',' -f6 | xargs)
        pcie_gen_current=$(echo $gpu_info | cut -d',' -f7 | xargs)
        pcie_gen_max=$(echo $gpu_info | cut -d',' -f8 | xargs)
        pcie_width_current=$(echo $gpu_info | cut -d',' -f9 | xargs)
        pcie_width_max=$(echo $gpu_info | cut -d',' -f10 | xargs)
        gpu_power_draw=$(echo $gpu_info | cut -d',' -f11 | xargs)
        gpu_power_limit=$(echo $gpu_info | cut -d',' -f12 | xargs)
        
        echo "GPU型号: $gpu_name"
        echo "GPU总线ID: $gpu_bus_id"
        echo "GPU使用率: $gpu_util%"
        echo "显存使用: ${gpu_mem_used}MB / ${gpu_mem_total}MB"
        echo "GPU温度: $gpu_temp°C"
        echo "GPU功耗: ${gpu_power_draw}W / ${gpu_power_limit}W"
        
        # 计算显存使用率
        if [ "$gpu_mem_total" -ne 0 ]; then
            gpu_mem_percent=$((gpu_mem_used * 100 / gpu_mem_total))
            echo "显存使用率: $gpu_mem_percent%"
        fi
        
        # PCIe信息
        echo "PCIe链路信息: Gen $pcie_gen_current x$pcie_width_current (最大支持: Gen $pcie_gen_max x$pcie_width_max)"
        
        # 计算理论带宽
        # PCIe带宽 (GB/s) = (GEN值 * 0.25 GB/s) * 通道数 * 2 (因为是全双工)
        # Gen1 = 250 MB/s 每通道, Gen2 = 500 MB/s 每通道, Gen3 = 1 GB/s 每通道, Gen4 = 2 GB/s 每通道
        case $pcie_gen_current in
            1) pcie_bandwidth_per_lane=0.25 ;;
            2) pcie_bandwidth_per_lane=0.5 ;;
            3) pcie_bandwidth_per_lane=1.0 ;;
            4) pcie_bandwidth_per_lane=2.0 ;;
            *) pcie_bandwidth_per_lane=0.25 ;;
        esac
        
        pcie_current_bandwidth=$(echo "$pcie_bandwidth_per_lane * $pcie_width_current * 2" | bc -l)
        pcie_current_bandwidth=$(printf "%.2f" $pcie_current_bandwidth)
        
        case $pcie_gen_max in
            1) pcie_max_bandwidth_per_lane=0.25 ;;
            2) pcie_max_bandwidth_per_lane=0.5 ;;
            3) pcie_max_bandwidth_per_lane=1.0 ;;
            4) pcie_max_bandwidth_per_lane=2.0 ;;
            *) pcie_max_bandwidth_per_lane=0.25 ;;
        esac
        
        pcie_max_bandwidth=$(echo "$pcie_max_bandwidth_per_lane * $pcie_width_max * 2" | bc -l)
        pcie_max_bandwidth=$(printf "%.2f" $pcie_max_bandwidth)
        
        echo "当前PCIe带宽: ${pcie_current_bandwidth} GB/s (最大: ${pcie_max_bandwidth} GB/s)"
        
        # 估算数据传输量 (基于显存使用情况)
        # 这是一个粗略估算，实际数据传输量可能包括显存数据、纹理、命令等
        echo "估算数据传输: 显存使用量 ${gpu_mem_used}MB (此为GPU上已使用的显存量)"
    else
        echo "未检测到NVIDIA GPU或nvidia-smi工具"
    fi
    
    echo ""
}

# 获取GPU进程信息（用于数据传输监控）
get_gpu_processes() {
    echo -e "${PURPLE}>>> GPU进程信息${NC}"
    echo "---------------------------------"
    
    if command -v nvidia-smi &> /dev/null; then
        # 获取GPU进程信息
        process_info=$(nvidia-smi pmon -c 1 2>/dev/null)
        if [ -n "$process_info" ] && [ "$(echo "$process_info" | wc -l)" -gt 1 ]; then
            echo "GPU进程监控 (PID, 类型, 显存使用, GPU使用率):"
            echo "$process_info" | tail -n +2 | while read line; do
                if [ -n "$line" ]; then
                    pid=$(echo "$line" | awk '{print $1}')
                    type=$(echo "$line" | awk '{print $2}')
                    mem=$(echo "$line" | awk '{print $3}')
                    sm=$(echo "$line" | awk '{print $4}')
                    echo "  PID: $pid, 类型: $type, 显存: ${mem}MB, GPU使用率: ${sm}%"
                fi
            done
        else
            echo "当前没有GPU进程运行"
        fi
    else
        echo "未检测到NVIDIA GPU或nvidia-smi工具"
    fi
    
    echo ""
}

# 获取传感器温度信息
get_sensor_info() {
    echo -e "${RED}>>> 传感器温度信息${NC}"
    echo "---------------------------------"
    
    if command -v sensors &> /dev/null; then
        sensors_output=$(sensors)
        echo "$sensors_output" | head -20
    else
        echo "未安装传感器工具(sensors)"
    fi
    
    echo ""
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--continuous)
                CONTINUOUS_MODE=true
                shift
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -d|--duration)
                DURATION="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 持续监控模式
continuous_monitor() {
    echo -e "${CYAN}开始持续监控模式${NC}"
    echo -e "${CYAN}监控间隔: ${INTERVAL}秒${NC}"
    if [ "$DURATION" -eq 0 ]; then
        echo -e "${CYAN}监控持续时间: 无限${NC}"
    else
        echo -e "${CYAN}监控持续时间: ${DURATION}秒${NC}"
    fi
    echo ""
    
    local start_timestamp=$(date +%s)
    local count=0
    
    while true; do
        local current_timestamp=$(date +%s)
        local elapsed=$((current_timestamp - start_timestamp))
        
        # 检查是否超过持续时间
        if [ "$DURATION" -ne 0 ] && [ "$elapsed" -ge "$DURATION" ]; then
            echo -e "${CYAN}监控时间已到，结束监控${NC}"
            break
        fi
        
        count=$((count + 1))
        echo -e "${CYAN}==== 监控轮次: $count (已运行: $elapsed 秒) ====${NC}"
        echo ""
        
        # 获取各项系统信息
        get_cpu_info
        get_memory_info
        get_disk_info
        get_gpu_info
        get_gpu_processes
        get_sensor_info
        
        echo ""
        echo "---------------------------------"
        echo ""
        
        # 等待指定间隔
        sleep "$INTERVAL"
    done
}

# 主函数
main() {
    parse_args "$@"
    
    show_header
    
    if [ "$CONTINUOUS_MODE" = true ]; then
        continuous_monitor
    else
        # 记录开始时间
        start_time=$(date)
        echo "监控开始时间: $start_time" | tee "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
        
        # 获取各项系统信息
        {
            get_cpu_info
            get_memory_info
            get_disk_info
            get_gpu_info
            get_sensor_info
        } | tee -a "$LOG_FILE"
        
        # 记录结束时间
        end_time=$(date)
        echo "监控结束时间: $end_time" | tee -a "$LOG_FILE"
        
        echo ""
        echo -e "${CYAN}系统性能信息已保存到: $LOG_FILE${NC}"
    fi
}

# 运行主函数
main
