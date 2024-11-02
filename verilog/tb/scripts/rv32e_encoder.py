from tabulate import tabulate
import pandas as pd
import re
import sys

# Define the RV32E register names
REGISTERS = {f'x{i}': i for i in range(16)}  # x0 to x15

# Define the opcode, funct3, and funct7 mappings
INSTRUCTION_SET = {
    'add':   {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b000, 'funct7': 0b0000000},
    'sub':   {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b000, 'funct7': 0b0100000},
    'sll':   {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b001, 'funct7': 0b0000000},
    'slt':   {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b010, 'funct7': 0b0000000},
    'sltu':  {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b011, 'funct7': 0b0000000},
    'xor':   {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b100, 'funct7': 0b0000000},
    'srl':   {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b101, 'funct7': 0b0000000},
    'sra':   {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b101, 'funct7': 0b0100000},
    'or':    {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b110, 'funct7': 0b0000000},
    'and':   {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b111, 'funct7': 0b0000000},

    'addi':  {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b000},
    'slti':  {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b010},
    'sltiu': {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b011},
    'xori':  {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b100},
    'ori':   {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b110},
    'andi':  {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b111},
    'slli':  {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b001, 'funct7': 0b0000000},
    'srli':  {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b101, 'funct7': 0b0000000},
    'srai':  {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b101, 'funct7': 0b0100000},

    'lb':    {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b000},
    'lh':    {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b001},
    'lw':    {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b010},
    'lbu':   {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b100},
    'lhu':   {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b101},

    'sw':    {'type': 'S', 'opcode': 0b0100011, 'funct3': 0b010},
    'sh':    {'type': 'S', 'opcode': 0b0100011, 'funct3': 0b001},
    'sb':    {'type': 'S', 'opcode': 0b0100011, 'funct3': 0b000},

    'beq':   {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b000},
    'bne':   {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b001},
    'blt':   {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b100},
    'bge':   {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b101},
    'bltu':  {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b110},
    'bgeu':  {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b111},

    'jal':   {'type': 'J', 'opcode': 0b1101111},
    'jalr':  {'type': 'I', 'opcode': 0b1100111, 'funct3': 0b000},

    'lui':   {'type': 'U', 'opcode': 0b0110111},
    'auipc': {'type': 'U', 'opcode': 0b0010111},

    'ecall':   {'type': 'I', 'opcode': 0b1110011, 'funct3': 0b000, 'funct12': 0b000000000000},
    'ebreak':  {'type': 'I', 'opcode': 0b1110011, 'funct3': 0b000, 'funct12': 0b000000000001},
    'fence':   {'type': 'I', 'opcode': 0b0001111, 'funct3': 0b000},
    'fence.i': {'type': 'I', 'opcode': 0b0001111, 'funct3': 0b001},
}


def parse_register(reg_str):
    if reg_str in REGISTERS:
        return REGISTERS[reg_str]
    else:
        raise ValueError(
            f"Invalid register '{reg_str}'. Valid registers are x0 to x15.")


def sign_extend(value, bits):
    sign_bit = 1 << (bits - 1)
    return_value = (value & (sign_bit - 1)) - (value & sign_bit)
    return return_value


