app = defines["app_path"]
background = defines["background_path"]

format = "UDZO"
filesystem = "HFS+"
compression_level = 9
default_view = "icon-view"

files = [(app, "OnePlus Buds Menu.app")]
symlinks = {"Applications": "/Applications"}

window_rect = ((100, 100), (540, 340))
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 100
text_size = 10
label_pos = "bottom"
arrange_by = None
grid_spacing = 100

icon_locations = {
    "OnePlus Buds Menu.app": (140, 170),
    "Applications": (400, 170),
}
