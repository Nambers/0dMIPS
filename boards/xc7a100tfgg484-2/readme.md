# DaVinci Pro FPGA Development Board (Xilinx Artix-7 XC7A100T)

## Board info

<https://github.com/alientek-openedv/Products/blob/master/zdyz_docs/boards/fpga/zdyz_dafenqipro.rst>

<http://47.111.11.73/docs/boards/fpga/zdyz_dafenqipro.html> <https://pan.baidu.com/s/110wcO-FVa9HCz8DSryWDyQ?pwd=1oat>

## How to use

```bash
python generate_vivado_project.py --target_path <workspace>
cd <workspace>
vivado -mode tcl -source create_proj.tcl
```
