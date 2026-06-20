import sys
import struct

def parse_module_signature(filepath):
    with open(filepath, 'rb') as f:
        data = f.read()
    
    magic = b'~Module signature appended~\n'
    if not data.endswith(magic):
        magic = b'~Module signature appended~'
        if not data.endswith(magic):
            print("No module signature appended.")
            return
            
    header_offset = len(data) - len(magic) - 12
    header_data = data[header_offset:header_offset+12]
    
    # struct module_signature { uint8_t algo, hash, id_type, signer_len, key_id_len, pad[3]; uint32_t sig_len; }
    algo, hash_type, id_type, signer_len, key_id_len, p1, p2, p3, sig_len = struct.unpack('>BBBBBBBBI', header_data)
    
    print(f"Algorithm: {algo}")
    print(f"Hash: {hash_type}")
    print(f"ID Type: {id_type}")
    print(f"Signer name length: {signer_len}")
    print(f"Key ID length: {key_id_len}")
    print(f"Signature length: {sig_len}")
    
    signer_offset = header_offset - sig_len - key_id_len - signer_len
    signer = data[signer_offset:signer_offset + signer_len]
    key_id = data[signer_offset + signer_len:signer_offset + signer_len + key_id_len]
    
    print(f"Signer name: {signer.decode('latin1')}")
    print(f"Key ID (hex): {key_id.hex()}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 parse-sig.py <kernel-module.ko>")
        sys.exit(1)
    parse_module_signature(sys.argv[1])
