extends RefCounted
## Reconstruction passthrough. No camera images are requested or stored.
## https://godotvr.github.io/godot_openxr_vendors/manual/meta/passthrough.html

static func supported(xr: XRInterface) -> bool:
	return xr != null and xr.is_initialized() and XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in xr.get_supported_environment_blend_modes()

static func apply(xr: XRInterface, viewport: Viewport, environment: Environment, enabled: bool) -> bool:
	if enabled and not supported(xr):
		return false
	if xr != null and xr.is_initialized():
		xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND if enabled else XRInterface.XR_ENV_BLEND_MODE_OPAQUE
		if enabled and xr.environment_blend_mode != XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND:
			return false
	viewport.transparent_bg = enabled
	environment.background_mode = Environment.BG_COLOR if enabled else Environment.BG_SKY
	environment.background_color = Color(0, 0, 0, 0) if enabled else Color("30263f")
	environment.fog_enabled = false
	print("FOAM_MR: active=", enabled, " supported=", supported(xr), " transparent=", viewport.transparent_bg)
	return true
