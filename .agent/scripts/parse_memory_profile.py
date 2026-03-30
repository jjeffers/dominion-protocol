import json
import re
import sys
import os

def parse_log(filename, prefix):
    if not os.path.exists(filename):
        print(f"Warning: {filename} not found.")
        return []

    results = []
    
    with open(filename, 'r') as f:
        content = f.read()
        
    # Regex patterns
    mem_pattern = r'Peak Static Memory:\s*([\d.]+)\s*(MB|KB|GB)'
    node_pattern = r'Peak Node Count:\s*(\d+)'
    res_pattern = r'Peak Resource Count:\s*(\d+)'
    
    mem_match = re.search(mem_pattern, content)
    if mem_match:
        val = float(mem_match.group(1))
        unit = mem_match.group(2)
        results.append({
            "name": f"{prefix} Peak Static Memory",
            "unit": unit,
            "value": val
        })
        
    node_match = re.search(node_pattern, content)
    if node_match:
        val = float(node_match.group(1))
        results.append({
            "name": f"{prefix} Peak Node Count",
            "unit": "Nodes",
            "value": val
        })
        
    res_match = re.search(res_pattern, content)
    if res_match:
        val = float(res_match.group(1))
        results.append({
            "name": f"{prefix} Peak Resource Count",
            "unit": "Resources",
            "value": val
        })
        
    return results

def main():
    host_results = parse_log("host_profile.log", "Host")
    client_results = parse_log("client_profile.log", "Client")
    
    all_results = host_results + client_results
    
    # Output JSON that github-action-benchmark 'customSmallerIsBetter' expects
    print(json.dumps(all_results, indent=2))

if __name__ == "__main__":
    main()
