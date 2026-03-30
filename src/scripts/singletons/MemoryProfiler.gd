extends Node

var _is_profiling: bool = false
var _role: String = "client"

var _peak_static_memory: int = 0
var _peak_node_count: int = 0
var _peak_resource_count: int = 0

func _ready() -> void:
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg == "--profile":
			_is_profiling = true
		elif arg == "--host":
			_role = "host"
		elif arg == "--client":
			_role = "client"

func _process(_delta: float) -> void:
	if not _is_profiling:
		return
		
	var mem = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	if mem > _peak_static_memory:
		_peak_static_memory = int(mem)
		
	var nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	if nodes > _peak_node_count:
		_peak_node_count = int(nodes)
		
	var res = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	if res > _peak_resource_count:
		_peak_resource_count = int(res)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		dump_report()

func is_profiling() -> bool:
	return _is_profiling

func dump_report() -> void:
	if not _is_profiling:
		return
		
	var report = "=== MEMORY PROFILE (" + _role.to_upper() + ") ===\n"
	report += "Peak Static Memory: " + str(_peak_static_memory / 1024 / 1024) + " MB\n"
	report += "Peak Node Count: " + str(_peak_node_count) + "\n"
	report += "Peak Resource Count: " + str(_peak_resource_count) + "\n\n"
	
	report += "--- Subsystem Node Distribution ---\n"
	
	var type_counts = {}
	_count_nodes(get_tree().root, type_counts)
	
	var ordered_types = type_counts.keys()
	ordered_types.sort_custom(func(a, b): return type_counts[a] > type_counts[b])
	
	for t in ordered_types:
		report += t + ": " + str(type_counts[t]) + "\n"
		
	var file_name = _role + "_profile.log"
	var file = FileAccess.open("res://" + file_name, FileAccess.WRITE)
	if file:
		file.store_string(report)
		print("Profiler: Wrote memory profile to " + file_name)
	else:
		push_error("Profiler: Failed to write profile log.")

func _count_nodes(node: Node, counts: Dictionary) -> void:
	var t = node.get_class()
	if node.get_script() != null:
		var path = node.get_script().resource_path
		if path != "":
			t = path.get_file().get_basename()
			
	if not counts.has(t):
		counts[t] = 0
	counts[t] += 1
	
	for child in node.get_children():
		_count_nodes(child, counts)
