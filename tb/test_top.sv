// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "apb4_if.sv"
`include "helper.sv"
`include "spi_define.sv"

program automatic test_top (
    apb4_if.master apb4,
    spi_if.tb      spi
);

  string wave_name = "default.fsdb";
  task sim_config();
    $timeformat(-9, 1, "ns", 10);
    if ($test$plusargs("WAVE_ON")) begin
      $value$plusargs("WAVE_NAME=%s", wave_name);
      $fsdbDumpfile(wave_name);
      $fsdbDumpvars("+all");
    end
  endtask

  SPITest spi_hdl;

  initial begin
    Helper::start_banner();
    sim_config();
    @(posedge apb4.presetn);
    Helper::print("tb init done");
    spi_hdl = new("spi_test", apb4, spi);
    spi_hdl.init();
    spi_hdl.test_reset_reg();
    spi_hdl.test_wr_rd_reg();
    spi_hdl.sm_test_div_clk();
    // spi_hdl.spi_flash_id_read();
    // spi_hdl.spi_flash_sector_erase(0);
    // spi_hdl.manu_send_data();
    // spi_hdl.w25q_std_spi_wr_rd_test();
    // spi_hdl.w25q_dual_spi_wr_rd_test();
    // spi_hdl.w25q_quad_spi_wr_rd_test();
    // spi_hdl.test_irq();
    // spi_hdl.single_8_data_wr_test();

    Helper::end_banner();
    #20000 $finish;
  end

endprogram
