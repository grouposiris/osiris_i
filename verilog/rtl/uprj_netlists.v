// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

// Include caravel global defines for the number of the user project IO pads 
`include "defines.v"
`define USE_POWER_PINS

`ifdef GL
    // Assume default net type to be wire because GL netlists don't have the wire definitions
    `default_nettype wire
    `include "gl/user_project_wrapper.v"
    `include "gl/user_proj_example.v"
    `include "gl/osiris_i.v"
`else
    `include "user_project_wrapper.v"
    `include "./osiris_i/adder.v"
    `include "./osiris_i/alu_decoder.v"
    `include "./osiris_i/alu.v"
    `include "./osiris_i/apb_bus.v"
    `include "./osiris_i/control_unit.v"
    `include "./osiris_i/core.v"
    `include "./osiris_i/datapath.v"
    `include "./osiris_i/ex_mem.v"
    `include "./osiris_i/extend_unit.v"
    `include "./osiris_i/full_adder.v"
    `include "./osiris_i/hazard_unit.v"
    `include "./osiris_i/id_ex.v"
    `include "./osiris_i/if_id.v"
    `include "./osiris_i/mem_wb.v"
    `include "./osiris_i/mux_2x1.v"
    `include "./osiris_i/mux_4x1.v"
    `include "./osiris_i/next_pc.v"
    `include "./osiris_i/op_decoder.v"
    `include "./osiris_i/osiris_i.v"
    `include "./osiris_i/pc_target.v"
    `include "./osiris_i/register_file.v"
    `include "./osiris_i/stage_decode.v"
    `include "./osiris_i/stage_execute.v"
    `include "./osiris_i/stage_fetch.v"
    `include "./osiris_i/stage_write_back.v"
    `include "./osiris_i/wishbone_master.v"
    `include "./osiris_i/mem.v"
    `include "./osiris_i/uart_wbs_bridge.v"
    `include "user_proj_example.v"
`endif