def encode_instruction(instr_str, line_num=None):
    # Remove comments and extra whitespace
    instr_str = instr_str.split('#')[0].strip()
    if not instr_str:
        return None  # Empty line or comment line

    # Split mnemonic and operands
    tokens = re.split(r'[,\s()]+', instr_str)
    tokens = [t for t in tokens if t]  # Remove empty strings

    mnemonic = tokens[0]
    operands = tokens[1:]

    if mnemonic not in INSTRUCTION_SET:
        raise ValueError(f"Unsupported instruction '{mnemonic}'.")

    instr_info = INSTRUCTION_SET[mnemonic]
    instr_type = instr_info['type']
    opcode = instr_info['opcode']
    funct3 = instr_info.get('funct3', 0)
    funct7 = instr_info.get('funct7', 0)

    rd = rs1 = rs2 = imm = 0

    if instr_type == 'R':
        if len(operands) != 3:
            raise ValueError(f"Instruction '{mnemonic}' requires 3 operands.")
        rd = parse_register(operands[0])
        rs1 = parse_register(operands[1])
        rs2 = parse_register(operands[2])
        machine_code = (
            (funct7 << 25) |
            (rs2 << 20) |
            (rs1 << 15) |
            (funct3 << 12) |
            (rd << 7) |
            opcode
        )
    elif instr_type == 'I':
        if mnemonic in ['xori']:
            print("xori")
        if mnemonic in ['slli', 'srli', 'srai']:
            if len(operands) != 3:
                raise ValueError(
                    f"Instruction '{mnemonic}' requires 3 operands.")
            rd = parse_register(operands[0])
            rs1 = parse_register(operands[1])
            shamt = int(operands[2], 0)
            if shamt < 0 or shamt > 15:
                raise ValueError(
                    "Shift amount must be between 0 and 15 for RV32E.")
            machine_code = (
                (funct7 << 25) |
                (shamt << 20) |
                (rs1 << 15) |
                (funct3 << 12) |
                (rd << 7) |
                opcode
            )
        elif mnemonic == 'jalr':
            if len(operands) != 3:
                raise ValueError(
                    f"Instruction '{mnemonic}' requires 3 operands.")
            rd = parse_register(operands[0])
            rs1 = parse_register(operands[1])
            imm = int(operands[2], 0)
            imm = sign_extend(imm, 12) & 0xFFF
            machine_code = (
                (imm << 20) |
                (rs1 << 15) |
                (funct3 << 12) |
                (rd << 7) |
                opcode
            )
        else:
            # xori x1, x2, 0x2
            if len(operands) != 3:
                raise ValueError(
                    f"Instruction '{mnemonic}' requires 3 operands.")
            rd = parse_register(operands[0])
            rs1 = parse_register(operands[1])
            imm = int(operands[2], 0)
            # imm = sign_extend(imm, 12) & 0xFFF
            imm = sign_extend(imm, 12)  # imm = 0x00000002
            # machine_code = (
            #     (imm << 20) |           # (0x002 << 20) = 0x00200000
            #     (rs1 << 15) |           # (2 << 15)     = 0x00010000
            #     (funct3 << 12) |        # (4 << 12)     = 0x00004000
            #     (rd << 7) |             # (1 << 7)      = 0x00000080
            #     opcode                  #               = 0x00000013
            # )
            machine_code = (
                ((imm & 0xFFF) << 20) |
                (rs1 << 15) |
                (funct3 << 12) |
                (rd << 7) |
                opcode
            ) & 0xFFFFFFFF
    elif instr_type == 'S':
        if len(operands) != 3:
            raise ValueError(f"Instruction '{mnemonic}' requires 3 operands.")
        rs2 = parse_register(operands[0])

        imm_val = operands[1]
        rs1_str = operands[2]
        rs1 = parse_register(rs1_str)
        imm = int(imm_val, 0)
        imm = sign_extend(imm, 12) & 0xFFF
        imm_11_5 = (imm >> 5) & 0x7F
        imm_4_0 = imm & 0x1F

        machine_code = (
            (imm_11_5 << 25) |
            (rs2 << 20) |
            (rs1 << 15) |
            (funct3 << 12) |
            (imm_4_0 << 7) |
            opcode
        )
    elif instr_type == 'B':
        if len(operands) != 3:
            raise ValueError(f"Instruction '{mnemonic}' requires 3 operands.")
        rs1 = parse_register(operands[0])
        rs2 = parse_register(operands[1])
        imm = int(operands[2], 0)
        imm = sign_extend(imm, 13)  # Branch offsets are 13 bits
        imm_12 = (imm >> 12) & 0x1
        imm_10_5 = (imm >> 5) & 0x3F
        imm_4_1 = (imm >> 1) & 0xF
        imm_11 = (imm >> 11) & 0x1
        machine_code = (
            (imm_12 << 31) |
            (imm_10_5 << 25) |
            (rs2 << 20) |
            (rs1 << 15) |
            (funct3 << 12) |
            (imm_4_1 << 8) |
            (imm_11 << 7) |
            opcode
        )
    elif instr_type == 'U':
        if len(operands) != 2:
            raise ValueError(f"Instruction '{mnemonic}' requires 2 operands.")
        rd = parse_register(operands[0])
        imm = int(operands[1], 0)
        imm = imm & 0xFFFFF000  # Upper 20 bits
        machine_code = (
            (imm) |
            (rd << 7) |
            opcode
        )
    elif instr_type == 'J':
        if len(operands) != 2:
            raise ValueError(f"Instruction '{mnemonic}' requires 2 operands.")
        rd = parse_register(operands[0])
        imm = int(operands[1], 0)
        imm = sign_extend(imm, 21)
        imm_20 = (imm >> 20) & 0x1
        imm_19_12 = (imm >> 12) & 0xFF
        imm_11 = (imm >> 11) & 0x1
        imm_10_1 = (imm >> 1) & 0x3FF
        machine_code = (
            (imm_20 << 31) |
            (imm_19_12 << 12) |
            (imm_11 << 20) |
            (imm_10_1 << 21) |
            (rd << 7) |
            opcode
        )
    else:
        raise ValueError(f"Unsupported instruction type '{instr_type}'.")

    # Create a dictionary of the instruction fields for display
    fields = {
        'opcode': opcode,
        'rd': rd,
        'funct3': funct3,
        'rs1': rs1,
        'rs2': rs2,
        'funct7': funct7,
        'imm': imm,
        'machine_code': machine_code
    }

    return fields


