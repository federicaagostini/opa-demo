package system.health

default live := true

default ready := false

ready if {
	input.plugins_ready
	input.plugin_state.bundle == "OK"
}