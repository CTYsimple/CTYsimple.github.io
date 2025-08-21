#!/bin/bash

# GPU带宽监控脚本
# 用于监控CPU到GPU的数据传输和带宽占用情况

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 显示标题
show_header() {
    clear
    echo -e "${CYAN}=================================${NC}"
    echo -e "${CYAN}   GPU带宽监控脚本${NC}"
    echo -e "${CYAN}=================================${NC}"
    echo ""
}

# 检查是否安装了nvidia-smi
check_nvidia_smi() {
    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${RED}错误: 未找到nvidia-smi命令，请确保已安装NVIDIA驱动${NC}"
        exit 1
    fi
}

# 获取GPU带宽信息
get_gpu_bandwidth_info() {
    echo -e "${PURPLE}>>> GPU带宽信息${NC}"
    echo "---------------------------------"
    
    # 获取GPU信息
    gpu_info=$(nvidia-smi --query-gpu=name,pci.bus_id,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,pcie.link.gen.current,pcie.link.width.current --format=csv,noheader,nounits)
    
    gpu_name=$(echo $gpu_info | cut -d',' -f1 | xargs)
    gpu_bus_id=$(echo $gpu_info | cut -d',' -f2 | xargs)
    gpu_util=$(echo $gpu_info | cut -d',' -f3 | xargs)
    mem_util=$(echo $gpu_info | cut -d',' -f4 | xargs)
    gpu_mem_used=$(echo $gpu_info | cut -d',' -f5 | xargs)
    gpu_mem_total=$(echo $gpu_info | cut -d',' -f6 | xargs)
    gpu_temp=$(echo $gpu_info | cut -d',' -f7 | xargs)
    pcie_gen_current=$(echo $gpu_info | cut -d',' -f8 | xargs)
    pcie_width_current=$(echo $gpu_info | cut -d',' -f9 | xargs)
    
    echo "GPU型号: $gpu_name"
    echo "GPU总线ID: $gpu_bus_id"
    echo "GPU使用率: $gpu_util%"
    echo "显存使用率: $mem_util%"
    echo "显存使用: ${gpu_mem_used}MB / ${gpu_mem_total}MB"
    echo "GPU温度: $gpu_temp°C"
    echo "PCIe链路: Gen $pcie_gen_current x$pcie_width_current"
    
    # 计算理论带宽 (GB/s)
    # Gen1 = 250 MB/s 每通道, Gen2 = 500 MB/s 每通道, Gen3 = 1 GB/s 每通道, Gen4 = 2 GB/s 每通道
    case $pcie_gen_current in
        1) pcie_bandwidth_per_lane=0.25 ;;
        2) pcie_bandwidth_per_lane=0.5 ;;
        3) pcie_bandwidth_per_lane=1.0 ;;
        4) pcie_bandwidth_per_lane=2.0 ;;
        *) pcie_bandwidth_per_lane=0.25 ;;
    esac
    
    # 全双工带宽 (发送+接收)
    pcie_current_bandwidth=$(echo "$pcie_bandwidth_per_lane * $pcie_width_current * 2" | bc -l)
    pcie_current_bandwidth=$(printf "%.2f" $pcie_current_bandwidth)
    
    echo "理论带宽: ${pcie_current_bandwidth} GB/s"
    
    # 估算实际带宽使用情况
    # 基于GPU使用率和显存使用率进行估算
    estimated_bandwidth=$(echo "$pcie_current_bandwidth * $gpu_util / 100" | bc -l)
    estimated_bandwidth=$(printf "%.2f" $estimated_bandwidth)
    
    echo "估算实际带宽使用: ${estimated_bandwidth} GB/s"
    echo "估算带宽占用率: $gpu_util%"
    
    # 显存带宽估算
    echo ""
    echo -e "${BLUE}>>> 显存带宽估算${NC}"
    echo "---------------------------------"
    mem_bandwidth_used=$(echo "$pcie_current_bandwidth * $mem_util / 100" | bc -l)
    mem_bandwidth_used=$(printf "%.2f" $mem_bandwidth_used)
    echo "显存带宽使用: ${mem_bandwidth_used} GB/s"
    echo "显存带宽占用率: $mem_util%"
    
    echo ""
}

# 持续监控模式
continuous_monitor() {
    echo -e "${YELLOW}按 Ctrl+C 停止监控${NC}"
    echo ""
    
    while true; do
        show_header
        get_gpu_bandwidth_info
        echo -e "${YELLOW}刷新时间: $(date)${NC}"
        sleep 2
    done
}

# 显示帮助信息
show_help() {
    echo "GPU带宽监控脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -c, --continuous    持续监控模式"
    echo "  -h, --help          显示此帮助信息"
    echo ""
    echo "说明:"
    echo "  该脚本用于监控GPU的带宽使用情况，包括理论带宽和估算的实际带宽使用。"
    echo "  估算值基于GPU使用率和显存使用率计算得出。"
}

# 主函数
main() {
    check_nvidia_smi
    
    case "$1" in
        -c|--continuous)
            continuous_monitor
            ;;
        -h|--help)
            show_help
            ;;
        *)
            show_header
            get_gpu_bandwidth_info
            echo -e "${YELLOW}刷新时间: $(date)${NC}"
            ;;
    esac
}

# 运行主函数
main "$@"