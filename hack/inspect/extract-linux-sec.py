import sys
import struct
import subprocess

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 extract-linux-sec.py <vmlinuz_efi> <output_vmlinux>")
        sys.exit(1)
        
    efi_path = sys.argv[1]
    out_path = sys.argv[2]
    
    with open(efi_path, 'rb') as f:
        data = f.read()
        
    if data[:2] != b'MZ':
        print("Not a PE file.")
        sys.exit(1)
        
    pe_offset = struct.unpack('<I', data[0x3c:0x40])[0]
    if data[pe_offset:pe_offset+4] != b'PE\x00\x00':
        print("Invalid PE magic.")
        sys.exit(1)
        
    num_sections = struct.unpack('<H', data[pe_offset+6:pe_offset+8])[0]
    size_optional_header = struct.unpack('<H', data[pe_offset+20:pe_offset+22])[0]
    section_table_offset = pe_offset + 24 + size_optional_header
    
    linux_ptr = None
    linux_size = None
    
    for i in range(num_sections):
        sec_offset = section_table_offset + i * 40
        name = data[sec_offset:sec_offset+8].rstrip(b'\x00').decode('latin1')
        if name == '.linux':
            vsize, vaddr, raw_size, raw_ptr = struct.unpack('<IIII', data[sec_offset+8:sec_offset+24])
            linux_ptr = raw_ptr
            linux_size = raw_size
            break
            
    if linux_ptr is None:
        print("Error: .linux section not found.")
        sys.exit(1)
        
    print(f"Found .linux section at raw pointer {linux_ptr} with size {linux_size}")
    
    linux_data = data[linux_ptr:linux_ptr+linux_size]
    print(f"First 4 bytes of .linux section: {linux_data[:4].hex()}")
    
    temp_zst = out_path + ".zst"
    with open(temp_zst, 'wb') as f:
        f.write(linux_data)
        
    # Decompress using zstd
    try:
        subprocess.run(['zstd', '-d', '-f', '-o', out_path, temp_zst], check=True)
        print(f"Successfully decompressed to {out_path}")
    except Exception as e:
        print(f"Error decompressing: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
