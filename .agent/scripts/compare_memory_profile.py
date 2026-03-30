import json
import re
import subprocess
import os

def parse_local_log(filename, prefix):
    if not os.path.exists(filename):
        return {}

    metrics = {}
    with open(filename, 'r') as f:
        content = f.read()
        
    mem_match = re.search(r'Peak Static Memory:\s*([\d.]+)\s*', content)
    if mem_match: metrics[f"{prefix} Peak Static Memory"] = float(mem_match.group(1))
        
    node_match = re.search(r'Peak Node Count:\s*(\d+)', content)
    if node_match: metrics[f"{prefix} Peak Node Count"] = float(node_match.group(1))
        
    res_match = re.search(r'Peak Resource Count:\s*(\d+)', content)
    if res_match: metrics[f"{prefix} Peak Resource Count"] = float(res_match.group(1))
        
    return metrics

def get_baseline_data():
    try:
        subprocess.run(["git", "fetch", "origin", "gh-pages"], capture_output=True)
        # The github-action-benchmark default directory can be root or dev/bench depending on context
        for path in ["origin/gh-pages:dev/bench/data.js", "origin/gh-pages:data.js"]:
            result = subprocess.run(["git", "show", path], capture_output=True, text=True)
            if result.returncode == 0:
                js_data = result.stdout
                prefix = "window.BENCHMARK_DATA = "
                if prefix in js_data:
                    json_str = js_data[js_data.index(prefix) + len(prefix):]
                    return json.loads(json_str)
    except Exception as e:
        print(f"Could not fetch baseline data: {e}")
    return None

def extract_latest_metrics(baseline_json, suite_name="Godot Memory Profile"):
    metrics = {}
    if not baseline_json or "entries" not in baseline_json: return metrics
    if suite_name not in baseline_json["entries"]: return metrics
    
    entries = baseline_json["entries"][suite_name]
    if not entries: return metrics
    
    latest_entry = entries[-1]
    for bench in latest_entry.get("benches", []):
        metrics[bench["name"]] = bench["value"]
        
    return metrics

def main():
    host_metrics = parse_local_log("host_profile.log", "Host")
    client_metrics = parse_local_log("client_profile.log", "Client")
    current_metrics = {**host_metrics, **client_metrics}
    
    print("Fetching baseline from gh-pages branch...")
    baseline_json = get_baseline_data()
    baseline_metrics = extract_latest_metrics(baseline_json)
    
    report = "# Pre-Push Memory Profile Comparison\n\n"
    report += "| Metric | Local Value | Baseline | Diff |\n"
    report += "|--------|-------------|----------|------|\n"
    
    for key, current_val in current_metrics.items():
        if baseline_metrics and key in baseline_metrics:
            base_val = baseline_metrics[key]
            diff = current_val - base_val
            diff_str = f"+{diff}" if diff > 0 else str(diff)
            trend = "🔴" if diff > 0 else "🟢" if diff < 0 else "⚪"
            report += f"| {key} | {current_val} | {base_val} | {diff_str} {trend} |\n"
        else:
            report += f"| {key} | {current_val} | N/A | N/A |\n"

    with open("memory_comparison_report.md", "w") as f:
        f.write(report)
        
    print(f"Generated comparison report at memory_comparison_report.md")

if __name__ == "__main__":
    main()
