class_name BunkerAssetMetrics
extends RefCounted
## Deterministic frame-time summaries shared by the live test HUD and regression test.


static func summarize(frame_times_ms: Array[float]) -> Dictionary:
	if frame_times_ms.is_empty():
		return {"frames": 0}
	var ordered := frame_times_ms.duplicate()
	ordered.sort()
	var total_ms := 0.0
	for frame_ms in ordered:
		if frame_ms <= 0.0:
			return {"frames": 0, "error": "frame times must be positive"}
		total_ms += frame_ms
	var slow_count := maxi(1, int(ceil(float(ordered.size()) * 0.01)))
	var slow_fps_total := 0.0
	for i in range(ordered.size() - slow_count, ordered.size()):
		slow_fps_total += 1000.0 / ordered[i]
	var p99_index := clampi(int(ceil(float(ordered.size()) * 0.99)) - 1, 0, ordered.size() - 1)
	return {
		"frames": ordered.size(),
		"average_fps": 1000.0 * float(ordered.size()) / total_ms,
		"minimum_fps": 1000.0 / ordered[-1],
		"maximum_fps": 1000.0 / ordered[0],
		"one_percent_low_fps": slow_fps_total / float(slow_count),
		"p99_frame_time_ms": ordered[p99_index],
		"average_frame_time_ms": total_ms / float(ordered.size()),
	}
