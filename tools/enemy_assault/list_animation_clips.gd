extends SceneTree

const LIBRARIES := [
	"res://resources/animations/meshy_player_animation_library.res",
	"res://resources/animations/meshy_player_animation_library_api.res",
]

func _initialize() -> void:
	for path in LIBRARIES:
		var library := load(path) as AnimationLibrary
		if library == null:
			push_error("Could not load animation library: " + path)
			quit(1)
			return
		var clips := library.get_animation_list()
		clips.sort()
		print("ASSAULT_ANIMATION_LIBRARY path=", path, " count=", clips.size())
		for clip in clips:
			print("ASSAULT_ANIMATION_CLIP name=", clip, " duration=", library.get_animation(clip).length, " tracks=", library.get_animation(clip).get_track_count())
	quit(0)
