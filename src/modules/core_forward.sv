import structures::forward_type_t;
import structures::NO_FORWARD;
import structures::FORWARD_ALU;
import structures::FORWARD_MEM;

module core_forward (
    input logic [4:0] IF_rs,  // IF 阶段下一条指令的 rs
    input logic [4:0] IF_rt,  // IF 阶段下一条指令的 rt
    input logic IF_B_is_reg,  // IF 阶段：rt 是寄存器输入（否则是立即数）
    input logic [4:0] ID_rs,  // ID 阶段当前指令的 rs
    input logic [4:0] ID_rt,  // ID 阶段当前指令的 rt
    input logic ID_B_is_reg,  // ID 阶段：rt 是寄存器输入
    input logic [4:0] EX_rd,  // EX 阶段写回寄存器号
    input logic EX_alu_writeback,  // EX 阶段：ALU 操作要写回
    input logic [4:0] MEM_rd,  // MEM 阶段写回寄存器号
    input logic MEM_mem_writeback,  // MEM 阶段：内存读结果要写回

    output forward_type_t forward_A,     // 给 ID 阶段的 A 操作数
    output forward_type_t forward_B,     // 给 ID 阶段的 B 操作数
    output forward_type_t forward_A_ID,  // 给 IF/ID 阶段（下一级 ID）的 A
    output forward_type_t forward_B_ID   // 给 IF/ID 阶段（下一级 ID）的 B
);

    always_comb begin
        forward_A    = NO_FORWARD;
        forward_B    = NO_FORWARD;
        forward_A_ID = NO_FORWARD;
        forward_B_ID = NO_FORWARD;

        // ── 对 ID 阶段 (EX stage 的 src) 做转发 ──
        // MEM 优先级最高
        if (MEM_mem_writeback && (MEM_rd != 0)) begin
            if (MEM_rd == ID_rs) forward_A = FORWARD_MEM;
            if ((MEM_rd == ID_rt) && ID_B_is_reg) forward_B = FORWARD_MEM;
        end
        // // EX 其次（只转发 ALU 写回，不转发 load）
        // if (EX_alu_writeback && (EX_rd != 0)) begin
        //     if ((forward_A == NO_FORWARD) && (EX_rd == ID_rs)) forward_A = FORWARD_ALU;
        //     if ((forward_B == NO_FORWARD) && (EX_rd == ID_rt) && ID_B_is_reg)
        //         forward_B = FORWARD_ALU;
        // end

        // // ── 对下一级 IF/ID 阶段 (ID stage 的 src) 做转发 ──
        // // MEM 先
        // if (MEM_mem_writeback && (MEM_rd != 0)) begin
        //     if (MEM_rd == IF_rs) forward_A_ID = FORWARD_MEM;
        //     if ((MEM_rd == IF_rt) && IF_B_is_reg) forward_B_ID = FORWARD_MEM;
        // end
        // EX 后
        if (EX_alu_writeback && (EX_rd != 0)) begin
            if ((forward_A_ID == NO_FORWARD) && (EX_rd == IF_rs)) forward_A_ID = FORWARD_ALU;
            if ((forward_B_ID == NO_FORWARD) && (EX_rd == IF_rt) && IF_B_is_reg)
                forward_B_ID = FORWARD_ALU;
        end
    end

endmodule
