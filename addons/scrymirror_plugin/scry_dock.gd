extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$ServerLineEdit.text = ScryMirror.scry_url
	print(ScryMirror.scry_url)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_server_line_edit_text_changed(new_text: String) -> void:
	ScryMirror.scry_url = new_text
	