# Modified process_file function with formatted output using a dataframe
# Adjust DataFrame display settings to show complete content for each cell
# Remove truncation for long text fields
pd.set_option("display.max_colwidth", None)


def display_formatted_output(instruction_list, fields_list, machine_code_list):
    # Create DataFrame for structured output
    df = pd.DataFrame({
        "Instruction": instruction_list,
        "Fields": fields_list,
        "Machine Code (Hex)": machine_code_list
    })
    # Display formatted table
    print(df)


def process_file(input_file, output_file):
    # Initialize lists for DataFrame
    instruction_list = []
    fields_list = []
    machine_code_list = []

    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        line_num = 0
        for line in infile:
            line_num += 1
            instr_str = line.strip()
            if not instr_str or instr_str.startswith('#'):
                # Collecting data for DataFrame
                instruction_list.append(instr_str)
                fields_list.append("")
                machine_code_list.append("")
                # Writing to output file
                outfile.write(instr_str + '\n')
                continue  # Skip empty lines and comments
            else:
                try:
                    if instr_str == "exit":
                        print("Exit instruction, finishing...")
                        break
                    else:
                        fields = encode_instruction(instr_str, line_num)
                        if fields:
                            # Collecting data for DataFrame
                            instruction_list.append(instr_str)
                            fields_list.append(str(fields))
                            machine_code_hex = f"{fields['machine_code']:08X}"
                            machine_code_list.append(machine_code_hex)
                            # Writing to output file
                            outfile.write(machine_code_hex + '\n')
                except ValueError as e:
                    print(f"Error on line {line_num}: {e}")
                    continue

    # Create DataFrame for structured output

    df = pd.DataFrame({
        "Instruction": instruction_list,
        "Fields": fields_list,
        "Machine Code (Hex)": machine_code_list
    })
    # Display formatted table
    # print(df)
    print(tabulate(df, headers='keys', tablefmt='grid', showindex=False))


# Displaying the formatted output function in action would require encode_instruction and an input file.
# This is a mockup intended to show the DataFrame-based formatting.


# def main():
#     if len(sys.argv) != 3:
#         print("Usage: python rv32e_encoder.py <input_file> <output_file>")
#         sys.exit(1)
#     input_file = sys.argv[1]
#     output_file = sys.argv[2]
#     process_file(input_file, output_file)
#     print(
#         f"Encoding complete. Hexadecimal machine codes written to '{output_file}'.")


# if __name__ == "__main__":
#     main()
folder = "/home/lspadersimon/repos/osiris_i/verilog/tb"
input_file = f"{folder}/instructions.txt"
output_file = f"{folder}/output_hex.txt"

process_file(input_file, output_file)
print(
    f"Encoding complete. Hexadecimal machine codes written to '{output_file}'.")

# Usage
# python rv32e_encoder.py instructions.txt output_hex.txt
